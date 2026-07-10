#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


DEFAULT_LOG_DIRS = [
    Path("/Volumes/Crucial X6/vocaldive-ml/oemer/logs"),
    Path.home() / "Documents/Codex/vocaldive-ml/oemer/logs",
]


def latest_log(explicit: Path | None) -> Path:
    if explicit:
        return explicit
    logs: list[Path] = []
    for root in DEFAULT_LOG_DIRS:
        if root.exists():
            logs.extend(root.glob("conversion-*.json"))
    if not logs:
        raise SystemExit("No conversion log found. Pass --log explicitly.")
    return sorted(logs)[-1]


def shorten(value: Any, limit: int = 220) -> str:
    if value is None:
        return "-"
    text = " ".join(str(value).split())
    return text if len(text) <= limit else text[: limit - 3] + "..."


def as_list(value: Any) -> list[Any]:
    return value if isinstance(value, list) else []


def dump_shape_list(items: Any) -> str:
    if not items:
        return "-"
    return shorten(items, 500)


def attempt_lines(attempt: dict[str, Any], index: int) -> list[str]:
    ok = attempt.get("ok")
    if ok is None:
        ok = attempt.get("success")
    status = "success" if ok is True else "failed"
    strategy = attempt.get("strategy") or attempt.get("name") or attempt.get("stage") or "unknown"
    branch = attempt.get("branch") or attempt.get("source") or "-"
    lines = [f"- [{status}] attempt {index}: strategy={strategy} branch={branch}"]

    for key in [
        "stage",
        "onnx_path",
        "rewritten_onnx_path",
        "auto_json_path",
        "replacement_profile_path",
        "saved_model_dir",
        "mlpackage_path",
    ]:
        if attempt.get(key):
            lines.append(f"  {key}: {attempt[key]}")

    failure_node = (
        attempt.get("failure_node")
        or attempt.get("error_node")
        or attempt.get("node_name")
        or attempt.get("node")
    )
    failure_reason = (
        attempt.get("failure_reason")
        or attempt.get("reason")
        or attempt.get("error")
        or attempt.get("stderr_tail")
        or attempt.get("message")
    )
    if failure_node or failure_reason:
        lines.append(f"  failure_node: {failure_node or '-'}")
        lines.append(f"  failure_reason: {shorten(failure_reason)}")
    return lines


def summarize_model(name: str, model: dict[str, Any]) -> list[str]:
    lines: list[str] = [f"## {name}"]
    lines.append(f"source: {model.get('path') or model.get('source_path') or '-'}")
    lines.append(f"exists: {model.get('exists', '-')}")

    onnx = model.get("onnx") if isinstance(model.get("onnx"), dict) else {}
    if onnx:
        lines.append(f"onnx inputs: {dump_shape_list(onnx.get('inputs'))}")
        lines.append(f"onnx outputs: {dump_shape_list(onnx.get('outputs'))}")
        lines.append(f"leading nodes: {dump_shape_list(onnx.get('leading_nodes'))}")
        lines.append(f"op count: {onnx.get('op_count', '-')}")

    direct = model.get("direct_coreml") if isinstance(model.get("direct_coreml"), dict) else {}
    if direct:
        lines.append("")
        lines.append("### Direct Core ML")
        lines.append(f"ok: {direct.get('ok', '-')}")
        lines.append(f"reason: {shorten(direct.get('reason'))}")

    conversion = model.get("onnx2tf_coreml") if isinstance(model.get("onnx2tf_coreml"), dict) else {}
    if conversion:
        lines.append("")
        lines.append("### ONNX -> TF -> Core ML")
        lines.append(f"ok: {conversion.get('ok', '-')}")
        lines.append(f"stage: {conversion.get('stage', '-')}")

        rewrite = conversion.get("nchw_rewrite")
        if isinstance(rewrite, dict):
            lines.append("")
            lines.append("#### NCHW rewrite")
            for key in [
                "ok",
                "consumer_count",
                "removed_transpose",
                "rewritten_onnx_path",
                "reason",
                "error",
            ]:
                if key in rewrite:
                    lines.append(f"{key}: {shorten(rewrite.get(key))}")

        attempts = as_list(conversion.get("attempts"))
        lines.append("")
        lines.append("#### Attempts")
        if attempts:
            for index, attempt in enumerate(attempts):
                if isinstance(attempt, dict):
                    lines.extend(attempt_lines(attempt, index))
                else:
                    lines.append(f"- {shorten(attempt)}")
        else:
            lines.append("- no attempts recorded")

        auto_jsons = []
        for attempt in attempts:
            if isinstance(attempt, dict) and attempt.get("auto_json_path"):
                auto_jsons.append(attempt["auto_json_path"])
        if auto_jsons:
            lines.append("")
            lines.append("#### Auto JSON candidates")
            for path in sorted(set(auto_jsons)):
                lines.append(f"- {path}")

    lines.append("")
    return lines


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    log = latest_log(args.log)
    data = json.loads(log.read_text(encoding="utf-8"))

    lines: list[str] = [
        "# oemer Core ML Conversion Summary",
        "",
        f"log: {log}",
        f"created_at: {data.get('created_at', '-')}",
        f"python: {data.get('python', '-')}",
        f"workspace: {data.get('workspace', '-')}",
        f"checkpoint_dir: {data.get('checkpoint_dir', '-')}",
        f"output_dir: {data.get('output_dir', '-')}",
        f"log_dir: {data.get('log_dir', '-')}",
        "",
    ]

    models = data.get("models", {})
    if isinstance(models, dict):
        for name, model in models.items():
            if isinstance(model, dict):
                lines.extend(summarize_model(name, model))
    else:
        lines.append("Unsupported log schema: models is not a dict.")

    text = "\n".join(lines).rstrip() + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print(text, end="")


if __name__ == "__main__":
    main()
