#!/usr/bin/env python3
"""Create TensorFlow-conversion-friendly oemer ONNX graph variants.

This tool does not modify official checkpoints. It writes repaired variants into
an ML workspace so conversion blockers can be reproduced without polluting git
with large model artifacts.
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from oemer_workspace import conversion_site_packages, workspace_paths

site_packages = conversion_site_packages()
if site_packages and str(site_packages) not in sys.path:
    sys.path.insert(0, str(site_packages))


def tensor_perm(node: Any) -> list[int] | None:
    for attribute in node.attribute:
        if attribute.name == "perm":
            return list(attribute.ints)
    return None


def replace_all_inputs(model: Any, old: str, new: str) -> int:
    count = 0
    for node in model.graph.node:
        updated = []
        for value in node.input:
            if value == old:
                updated.append(new)
                count += 1
            else:
                updated.append(value)
        del node.input[:]
        node.input.extend(updated)
    return count


def remove_named_nodes(model: Any, names: set[str]) -> int:
    kept = [node for node in model.graph.node if node.name not in names]
    removed = len(model.graph.node) - len(kept)
    del model.graph.node[:]
    model.graph.node.extend(kept)
    return removed


def find_residual_transpose_pairs(model: Any) -> list[dict[str, Any]]:
    producers: dict[str, Any] = {}
    consumers: dict[str, list[Any]] = {}
    for node in model.graph.node:
        for output in node.output:
            producers[output] = node
        for input_name in node.input:
            consumers.setdefault(input_name, []).append(node)

    pairs: list[dict[str, Any]] = []
    for add in model.graph.node:
        if add.op_type != "Add" or not add.name.startswith("model/add"):
            continue
        pre_candidates = []
        for input_name in add.input:
            producer = producers.get(input_name)
            if producer and producer.op_type == "Transpose" and tensor_perm(producer) == [0, 3, 1, 2]:
                pre_candidates.append((input_name, producer))
        post_candidates = []
        for output_name in add.output:
            for consumer in consumers.get(output_name, []):
                if consumer.op_type == "Transpose" and tensor_perm(consumer) == [0, 2, 3, 1]:
                    post_candidates.append((output_name, consumer))
        if pre_candidates and post_candidates:
            pre_output, pre_node = pre_candidates[0]
            add_output, post_node = post_candidates[0]
            pairs.append({
                "add_name": add.name,
                "pre_transpose_name": pre_node.name,
                "pre_transpose_output": pre_output,
                "pre_transpose_input": pre_node.input[0],
                "add_output": add_output,
                "post_transpose_name": post_node.name,
                "post_transpose_output": post_node.output[0],
            })
    return pairs


def bypass_residual_transposes(model: Any, pairs: list[dict[str, Any]]) -> dict[str, Any]:
    node_by_name = {node.name: node for node in model.graph.node}
    removed_names: set[str] = set()
    rewires: list[str] = []
    for pair in pairs:
        add = node_by_name[pair["add_name"]]
        for index, value in enumerate(add.input):
            if value == pair["pre_transpose_output"]:
                add.input[index] = pair["pre_transpose_input"]
                rewires.append(f"{pair['add_name']}: {pair['pre_transpose_output']} -> {pair['pre_transpose_input']}")
        rewired_count = replace_all_inputs(model, pair["post_transpose_output"], pair["add_output"])
        if rewired_count:
            rewires.append(f"{pair['add_name']}: {pair['post_transpose_output']} -> {pair['add_output']} ({rewired_count} consumers)")
        removed_names.add(pair["pre_transpose_name"])
        removed_names.add(pair["post_transpose_name"])
    removed = remove_named_nodes(model, removed_names)
    return {"removed_nodes": removed, "rewires": rewires}


def add_convtranspose_shape_hints(original_model_path: Path, repaired_model: Any, output_dir: Path) -> dict[str, Any]:
    import numpy as np
    import onnx
    import onnxruntime as ort
    from onnx import TensorProto, helper

    original = onnx.load(original_model_path)
    watch: list[str] = []
    for node in original.graph.node:
        if node.op_type == "ConvTranspose":
            watch.append(node.input[0])
            watch.extend(node.output)
    seen: set[str] = set()
    watch = [name for name in watch if not (name in seen or seen.add(name))]

    inspection_model = copy.deepcopy(original)
    for name in watch:
        inspection_model.graph.output.append(helper.make_tensor_value_info(name, TensorProto.FLOAT, None))
    inspection_path = output_dir / "inspect_convtranspose_intermediates.onnx"
    onnx.save(inspection_model, inspection_path)

    session = ort.InferenceSession(str(inspection_path), providers=["CPUExecutionProvider"])
    outputs = session.run(None, {"input": np.full((1, 3, 288, 288), 255, dtype=np.uint8)})
    shape_by_name = {
        meta.name: list(array.shape)
        for meta, array in zip(session.get_outputs(), outputs)
        if meta.name in watch
    }

    keep = []
    removed_stale = 0
    for value_info in repaired_model.graph.value_info:
        if value_info.name in shape_by_name:
            removed_stale += 1
        else:
            keep.append(value_info)
    del repaired_model.graph.value_info[:]
    repaired_model.graph.value_info.extend(keep)
    for name, shape in shape_by_name.items():
        repaired_model.graph.value_info.append(helper.make_tensor_value_info(name, TensorProto.FLOAT, shape))
    return {
        "inspection_model": str(inspection_path),
        "shape_count": len(shape_by_name),
        "removed_stale_value_info": removed_stale,
        "shapes": shape_by_name,
    }


def main() -> int:
    import onnx

    defaults = workspace_paths()
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=defaults["models"] / "2nd_model_nchw_input.onnx")
    parser.add_argument("--output-dir", type=Path, default=defaults["models"] / "graph_repair")
    parser.add_argument("--no-shape-hints", action="store_true")
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    original = onnx.load(source)
    pairs = find_residual_transpose_pairs(original)
    repaired = copy.deepcopy(original)
    bypass_report = bypass_residual_transposes(repaired, pairs)
    shape_report = None
    if not args.no_shape_hints:
        shape_report = add_convtranspose_shape_hints(source, repaired, output_dir)

    onnx.checker.check_model(repaired)
    suffix = "shape_hinted" if shape_report else "no_shape_hints"
    output_model = output_dir / f"{source.stem}_bypass_all_add_transposes_{suffix}.onnx"
    onnx.save(repaired, output_model)

    report = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source": str(source),
        "output_model": str(output_model),
        "residual_pair_count": len(pairs),
        "pairs": pairs,
        "bypass": bypass_report,
        "shape_hints": shape_report,
    }
    report_path = output_dir / f"{output_model.stem}.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
