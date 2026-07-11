#!/usr/bin/env python3
"""Convert DeepScoresV2 dense annotations into VocalDive tile manifests.

DeepScores stores full-page images and object annotations. The v1 detector
expects horizontal system-like tiles, so this adapter creates a manifest of
overlapping tile bounds without duplicating the source PNGs.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from omr_v1_schema import model_kind


DEFAULT_ROOT = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/normalized/deepscoresv2_dense/ds2_dense")
TILE_WIDTH = 1024
TILE_HEIGHT = 256
STRIDE_X = 896
STRIDE_Y = 224


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_source(path: Path) -> dict[str, object]:
    return json.loads(path.read_text(encoding="utf-8"))


def category_name(categories: dict[str, object], ids: list[str]) -> str:
    for category_id in ids:
        category = categories.get(str(category_id), {})
        name = str(category.get("name", "")) if isinstance(category, dict) else ""
        if name:
            return name
    return "other"


def bbox(annotation: dict[str, object]) -> tuple[float, float, float, float]:
    values = [float(value) for value in annotation.get("a_bbox", [])]
    if len(values) != 4:
        return 0, 0, 0, 0
    left, top, right, bottom = values
    return min(left, right), min(top, bottom), max(left, right), max(top, bottom)


def intersect(box: tuple[float, float, float, float], tile: tuple[int, int, int, int]) -> tuple[float, float, float, float] | None:
    left, top, right, bottom = box
    tile_left, tile_top, tile_right, tile_bottom = tile
    clipped = max(left, tile_left), max(top, tile_top), min(right, tile_right), min(bottom, tile_bottom)
    if clipped[2] <= clipped[0] or clipped[3] <= clipped[1]:
        return None
    return clipped


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--split", choices=("train", "test"), default="train")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--max-images", type=int)
    args = parser.parse_args()
    source = args.source.expanduser().resolve()
    metadata = load_source(source / ("deepscores_train.json" if args.split == "train" else "deepscores_test.json"))
    categories = metadata.get("categories", {})
    annotations = metadata.get("annotations", {})
    images = list(metadata.get("images", []))
    if args.max_images:
        images = images[:args.max_images]
    output = args.output or source.parent / "manifests" / f"symbol-heatmap-{args.split}.jsonl"
    output.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    source_kind_counts: Counter[str] = Counter()
    model_kind_counts: Counter[str] = Counter()
    for image in images:
        image_name = str(image["filename"])
        image_path = source / "images" / image_name
        width, height = int(image["width"]), int(image["height"])
        objects = []
        for annotation_id in image.get("ann_ids", []):
            annotation = annotations.get(str(annotation_id), {})
            source_kind = category_name(categories, list(annotation.get("cat_id", [])))
            left, top, right, bottom = bbox(annotation)
            if right <= left or bottom <= top:
                continue
            mapped = model_kind(source_kind)
            objects.append((source_kind, mapped, (left, top, right, bottom)))
            source_kind_counts[source_kind] += 1
            if mapped:
                model_kind_counts[mapped] += 1
        for tile_top in range(0, max(1, height - TILE_HEIGHT + 1), STRIDE_Y):
            if tile_top + TILE_HEIGHT < height and tile_top + TILE_HEIGHT + STRIDE_Y >= height:
                tile_top = height - TILE_HEIGHT
            for tile_left in range(0, max(1, width - TILE_WIDTH + 1), STRIDE_X):
                if tile_left + TILE_WIDTH < width and tile_left + TILE_WIDTH + STRIDE_X >= width:
                    tile_left = width - TILE_WIDTH
                tile = (tile_left, tile_top, min(width, tile_left + TILE_WIDTH), min(height, tile_top + TILE_HEIGHT))
                symbols = []
                for source_kind, mapped, object_box in objects:
                    clipped = intersect(object_box, tile)
                    if clipped is None:
                        continue
                    x0, y0, x1, y1 = clipped
                    symbols.append({
                        "source_kind": source_kind,
                        "model_kind": mapped,
                        "trainable": mapped is not None,
                        "x": (x0 - tile[0]) / TILE_WIDTH,
                        "y": (y0 - tile[1]) / TILE_HEIGHT,
                        "width": (x1 - x0) / TILE_WIDTH,
                        "height": (y1 - y0) / TILE_HEIGHT,
                    })
                if not symbols:
                    continue
                rows.append({
                    "id": f"{image_name}__x{tile[0]}_y{tile[1]}",
                    "dataset_id": "deepscoresv2_dense",
                    "score_id": image_name.rsplit("--page-", 1)[0],
                    "split": args.split,
                    "image_path": str(image_path),
                    "system_bounds": [tile[0], tile[1], tile[2] - tile[0], tile[3] - tile[1]],
                    "symbols": symbols,
                    "source_kind_counts": dict(Counter(symbol["source_kind"] for symbol in symbols)),
                    "schema_version": "vocaldive-symbols-v1",
                })
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    summary = {
        "created_at": now(),
        "dataset_id": "deepscoresv2_dense",
        "source": str(source),
        "split": args.split,
        "source_images": len(images),
        "tile_examples": len(rows),
        "source_kind_counts": dict(source_kind_counts),
        "model_kind_counts": dict(model_kind_counts),
        "manifest": str(output),
        "tile_size": [TILE_WIDTH, TILE_HEIGHT],
        "stride": [STRIDE_X, STRIDE_Y],
    }
    summary_path = output.with_suffix(".summary.json")
    summary_path.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

