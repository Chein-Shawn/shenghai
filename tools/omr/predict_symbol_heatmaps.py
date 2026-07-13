#!/usr/bin/env python3
"""Render model-suggestion previews for the CPDL symbol annotation reviewer.

The previews are derived artifacts. They never write back to the source page
or annotation manifests, and the reviewer treats them as visual suggestions
only until a human saves boxes.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image

from omr_v1_schema import CORE_SYMBOL_KINDS, PRIMARY_SYMBOL_KINDS
from train_symbol_heatmap import HEIGHT, OUTPUT_SCALE, WIDTH, SymbolHeatmapNet, contain_geometry, select_device


COLORS = {
    "notehead": (154, 243, 208),
    "rest": (112, 215, 243),
    "barline": (255, 155, 125),
    "clef": (243, 202, 117),
    "key_signature": (183, 246, 255),
    "time_signature": (183, 246, 255),
    "accidental": (255, 155, 125),
    "stem": (154, 243, 208),
    "beam": (112, 215, 243),
    "dot": (243, 202, 117),
}


def load_rows(path: Path, limit: int | None) -> list[dict[str, object]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return rows[:limit] if limit else rows


def prepare_crop(row: dict[str, object]) -> tuple[Image.Image, tuple[int, int, int, int]]:
    with Image.open(str(row["image_path"])) as source:
        source = source.convert("L")
        left, top, width, height = [int(value) for value in row["system_bounds"]]
        crop = source.crop((left, top, left + width, top + height))
    resized_width, resized_height, offset_x, offset_y = contain_geometry(crop.width, crop.height)
    canvas = Image.new("L", (WIDTH, HEIGHT), 255)
    canvas.paste(crop.resize((resized_width, resized_height), Image.Resampling.LANCZOS), (offset_x, offset_y))
    return canvas, (resized_width, resized_height, offset_x, offset_y)


def load_model(path: Path, device: torch.device) -> SymbolHeatmapNet:
    payload = torch.load(path, map_location="cpu", weights_only=False)
    if payload.get("schema") and list(payload["schema"]) != list(CORE_SYMBOL_KINDS):
        raise ValueError(f"Checkpoint schema does not match v1: {path}")
    model = SymbolHeatmapNet()
    model.load_state_dict(payload["state_dict"])
    return model.to(device).eval()


def render_preview(canvas: Image.Image, probabilities: np.ndarray, threshold: float) -> Image.Image:
    base = np.asarray(canvas.convert("RGB"), dtype=np.float32)
    overlay = np.zeros_like(base)
    alpha = np.zeros(base.shape[:2], dtype=np.float32)
    for index, kind in enumerate(CORE_SYMBOL_KINDS):
        if kind not in PRIMARY_SYMBOL_KINDS:
            continue
        channel = probabilities[index]
        mask = np.clip((channel - threshold) / max(1e-6, 1.0 - threshold), 0.0, 1.0)
        if not np.any(mask):
            continue
        color = np.asarray(COLORS[kind], dtype=np.float32)
        overlay = np.where(mask[..., None] > alpha[..., None], color, overlay)
        alpha = np.maximum(alpha, mask * 0.6)
    composite = base * (1.0 - alpha[..., None]) + overlay * alpha[..., None]
    return Image.fromarray(np.clip(composite, 0, 255).astype(np.uint8), "RGB")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--checkpoint", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--output-manifest", type=Path, required=True)
    parser.add_argument("--threshold", type=float, default=0.5)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--device", choices=("auto", "cpu", "mps"), default="auto")
    args = parser.parse_args()

    device = select_device(args.device)
    checkpoint = args.checkpoint.expanduser().resolve()
    model = load_model(checkpoint, device)
    rows = load_rows(args.manifest.expanduser().resolve(), args.limit)
    output_dir = args.output_dir.expanduser().resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    results = []
    for index, row in enumerate(rows, start=1):
        canvas, _ = prepare_crop(row)
        pixels = torch.from_numpy(np.asarray(canvas, dtype=np.float32) / 255.0).unsqueeze(0).unsqueeze(0).to(device)
        with torch.no_grad():
            logits = model(pixels)
            probabilities = torch.sigmoid(logits)[0]
            probabilities = torch.nn.functional.interpolate(probabilities.unsqueeze(0), size=(HEIGHT, WIDTH), mode="bilinear", align_corners=False)[0]
        preview = render_preview(canvas, probabilities.cpu().numpy(), args.threshold)
        identifier = str(row["id"])
        path = output_dir / f"{identifier}.png"
        preview.save(path)
        results.append({
            "id": identifier,
            "prediction_preview_path": str(path),
            "checkpoint": str(checkpoint),
            "threshold": args.threshold,
            "primary_classes": list(PRIMARY_SYMBOL_KINDS),
        })
        print(json.dumps({"index": index, "total": len(rows), "id": identifier}), flush=True)
    args.output_manifest.parent.mkdir(parents=True, exist_ok=True)
    args.output_manifest.write_text("".join(json.dumps(row) + "\n" for row in results), encoding="utf-8")
    print(json.dumps({"preview_count": len(results), "manifest": str(args.output_manifest), "device": str(device)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
