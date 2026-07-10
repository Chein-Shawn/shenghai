#!/usr/bin/env python3
"""Decision-gate experiments for getting oemer into VocalDive.

This script keeps large model artifacts in the local ML workspace and records
small, reproducible evidence for deciding whether to continue Core ML graph
repair, use an ONNX Runtime research fallback, or pivot to an Apple-friendly
segmentation model.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from oemer_workspace import conversion_site_packages, workspace_paths

site_packages = conversion_site_packages()
if site_packages and str(site_packages) not in sys.path:
    sys.path.insert(0, str(site_packages))


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_onnx(path: Path) -> Any:
    import onnx

    return onnx.load(path)


def tensor_perm(node: Any) -> list[int] | None:
    for attribute in node.attribute:
        if attribute.name == "perm":
            return list(attribute.ints)
    return None


def producers_for(model: Any) -> dict[str, Any]:
    producers: dict[str, Any] = {}
    for node in model.graph.node:
        for output in node.output:
            producers[output] = node
    return producers


def run_ort(model_path: Path, repeats: int, output_npz: Path | None) -> dict[str, Any]:
    import numpy as np
    import onnxruntime as ort

    session = ort.InferenceSession(str(model_path), providers=["CPUExecutionProvider"])
    input_meta = session.get_inputs()[0]
    output_meta = session.get_outputs()[0]
    shape = [1 if isinstance(dim, str) or dim is None else int(dim) for dim in input_meta.shape]
    sample = np.full(shape, 255, dtype=np.uint8)

    first = session.run(None, {input_meta.name: sample})[0]
    timings: list[float] = []
    for _ in range(repeats):
        start = time.perf_counter()
        result = session.run(None, {input_meta.name: sample})[0]
        timings.append((time.perf_counter() - start) * 1000.0)

    if output_npz:
        output_npz.parent.mkdir(parents=True, exist_ok=True)
        np.savez_compressed(output_npz, prediction=first)

    return {
        "created_at": utc_now(),
        "model_path": str(model_path),
        "model_size_bytes": model_path.stat().st_size,
        "input": {"name": input_meta.name, "shape": input_meta.shape, "type": input_meta.type},
        "output": {"name": output_meta.name, "shape": output_meta.shape, "type": output_meta.type},
        "prediction": {
            "shape": list(first.shape),
            "dtype": str(first.dtype),
            "min": float(first.min()),
            "max": float(first.max()),
            "mean": float(first.mean()),
        },
        "timing_ms": {
            "repeats": repeats,
            "mean": sum(timings) / len(timings),
            "min": min(timings),
            "max": max(timings),
        },
        "output_npz": str(output_npz) if output_npz else None,
    }


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def write_convtranspose_profile(source: Path, output: Path) -> dict[str, Any]:
    import numpy as np
    import onnx
    import onnxruntime as ort
    from onnx import TensorProto, helper

    model = onnx.load(source)
    watch: list[str] = []
    conv_nodes = [node for node in model.graph.node if node.op_type == "ConvTranspose"]
    for node in conv_nodes:
        watch.extend(node.output)
    seen: set[str] = set()
    watch = [name for name in watch if not (name in seen or seen.add(name))]

    inspection = onnx.load(source)
    for name in watch:
        inspection.graph.output.append(helper.make_tensor_value_info(name, TensorProto.FLOAT, None))
    inspection_path = output.with_name("inspect_convtranspose_outputs_for_decision_gate.onnx")
    onnx.save(inspection, inspection_path)

    session = ort.InferenceSession(str(inspection_path), providers=["CPUExecutionProvider"])
    input_meta = session.get_inputs()[0]
    shape = [1 if isinstance(dim, str) or dim is None else int(dim) for dim in input_meta.shape]
    outputs = session.run(None, {input_meta.name: np.full(shape, 255, dtype=np.uint8)})
    shape_by_name = {meta.name: list(array.shape) for meta, array in zip(session.get_outputs(), outputs)}

    operations = []
    for node in conv_nodes:
        out_shape = shape_by_name.get(node.output[0])
        if not out_shape:
            continue
        strides = list(node.attribute[0].ints) if node.attribute and node.attribute[0].name == "strides" else [2, 2]
        operations.append({
            "op_name": node.name,
            "param_target": "op",
            "output_shape": out_shape,
            "strides": [1, *strides, 1],
            "padding": "SAME",
            "dilations": [1, 1, 1, 1],
        })

    profile = {"format_version": 1, "operations": operations}
    write_json(output, profile)
    return {"profile": str(output), "operation_count": len(operations), "inspection_model": str(inspection_path)}


def write_conservative_add_profile(source: Path, output: Path, perm: list[int]) -> dict[str, Any]:
    model = load_onnx(source)
    producers = producers_for(model)
    operations: list[dict[str, Any]] = []
    for node in model.graph.node:
        if node.op_type != "Add" or not node.name.startswith("model/add"):
            continue
        for input_name in node.input:
            producer = producers.get(input_name)
            if producer and producer.op_type == "Transpose" and tensor_perm(producer) == [0, 3, 1, 2]:
                operations.append({
                    "op_name": node.name,
                    "param_target": "inputs",
                    "param_name": input_name,
                    "pre_process_transpose_perm": perm,
                })
    profile = {"format_version": 1, "operations": operations}
    write_json(output, profile)
    return {"profile": str(output), "operation_count": len(operations), "perm": perm}


def run_onnx2tf(source: Path, output_dir: Path, profiles: list[Path], keep_ncw: bool) -> dict[str, Any]:
    output_dir.parent.mkdir(parents=True, exist_ok=True)
    command = [
        sys.executable,
        "-S",
        "-m",
        "onnx2tf",
        "-i",
        str(source),
        "-o",
        str(output_dir),
        "-osd",
        "-b",
        "1",
        "-ois",
        "input:1,3,288,288",
        "-n",
    ]
    if keep_ncw:
        command.extend(["-kat", "input"])
    for profile in profiles:
        command.extend(["-prf", str(profile)])

    env = os.environ.copy()
    if site_packages:
        env["PYTHONPATH"] = str(site_packages)
    start = time.perf_counter()
    proc = subprocess.run(command, cwd=str(output_dir.parent), env=env, text=True, capture_output=True)
    duration = time.perf_counter() - start
    return {
        "created_at": utc_now(),
        "source": str(source),
        "output_dir": str(output_dir),
        "profiles": [str(profile) for profile in profiles],
        "keep_ncw": keep_ncw,
        "returncode": proc.returncode,
        "duration_seconds": duration,
        "stdout_tail": proc.stdout[-6000:],
        "stderr_tail": proc.stderr[-6000:],
    }


def main() -> int:
    defaults = workspace_paths()
    model_dir = defaults["models"]
    repair_dir = model_dir / "graph_repair"
    reports_dir = defaults["root"] / "outputs" / "decision_gate"

    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    bench = sub.add_parser("benchmark-onnx")
    bench.add_argument("--model", type=Path, default=model_dir / "2nd_model_nchw_input.onnx")
    bench.add_argument("--repeats", type=int, default=10)
    bench.add_argument("--output", type=Path, default=reports_dir / "2nd_model_onnxruntime_benchmark.json")

    export = sub.add_parser("export-prediction-map")
    export.add_argument("--model", type=Path, default=model_dir / "2nd_model_nchw_input.onnx")
    export.add_argument("--npz", type=Path, default=reports_dir / "2nd_model_prediction_map.npz")
    export.add_argument("--output", type=Path, default=reports_dir / "2nd_model_prediction_map_summary.json")

    conv_profile = sub.add_parser("write-convtranspose-profile")
    # The all-Add-bypass experiment no longer passes ONNX Runtime shape
    # validation. Measure profiles from the valid NCHW graph instead.
    conv_profile.add_argument("--source", type=Path, default=model_dir / "2nd_model_nchw_input.onnx")
    conv_profile.add_argument("--output", type=Path, default=repair_dir / "decision_gate_convtranspose_replacement_profile.json")

    add_profile = sub.add_parser("write-conservative-add-profile")
    add_profile.add_argument("--source", type=Path, default=model_dir / "2nd_model_nchw_input.onnx")
    add_profile.add_argument("--output", type=Path, default=repair_dir / "decision_gate_conservative_add_profile_0132.json")
    add_profile.add_argument("--perm", type=int, nargs=4, default=[0, 1, 3, 2])

    convert = sub.add_parser("run-onnx2tf")
    convert.add_argument("--source", type=Path, default=model_dir / "2nd_model_nchw_input.onnx")
    convert.add_argument("--output-dir", type=Path, default=repair_dir / "decision_gate_conservative_add_saved_model")
    convert.add_argument("--profile", action="append", type=Path, default=[])
    convert.add_argument("--keep-ncw", action="store_true")
    convert.add_argument("--report", type=Path, default=reports_dir / "run_onnx2tf_latest.json")

    args = parser.parse_args()

    if args.command == "benchmark-onnx":
        result = run_ort(args.model.expanduser().resolve(), args.repeats, None)
        write_json(args.output.expanduser().resolve(), result)
        print(json.dumps(result, indent=2))
        return 0
    if args.command == "export-prediction-map":
        result = run_ort(args.model.expanduser().resolve(), 1, args.npz.expanduser().resolve())
        write_json(args.output.expanduser().resolve(), result)
        print(json.dumps(result, indent=2))
        return 0
    if args.command == "write-convtranspose-profile":
        result = write_convtranspose_profile(args.source.expanduser().resolve(), args.output.expanduser().resolve())
        print(json.dumps(result, indent=2))
        return 0
    if args.command == "write-conservative-add-profile":
        result = write_conservative_add_profile(args.source.expanduser().resolve(), args.output.expanduser().resolve(), args.perm)
        print(json.dumps(result, indent=2))
        return 0
    if args.command == "run-onnx2tf":
        result = run_onnx2tf(
            args.source.expanduser().resolve(),
            args.output_dir.expanduser().resolve(),
            [profile.expanduser().resolve() for profile in args.profile],
            args.keep_ncw,
        )
        write_json(args.report.expanduser().resolve(), result)
        print(json.dumps(result, indent=2))
        return 0 if result["returncode"] == 0 else result["returncode"]
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
