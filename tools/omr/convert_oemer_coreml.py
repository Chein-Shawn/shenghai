#!/usr/bin/env python3
"""Attempt reproducible oemer ONNX -> Apple model conversion paths.

The script writes logs and any successful artifacts to the ML workspace. It is
allowed to fail with a structured report: conversion tooling is part of the
research surface and must not be hidden behind fake app behavior.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

MODEL_SPECS = {
    "1st_model.onnx": {
        "coreml_name": "oemer_1st_model",
        "input_shape": [1, 256, 256, 3],
        "input_name": "input",
        "output_name": "prediction",
    },
    "2nd_model.onnx": {
        "coreml_name": "oemer_2nd_model",
        "input_shape": [1, 288, 288, 3],
        "input_name": "input",
        "output_name": "conv2d_25",
    },
}


def run(command: list[str], cwd: Path | None = None) -> dict[str, object]:
    completed = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    return {
        "command": command,
        "returncode": completed.returncode,
        "stdout": completed.stdout,
        "stderr": completed.stderr,
    }


def artifact_size(path: Path) -> int:
    if path.is_file():
        return path.stat().st_size
    if path.is_dir():
        return sum(item.stat().st_size for item in path.rglob("*") if item.is_file())
    return 0


def ensure_calibration_sample(output_dir: Path, spec: dict[str, object]) -> Path:
    import numpy as np

    sample_path = output_dir / f"{spec['coreml_name']}_calibration.npy"
    if not sample_path.exists():
        shape = [int(value) for value in spec["input_shape"]]
        sample = np.full(shape, 255, dtype=np.uint8)
        np.save(sample_path, sample)
    return sample_path


def ensure_onnx2tf_default_sample(output_dir: Path) -> Path:
    import numpy as np

    sample_path = output_dir / "calibration_image_sample_data_20x128x128x3_float32.npy"
    if not sample_path.exists():
        sample = np.full((20, 128, 128, 3), 1.0, dtype=np.float32)
        np.save(sample_path, sample)
    return sample_path


def maybe_compile_coreml(package_path: Path, output_dir: Path) -> dict[str, object]:
    compiler = shutil.which("xcrun")
    if compiler is None:
        return {"ok": False, "reason": "xcrun is not available"}
    compiled_dir = output_dir / "compiled"
    compiled_dir.mkdir(parents=True, exist_ok=True)
    result = run(["xcrun", "coremlcompiler", "compile", str(package_path), str(compiled_dir)])
    if result["returncode"] != 0:
        return {"ok": False, "stage": "coremlcompiler", **result}
    modelc = compiled_dir / f"{package_path.stem}.mlmodelc"
    return {
        "ok": modelc.exists(),
        "artifact": str(modelc) if modelc.exists() else None,
        "bytes": artifact_size(modelc),
        "coremlcompiler": result,
    }


def inspect_model(path: Path) -> dict[str, object]:
    import onnx
    import onnxruntime as ort

    model = onnx.load(path)
    onnx.checker.check_model(model)
    session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
    return {
        "inputs": [{"name": item.name, "shape": item.shape, "type": item.type} for item in session.get_inputs()],
        "outputs": [{"name": item.name, "shape": item.shape, "type": item.type} for item in session.get_outputs()],
        "op_types": sorted({node.op_type for node in model.graph.node}),
        "op_count": len(model.graph.node),
    }


def try_direct_coreml(path: Path, output_dir: Path, spec: dict[str, object]) -> dict[str, object]:
    try:
        import coremltools as ct
        import onnx

        if not hasattr(ct.converters, "onnx"):
            return {"ok": False, "reason": "coremltools has no ONNX converter in this version"}
        model = onnx.load(path)
        converted = ct.converters.onnx.convert(model=model)
        output = output_dir / f"{spec['coreml_name']}.mlmodel"
        converted.save(str(output))
        return {"ok": True, "artifact": str(output)}
    except Exception as exc:  # pragma: no cover - diagnostic script
        return {"ok": False, "reason": str(exc), "traceback": traceback.format_exc()}


def try_onnx2tf_coreml(path: Path, output_dir: Path, spec: dict[str, object]) -> dict[str, object]:
    sibling_onnx2tf = Path(sys.executable).with_name("onnx2tf")
    onnx2tf = str(sibling_onnx2tf) if sibling_onnx2tf.exists() else shutil.which("onnx2tf")
    if onnx2tf is None:
        return {"ok": False, "reason": "onnx2tf command is not installed"}

    input_shape = spec["input_shape"]
    input_name = spec["input_name"]
    shape_override = f"{input_name}:{','.join(str(value) for value in input_shape)}"
    calibration_sample = ensure_calibration_sample(output_dir, spec)
    ensure_onnx2tf_default_sample(output_dir)
    calibration_args = ["-cind", str(input_name), str(calibration_sample)]
    attempts = [
        {
            "name": "baseline",
            "extra_args": ["-osd", "-n"],
        },
        {
            "name": "static_shape_only",
            "extra_args": ["-osd", "-b", "1", "-ois", shape_override, *calibration_args, "-n"],
        },
        {
            "name": "static_keep_nhwc",
            "extra_args": ["-osd", "-b", "1", "-ois", shape_override, "-kt", input_name, *calibration_args, "-n"],
        },
        {
            "name": "static_keep_absolute",
            "extra_args": ["-osd", "-b", "1", "-ois", shape_override, "-kat", input_name, *calibration_args, "-n"],
        },
    ]

    attempt_reports: list[dict[str, object]] = []
    seen_attempt_names: set[str] = set()

    def run_attempt(attempt: dict[str, object]) -> dict[str, object]:
        saved_model_dir = output_dir / f"{spec['coreml_name']}_{attempt['name']}_saved_model"
        package_path = output_dir / f"{spec['coreml_name']}_{attempt['name']}.mlpackage"
        if saved_model_dir.exists():
            shutil.rmtree(saved_model_dir)
        command = [onnx2tf, "-i", str(path), "-o", str(saved_model_dir), *attempt["extra_args"]]
        conversion = run(command, cwd=output_dir)
        attempt_report: dict[str, object] = {"name": attempt["name"], "onnx2tf": conversion}
        if conversion["returncode"] != 0:
            attempt_report["ok"] = False
            attempt_report["stage"] = "onnx2tf"
            auto_json = saved_model_dir / f"{path.stem}_auto.json"
            if auto_json.exists():
                attempt_report["auto_json"] = str(auto_json)
            return attempt_report

        try:
            import coremltools as ct

            mlmodel = ct.convert(
                str(saved_model_dir),
                source="tensorflow",
                convert_to="mlprogram",
                minimum_deployment_target=ct.target.iOS17,
            )
            mlmodel.save(str(package_path))
            attempt_report.update({
                "ok": True,
                "artifact": str(package_path),
                "bytes": artifact_size(package_path),
                "compiled_model": maybe_compile_coreml(package_path, output_dir),
            })
            return attempt_report
        except Exception as exc:  # pragma: no cover - diagnostic script
            attempt_report.update({
                "ok": False,
                "stage": "coremltools tensorflow",
                "reason": str(exc),
                "traceback": traceback.format_exc(),
            })
            return attempt_report

    pending = list(attempts)
    index = 0
    while index < len(pending):
        attempt = pending[index]
        index += 1
        attempt_name = str(attempt["name"])
        if attempt_name in seen_attempt_names:
            continue
        seen_attempt_names.add(attempt_name)
        attempt_report = run_attempt(attempt)
        attempt_reports.append(attempt_report)
        if attempt_report.get("ok"):
            return {"ok": True, "artifact": attempt_report.get("artifact"), "attempts": attempt_reports}

        auto_json = attempt_report.get("auto_json")
        if isinstance(auto_json, str) and Path(auto_json).exists():
            retry_name = f"{attempt_name}_auto_json"
            pending.append({
                "name": retry_name,
                "extra_args": [*attempt["extra_args"], "-prf", auto_json],
            })

    return {"ok": False, "stage": "all conversion attempts", "attempts": attempt_reports}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint-dir", default="/Users/shawn/Documents/Codex/vocaldive-ml/oemer/checkpoints")
    parser.add_argument("--output-dir", default="/Users/shawn/Documents/Codex/vocaldive-ml/oemer/models")
    parser.add_argument("--log-dir", default="/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs")
    args = parser.parse_args()

    checkpoint_dir = Path(args.checkpoint_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    log_dir = Path(args.log_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, object] = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "python": sys.version,
        "models": {},
    }
    for filename, spec in MODEL_SPECS.items():
        path = checkpoint_dir / filename
        model_report: dict[str, object] = {"path": str(path), "exists": path.exists()}
        if not path.exists():
            model_report["error"] = "missing checkpoint"
            report["models"][filename] = model_report
            continue
        try:
            model_report["onnx"] = inspect_model(path)
            model_report["direct_coreml"] = try_direct_coreml(path, output_dir, spec)
            model_report["onnx2tf_coreml"] = try_onnx2tf_coreml(path, output_dir, spec)
        except Exception as exc:  # pragma: no cover - diagnostic script
            model_report["error"] = str(exc)
            model_report["traceback"] = traceback.format_exc()
        report["models"][filename] = model_report

    log_path = log_dir / f"conversion-{datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')}.json"
    log_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    print(f"wrote {log_path}")
    any_success = any(
        model.get("direct_coreml", {}).get("ok") or model.get("onnx2tf_coreml", {}).get("ok")
        for model in report["models"].values()
        if isinstance(model, dict)
    )
    return 0 if any_success else 1


if __name__ == "__main__":
    raise SystemExit(main())
