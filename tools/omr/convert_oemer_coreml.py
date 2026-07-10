#!/usr/bin/env python3
"""Attempt reproducible oemer ONNX -> Apple model conversion paths.

The script writes logs and any successful artifacts to the ML workspace. It is
allowed to fail with a structured report: conversion tooling is part of the
research surface and must not be hidden behind fake app behavior.
"""

from __future__ import annotations

import argparse
import copy
import json
import os
import shutil
import subprocess
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

from oemer_workspace import conversion_site_packages, workspace_paths

site_packages = conversion_site_packages()
if site_packages and str(site_packages) not in sys.path:
    sys.path.insert(0, str(site_packages))

MODEL_SPECS = {
    "1st_model.onnx": {
        "coreml_name": "oemer_1st_model",
        "input_shape": [1, 256, 256, 3],
        "nchw_input_shape": [1, 3, 256, 256],
        "input_name": "input",
        "output_name": "prediction",
    },
    "2nd_model.onnx": {
        "coreml_name": "oemer_2nd_model",
        "input_shape": [1, 288, 288, 3],
        "nchw_input_shape": [1, 3, 288, 288],
        "input_name": "input",
        "output_name": "conv2d_25",
    },
}


def run(command: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> dict[str, object]:
    completed = subprocess.run(command, cwd=cwd, env=env, text=True, capture_output=True)
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
    inits = {initializer.name: initializer for initializer in model.graph.initializer}
    leading_nodes = []
    for node in model.graph.node[:12]:
        item = {
            "op_type": node.op_type,
            "inputs": list(node.input),
            "outputs": list(node.output),
        }
        if node.op_type in {"Conv", "ConvTranspose"} and len(node.input) > 1:
            weight = inits.get(node.input[1])
            item["weight_shape"] = list(weight.dims) if weight is not None else None
        leading_nodes.append(item)
    return {
        "inputs": [{"name": item.name, "shape": item.shape, "type": item.type} for item in session.get_inputs()],
        "outputs": [{"name": item.name, "shape": item.shape, "type": item.type} for item in session.get_outputs()],
        "op_types": sorted({node.op_type for node in model.graph.node}),
        "op_count": len(model.graph.node),
        "leading_nodes": leading_nodes,
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
    except Exception as exc:
        return {"ok": False, "reason": str(exc), "traceback": traceback.format_exc()}


def onnx2tf_runner() -> tuple[list[str], dict[str, str]] | None:
    if site_packages:
        env = os.environ.copy()
        existing = env.get("PYTHONPATH")
        env["PYTHONPATH"] = f"{site_packages}{os.pathsep}{existing}" if existing else str(site_packages)
        return ([sys.executable, "-S", "-m", "onnx2tf"], env)

    sibling_onnx2tf = Path(sys.executable).with_name("onnx2tf")
    if sibling_onnx2tf.exists():
        return ([str(sibling_onnx2tf)], None)

    onnx2tf = shutil.which("onnx2tf")
    if onnx2tf is not None:
        return ([onnx2tf], None)
    return None


def node_attribute_ints(node, name: str) -> list[int] | None:
    for attribute in node.attribute:
        if attribute.name == name:
            return list(attribute.ints)
    return None


def rewrite_initial_transpose_to_nchw(path: Path, output_dir: Path, spec: dict[str, object]) -> dict[str, object]:
    import onnx

    model = onnx.load(path)
    rewritten = copy.deepcopy(model)
    input_name = str(spec["input_name"])

    cast_node = next((node for node in rewritten.graph.node if node.op_type == "Cast" and input_name in node.input), None)
    if cast_node is None:
        return {"ok": False, "reason": "could not find cast node connected to model input"}

    cast_output = cast_node.output[0]
    transpose_node = next(
        (node for node in rewritten.graph.node if node.op_type == "Transpose" and len(node.input) == 1 and node.input[0] == cast_output),
        None,
    )
    if transpose_node is None:
        return {"ok": False, "reason": "could not find initial transpose after cast"}

    perm = node_attribute_ints(transpose_node, "perm")
    if perm != [0, 3, 1, 2]:
        return {"ok": False, "reason": f"initial transpose perm is {perm}, expected [0, 3, 1, 2]"}

    old_output = transpose_node.output[0]
    new_output = transpose_node.input[0]
    consumer_count = 0
    for node in rewritten.graph.node:
        updated_inputs = []
        for value in node.input:
            if value == old_output:
                updated_inputs.append(new_output)
                consumer_count += 1
            else:
                updated_inputs.append(value)
        del node.input[:]
        node.input.extend(updated_inputs)

    remaining = [node for node in rewritten.graph.node if node is not transpose_node]
    del rewritten.graph.node[:]
    rewritten.graph.node.extend(remaining)

    nchw_shape = [int(value) for value in spec["nchw_input_shape"]]
    for value_info in rewritten.graph.input:
        if value_info.name != input_name:
            continue
        dims = value_info.type.tensor_type.shape.dim
        for index, replacement in enumerate(nchw_shape):
            dims[index].ClearField("dim_param")
            dims[index].dim_value = replacement
        break

    output_path = output_dir / f"{path.stem}_nchw_input.onnx"
    onnx.checker.check_model(rewritten)
    onnx.save(rewritten, output_path)
    return {
        "ok": True,
        "artifact": str(output_path),
        "consumer_count": consumer_count,
        "removed_transpose": transpose_node.name or old_output,
    }


def attempt_definitions(spec: dict[str, object], *, keep_layout_hints: bool) -> list[dict[str, object]]:
    input_shape = [int(value) for value in spec["input_shape"]]
    input_name = str(spec["input_name"])
    shape_override = f"{input_name}:{','.join(str(value) for value in input_shape)}"
    calibration_args = ["-cind", str(input_name), str(ensure_calibration_sample(Path(spec["_output_dir"]), spec))]
    attempts = [
        {
            "name": "baseline",
            "extra_args": ["-osd", "-n"],
        },
        {
            "name": "static_shape_only",
            "extra_args": ["-osd", "-b", "1", "-ois", shape_override, *calibration_args, "-n"],
        },
    ]
    if keep_layout_hints:
        attempts.extend([
            {
                "name": "static_keep_nhwc",
                "extra_args": ["-osd", "-b", "1", "-ois", shape_override, "-kt", input_name, *calibration_args, "-n"],
            },
            {
                "name": "static_keep_absolute",
                "extra_args": ["-osd", "-b", "1", "-ois", shape_override, "-kat", input_name, *calibration_args, "-n"],
            },
        ])
    return attempts


def run_onnx2tf_attempts(
    model_path: Path,
    output_dir: Path,
    spec: dict[str, object],
    *,
    variant_name: str,
    keep_layout_hints: bool,
) -> list[dict[str, object]]:
    runner = onnx2tf_runner()
    if runner is None:
        return [{"ok": False, "stage": "onnx2tf", "reason": "onnx2tf command is not installed"}]
    command_prefix, command_env = runner
    ensure_onnx2tf_default_sample(output_dir)

    temp_spec = dict(spec)
    temp_spec["_output_dir"] = output_dir
    attempts = attempt_definitions(temp_spec, keep_layout_hints=keep_layout_hints)
    reports: list[dict[str, object]] = []
    pending = list(attempts)
    seen: set[str] = set()

    while pending:
        attempt = pending.pop(0)
        attempt_name = str(attempt["name"])
        if attempt_name in seen:
            continue
        seen.add(attempt_name)

        saved_model_dir = output_dir / f"{spec['coreml_name']}_{variant_name}_{attempt_name}_saved_model"
        package_path = output_dir / f"{spec['coreml_name']}_{variant_name}_{attempt_name}.mlpackage"
        if saved_model_dir.exists():
            shutil.rmtree(saved_model_dir)
        command = [*command_prefix, "-i", str(model_path), "-o", str(saved_model_dir), *attempt["extra_args"]]
        conversion = run(command, cwd=output_dir, env=command_env)
        report: dict[str, object] = {"variant": variant_name, "name": attempt_name, "onnx2tf": conversion}
        if conversion["returncode"] != 0:
            report["ok"] = False
            report["stage"] = "onnx2tf"
            auto_json = saved_model_dir / f"{model_path.stem}_auto.json"
            if auto_json.exists():
                report["auto_json"] = str(auto_json)
                pending.append({
                    "name": f"{attempt_name}_auto_json",
                    "extra_args": [*attempt["extra_args"], "-prf", str(auto_json)],
                })
            reports.append(report)
            continue

        try:
            import coremltools as ct

            mlmodel = ct.convert(
                str(saved_model_dir),
                source="tensorflow",
                convert_to="mlprogram",
                minimum_deployment_target=ct.target.iOS17,
            )
            mlmodel.save(str(package_path))
            report.update({
                "ok": True,
                "artifact": str(package_path),
                "bytes": artifact_size(package_path),
                "compiled_model": maybe_compile_coreml(package_path, output_dir),
            })
        except Exception as exc:
            report.update({
                "ok": False,
                "stage": "coremltools tensorflow",
                "reason": str(exc),
                "traceback": traceback.format_exc(),
            })
        reports.append(report)
        if report.get("ok"):
            break

    return reports


def try_onnx2tf_coreml(path: Path, output_dir: Path, spec: dict[str, object]) -> dict[str, object]:
    reports = run_onnx2tf_attempts(path, output_dir, spec, variant_name="original", keep_layout_hints=True)
    if any(report.get("ok") for report in reports):
        success = next(report for report in reports if report.get("ok"))
        return {"ok": True, "artifact": success.get("artifact"), "attempts": reports}

    rewrite_report = rewrite_initial_transpose_to_nchw(path, output_dir, spec)
    if not rewrite_report.get("ok"):
        return {"ok": False, "stage": "all conversion attempts", "attempts": reports, "nchw_rewrite": rewrite_report}

    rewritten_spec = dict(spec)
    rewritten_spec["input_shape"] = list(spec["nchw_input_shape"])
    rewritten_path = Path(str(rewrite_report["artifact"]))
    rewritten_reports = run_onnx2tf_attempts(
        rewritten_path,
        output_dir,
        rewritten_spec,
        variant_name="nchw_rewrite",
        keep_layout_hints=False,
    )
    combined = reports + rewritten_reports
    if any(report.get("ok") for report in rewritten_reports):
        success = next(report for report in rewritten_reports if report.get("ok"))
        return {
            "ok": True,
            "artifact": success.get("artifact"),
            "attempts": combined,
            "nchw_rewrite": rewrite_report,
        }

    return {
        "ok": False,
        "stage": "all conversion attempts",
        "attempts": combined,
        "nchw_rewrite": rewrite_report,
    }


def main() -> int:
    defaults = workspace_paths()
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkpoint-dir", default=str(defaults["checkpoints"]))
    parser.add_argument("--output-dir", default=str(defaults["models"]))
    parser.add_argument("--log-dir", default=str(defaults["logs"]))
    args = parser.parse_args()

    checkpoint_dir = Path(args.checkpoint_dir).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    log_dir = Path(args.log_dir).expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)

    report: dict[str, object] = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "python": sys.version,
        "workspace": str(defaults["root"]),
        "checkpoint_dir": str(checkpoint_dir),
        "output_dir": str(output_dir),
        "log_dir": str(log_dir),
        "site_packages": str(site_packages) if site_packages else None,
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
        except Exception as exc:
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
