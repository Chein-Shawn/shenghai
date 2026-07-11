#!/usr/bin/env python3
"""Propose system crops for manual review in the CPDL-v1 dataset.

This is intentionally a candidate generator, not ground-truth annotation. The
output keeps measure_start/measure_end empty until a reviewer confirms the PDF
to MusicXML alignment.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


def find_systems(path: Path) -> list[list[int]]:
    image = np.asarray(Image.open(path).convert("L"))
    height, width = image.shape
    binary = cv2.threshold(image, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (max(24, width // 12), 1))
    horizontal = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel)
    row_score = (horizontal > 0).mean(axis=1)
    active = row_score > 0.035
    runs: list[tuple[int, int]] = []
    start = None
    for index, value in enumerate(np.r_[active, False]):
        if value and start is None:
            start = index
        elif not value and start is not None:
            if index - start >= 1:
                runs.append((start, index - 1))
            start = None
    if not runs:
        return [[0, 0, width, height]]

    line_centers = [(left + right) // 2 for left, right in runs]
    staff_groups: list[list[int]] = []
    current = [line_centers[0]]
    staff_gap = max(12, round(height * 0.018))
    for center in line_centers[1:]:
        if center - current[-1] <= staff_gap:
            current.append(center)
        else:
            staff_groups.append(current)
            current = [center]
    staff_groups.append(current)

    systems: list[list[list[int]]] = []
    current_system = [staff_groups[0]]
    system_gap = max(42, round(height * 0.055))
    for group in staff_groups[1:]:
        if group[0] - current_system[-1][-1] <= system_gap:
            current_system.append(group)
        else:
            systems.append(current_system)
            current_system = [group]
    systems.append(current_system)

    padding = max(24, round(height * 0.018))
    result = []
    for system in systems:
        top = max(0, min(group[0] for group in system) - padding)
        bottom = min(height, max(group[-1] for group in system) + padding)
        result.append([0, top, width, bottom - top])
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=Path, default=Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1"))
    args = parser.parse_args()
    version = args.version.expanduser().resolve()
    source = version / "manifests/page-manifest.jsonl"
    output = version / "manifests/system-candidate-manifest.jsonl"
    rows = []
    for line in source.read_text(encoding="utf-8").splitlines():
        page = json.loads(line)
        for page_index, image_path in enumerate(page["page_png_paths"], start=1):
            bounds = find_systems(Path(image_path))
            with Image.open(image_path) as image:
                width, height = image.size
            for system_index, box in enumerate(bounds, start=1):
                rows.append({
                    "id": f"{page['score_id']}-p{page_index:03d}-s{system_index:02d}",
                    "score_id": page["score_id"],
                    "title": page["title"],
                    "split": page["split"],
                    "page_index": page_index,
                    "system_index": system_index,
                    "image_path": image_path,
                    "musicxml_path": page["musicxml_path"],
                    "bounds": box,
                    "bounds_normalized": [box[0] / width, box[1] / height, box[2] / width, box[3] / height],
                    "measure_start": None,
                    "measure_end": None,
                    "lmx_tokens": None,
                    "alignment_status": "manual_review_required",
                    "detector": "horizontal_staffline_heuristic_v1",
                })
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    print(json.dumps({"manifest": str(output), "pages": len({(r['score_id'], r['page_index']) for r in rows}), "system_candidates": len(rows), "status": "manual_review_required"}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
