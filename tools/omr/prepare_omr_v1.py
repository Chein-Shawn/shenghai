#!/usr/bin/env python3
"""Prepare the fixed-schema v1 OMR metadata outside the git repository.

This tool never edits raw CPDL manifests or downloaded score files.  It
creates reports, source-level splits, and system-relative symbol manifests
under the external-SSD prepared dataset.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image

from omr_v1_schema import CORE_SYMBOL_KINDS, MODEL_SCHEMA_VERSION, model_kind, schema_payload


DEFAULT_VERSION = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1")
DEFAULT_TRAINING = DEFAULT_VERSION / "processed/training-manifest.jsonl"
DEFAULT_SYMBOLS = DEFAULT_VERSION / "symbols/symbol-annotation-manifest.jsonl"


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_jsonl(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")


def stable_score_split(score_id: str) -> str:
    """Assign a score deterministically without leaking pages across splits."""

    digest = hashlib.sha256(score_id.encode("utf-8")).digest()
    bucket = int.from_bytes(digest[:8], "big") % 100
    if bucket < 70:
        return "train"
    if bucket < 85:
        return "validation"
    return "test"


def image_size(path: Path) -> tuple[int, int] | None:
    try:
        with Image.open(path) as image:
            return image.size
    except (OSError, ValueError):
        return None


def audit(version: Path, training_path: Path, symbols_path: Path) -> dict[str, object]:
    training = load_jsonl(training_path)
    symbols = load_jsonl(symbols_path)
    annotated = [row for row in symbols if row.get("annotation_status") == "annotated"]
    symbol_counts: Counter[str] = Counter()
    model_counts: Counter[str] = Counter()
    unsupported_counts: Counter[str] = Counter()
    for row in annotated:
        for symbol in row.get("symbols", []):
            source_kind = str(symbol.get("kind", "other"))
            symbol_counts[source_kind] += 1
            mapped = model_kind(source_kind)
            if mapped is None:
                unsupported_counts[source_kind] += 1
            else:
                model_counts[mapped] += 1
    score_ids = {str(row.get("score_id", "")) for row in training if row.get("score_id")}
    image_missing = sum(not Path(str(row.get("image_path", ""))).is_file() for row in training)
    musicxml_missing = sum(not Path(str(row.get("musicxml_fragment_path", ""))).is_file() for row in training)
    payload = {
        "created_at": now(),
        "schema_version": MODEL_SCHEMA_VERSION,
        "training_manifest": str(training_path),
        "symbol_manifest": str(symbols_path),
        "training_records": len(training),
        "training_scores": len(score_ids),
        "annotated_symbol_records": len(annotated),
        "pending_symbol_records": sum(row.get("annotation_status") not in {"annotated", "skipped"} for row in symbols),
        "image_missing": image_missing,
        "musicxml_fragment_missing": musicxml_missing,
        "model_classes": list(CORE_SYMBOL_KINDS),
        "source_symbol_counts": dict(symbol_counts),
        "model_symbol_counts": dict(model_counts),
        "unsupported_symbol_counts": dict(unsupported_counts),
        "note": "Unsupported labels remain metadata and are not v1 supervised targets.",
    }
    output = version / "reports/omr-v1-audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return payload


def build_splits(version: Path, training_path: Path) -> dict[str, object]:
    rows = load_jsonl(training_path)
    grouped: dict[str, list[dict[str, object]]] = defaultdict(list)
    for row in rows:
        score_id = str(row.get("score_id", ""))
        if score_id:
            grouped[score_id].append(row)
    split_rows: dict[str, list[dict[str, object]]] = {"train": [], "validation": [], "test": []}
    for score_id, score_rows in sorted(grouped.items()):
        split = stable_score_split(score_id)
        for row in score_rows:
            derived = dict(row)
            derived["split"] = split
            derived["split_schema"] = "score_hash_70_15_15_v1"
            split_rows[split].append(derived)
    for split, values in split_rows.items():
        write_jsonl(version / f"splits/omr-v1-{split}.jsonl", values)
    summary = {
        "created_at": now(),
        "schema_version": MODEL_SCHEMA_VERSION,
        "split_by": "score_id",
        "rule": "sha256(score_id) bucketed 70/15/15",
        "scores": {split: len({str(row["score_id"]) for row in values}) for split, values in split_rows.items()},
        "systems": {split: len(values) for split, values in split_rows.items()},
    }
    (version / "reports/omr-v1-split-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def relative_symbols(row: dict[str, object]) -> tuple[list[dict[str, object]], int]:
    image_path = Path(str(row.get("image_path", "")))
    size = image_size(image_path)
    bounds = [float(value) for value in row.get("system_bounds", [0, 0, 0, 0])]
    left, top, width, height = bounds
    if size is None or width <= 0 or height <= 0:
        return [], 0
    page_width, page_height = size
    derived: list[dict[str, object]] = []
    unsupported = 0
    for symbol in row.get("symbols", []):
        source_kind = str(symbol.get("kind", "other"))
        x = (float(symbol.get("x", 0)) * page_width - left) / width
        y = (float(symbol.get("y", 0)) * page_height - top) / height
        symbol_width = float(symbol.get("width", 0)) * page_width / width
        symbol_height = float(symbol.get("height", 0)) * page_height / height
        right = min(1.0, x + symbol_width)
        bottom = min(1.0, y + symbol_height)
        x, y = max(0.0, x), max(0.0, y)
        symbol_width, symbol_height = max(0.0, right - x), max(0.0, bottom - y)
        mapped = model_kind(source_kind)
        if mapped is None:
            unsupported += 1
        derived.append({
            "source_kind": source_kind,
            "model_kind": mapped,
            "trainable": mapped is not None and symbol_width > 0 and symbol_height > 0,
            "x": x,
            "y": y,
            "width": symbol_width,
            "height": symbol_height,
        })
    return derived, unsupported


def build_symbol_manifest(version: Path, symbols_path: Path) -> dict[str, object]:
    rows = load_jsonl(symbols_path)
    output_rows: list[dict[str, object]] = []
    skipped = Counter()
    unsupported = 0
    for row in rows:
        if row.get("annotation_status") != "annotated":
            skipped[str(row.get("annotation_status", "unknown"))] += 1
            continue
        symbols, unsupported_count = relative_symbols(row)
        unsupported += unsupported_count
        output_rows.append({
            "id": row.get("id"),
            "dataset_id": row.get("dataset_id", "cpdl_v1"),
            "score_id": row.get("score_id"),
            "title": row.get("title"),
            "page_index": row.get("page_index"),
            "system_index": row.get("system_index"),
            "image_path": row.get("image_path"),
            "system_bounds": row.get("system_bounds"),
            "measure_start": row.get("measure_start"),
            "measure_end": row.get("measure_end"),
            "split": stable_score_split(str(row.get("score_id", ""))),
            "review_status": "verified",
            "source_review_note": row.get("source_review_note", ""),
            "annotation_note": row.get("annotation_note", ""),
            "symbols": symbols,
            "schema_version": MODEL_SCHEMA_VERSION,
        })
    output = version / "symbols/omr-v1-symbol-manifest.jsonl"
    write_jsonl(output, output_rows)
    schema_path = version / "symbols/omr-v1-symbol-schema.json"
    schema_path.parent.mkdir(parents=True, exist_ok=True)
    schema_path.write_text(json.dumps(schema_payload(), ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    summary = {
        "created_at": now(),
        "schema_version": MODEL_SCHEMA_VERSION,
        "manifest": str(output),
        "schema": str(schema_path),
        "annotated_records": len(output_rows),
        "skipped_records": dict(skipped),
        "unsupported_symbols": unsupported,
        "model_classes": list(CORE_SYMBOL_KINDS),
    }
    (version / "reports/omr-v1-symbol-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("audit", "build-splits", "build-symbol-manifest"))
    parser.add_argument("--version", type=Path, default=DEFAULT_VERSION)
    parser.add_argument("--training-manifest", type=Path, default=DEFAULT_TRAINING)
    parser.add_argument("--symbol-manifest", type=Path, default=DEFAULT_SYMBOLS)
    args = parser.parse_args()
    version = args.version.expanduser().resolve()
    if args.command == "audit":
        result = audit(version, args.training_manifest.expanduser().resolve(), args.symbol_manifest.expanduser().resolve())
    elif args.command == "build-splits":
        result = build_splits(version, args.training_manifest.expanduser().resolve())
    else:
        result = build_symbol_manifest(version, args.symbol_manifest.expanduser().resolve())
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

