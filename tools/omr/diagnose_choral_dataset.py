#!/usr/bin/env python3
"""Report data risks before training a choral OMR model."""

from __future__ import annotations

import argparse
import json
import statistics
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

from PIL import Image


def rows_from(path: Path, limit: int | None) -> list[dict[str, object]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return rows[:limit] if limit else rows


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, round((len(ordered) - 1) * fraction)))
    return round(ordered[index], 4)


def xml_is_parseable(path: Path) -> bool | None:
    if not path.is_file():
        return None
    try:
        ET.parse(path)
        return True
    except (ET.ParseError, OSError):
        return False


def analyze(rows: list[dict[str, object]]) -> dict[str, object]:
    token_counts: Counter[str] = Counter()
    sequence_lengths: list[int] = []
    crop_ratios: list[float] = []
    page_ratios: list[float] = []
    score_ids: set[str] = set()
    missing_images = parseable_fragments = unparseable_fragments = 0
    source_notes = Counter(); selected_parts = Counter()
    duplicate_ids = Counter(str(row.get("id", "")) for row in rows)
    for row in rows:
        score_ids.add(str(row.get("score_id", "")))
        tokens = row.get("tokens") or row.get("lmx_tokens") or []
        if isinstance(tokens, list):
            token_counts.update(str(token) for token in tokens); sequence_lengths.append(len(tokens))
        note = str(row.get("review_note") or row.get("source_review_note") or "").strip()
        if note: source_notes[note] += 1
        for part in row.get("selected_parts", []) or []: selected_parts[str(part)] += 1
        image_path = Path(str(row.get("image_path", ""))); bounds = row.get("bounds") or []
        if image_path.is_file():
            try:
                with Image.open(image_path) as image: page_width, page_height = image.size
                if page_height: page_ratios.append(page_width / page_height)
                if len(bounds) == 4 and float(bounds[3]) > 0: crop_ratios.append(float(bounds[2]) / float(bounds[3]))
            except (OSError, ValueError, TypeError, ZeroDivisionError): missing_images += 1
        else: missing_images += 1
        parsed = xml_is_parseable(Path(str(row.get("musicxml_fragment_path", ""))))
        if parsed is True: parseable_fragments += 1
        elif parsed is False: unparseable_fragments += 1
    duplicates = {key: count for key, count in duplicate_ids.items() if key and count > 1}
    return {
        "rows": len(rows), "scores": len(score_ids), "score_ids": sorted(score_ids),
        "sequence_length": {"min": min(sequence_lengths) if sequence_lengths else None, "max": max(sequence_lengths) if sequence_lengths else None, "mean": round(statistics.mean(sequence_lengths), 3) if sequence_lengths else None, "p50": percentile([float(x) for x in sequence_lengths], .5), "p95": percentile([float(x) for x in sequence_lengths], .95)},
        "vocabulary": {"unique_tokens": len(token_counts), "total_tokens": sum(token_counts.values()), "single_occurrence_tokens": sum(1 for count in token_counts.values() if count == 1), "top_30": token_counts.most_common(30)},
        "image": {"missing_or_unreadable": missing_images, "page_aspect_ratio": {"min": round(min(page_ratios), 4) if page_ratios else None, "max": round(max(page_ratios), 4) if page_ratios else None, "mean": round(statistics.mean(page_ratios), 4) if page_ratios else None}, "crop_aspect_ratio": {"min": round(min(crop_ratios), 4) if crop_ratios else None, "max": round(max(crop_ratios), 4) if crop_ratios else None, "mean": round(statistics.mean(crop_ratios), 4) if crop_ratios else None}},
        "musicxml_fragments": {"parseable": parseable_fragments, "unparseable": unparseable_fragments, "missing": len(rows) - parseable_fragments - unparseable_fragments},
        "selected_parts": selected_parts.most_common(), "review_notes": source_notes.most_common(20), "duplicate_ids": duplicates,
        "warnings": ["A large vocabulary relative to row count makes direct sequence generation unstable.", "Page/system crops should use aspect-preserving padding, not stretching.", "Score-level splits must remain immutable to avoid page leakage."],
    }


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--manifest", type=Path, required=True); parser.add_argument("--output", type=Path, required=True); parser.add_argument("--limit", type=int)
    args = parser.parse_args(); report = analyze(rows_from(args.manifest.expanduser().resolve(), args.limit)); report["manifest"] = str(args.manifest.expanduser().resolve()); report["limit"] = args.limit
    output = args.output.expanduser().resolve(); output.parent.mkdir(parents=True, exist_ok=True); output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({key: report[key] for key in ("rows", "scores", "sequence_length", "vocabulary", "image", "musicxml_fragments")}, ensure_ascii=False, indent=2)); return 0


if __name__ == "__main__": raise SystemExit(main())
