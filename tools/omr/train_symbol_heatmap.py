#!/usr/bin/env python3
"""MPS-friendly baseline for the fixed VocalDive v1 symbol heatmaps.

This is deliberately a small detector, not the final OMR model. It proves
that system-relative boxes can become fixed Core ML-friendly heatmaps before
larger public datasets and more human annotations are added.
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageEnhance
from torch import nn
from torch.utils.data import DataLoader, Dataset

from omr_v1_schema import CORE_SYMBOL_KINDS, target_index


WIDTH = 1024
HEIGHT = 256
OUTPUT_SCALE = 4


def load_rows(path: Path, limit: int | None = None) -> list[dict[str, object]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return rows[:limit] if limit else rows


def contain_geometry(source_width: int, source_height: int) -> tuple[int, int, int, int]:
    scale = min(WIDTH / source_width, HEIGHT / source_height)
    resized_width = max(1, round(source_width * scale))
    resized_height = max(1, round(source_height * scale))
    offset_x = (WIDTH - resized_width) // 2
    offset_y = (HEIGHT - resized_height) // 2
    return resized_width, resized_height, offset_x, offset_y


def crop_and_target(row: dict[str, object], augment: bool) -> tuple[Image.Image, torch.Tensor]:
    with Image.open(str(row["image_path"])) as source:
        source = source.convert("L")
        left, top, crop_width, crop_height = [int(value) for value in row["system_bounds"]]
        crop = source.crop((left, top, left + crop_width, top + crop_height))
    if augment:
        if random.random() < 0.5:
            crop = ImageEnhance.Contrast(crop).enhance(random.uniform(0.85, 1.15))
        if random.random() < 0.25:
            crop = ImageEnhance.Brightness(crop).enhance(random.uniform(0.9, 1.1))
    resized_width, resized_height, offset_x, offset_y = contain_geometry(crop.width, crop.height)
    resized = crop.resize((resized_width, resized_height), Image.Resampling.LANCZOS)
    canvas = Image.new("L", (WIDTH, HEIGHT), 255)
    canvas.paste(resized, (offset_x, offset_y))
    target = torch.zeros((len(CORE_SYMBOL_KINDS), HEIGHT // OUTPUT_SCALE, WIDTH // OUTPUT_SCALE), dtype=torch.float32)
    for symbol in row.get("symbols", []):
        index = target_index(str(symbol.get("source_kind", symbol.get("kind", "other"))))
        if index is None or not symbol.get("trainable", True):
            continue
        x = float(symbol.get("x", 0)) * resized_width + offset_x
        y = float(symbol.get("y", 0)) * resized_height + offset_y
        right = (float(symbol.get("x", 0)) + float(symbol.get("width", 0))) * resized_width + offset_x
        bottom = (float(symbol.get("y", 0)) + float(symbol.get("height", 0))) * resized_height + offset_y
        x0 = max(0, min(WIDTH // OUTPUT_SCALE - 1, int(x / OUTPUT_SCALE)))
        y0 = max(0, min(HEIGHT // OUTPUT_SCALE - 1, int(y / OUTPUT_SCALE)))
        x1 = max(x0 + 1, min(WIDTH // OUTPUT_SCALE, int(np.ceil(right / OUTPUT_SCALE))))
        y1 = max(y0 + 1, min(HEIGHT // OUTPUT_SCALE, int(np.ceil(bottom / OUTPUT_SCALE))))
        target[index, y0:y1, x0:x1] = 1.0
    return canvas, target


class SymbolDataset(Dataset):
    def __init__(self, rows: list[dict[str, object]], augment: bool) -> None:
        self.rows = rows
        self.augment = augment

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        image, target = crop_and_target(self.rows[index], self.augment)
        pixels = torch.from_numpy(np.asarray(image, dtype=np.float32) / 255.0).unsqueeze(0)
        return pixels, target


class SymbolHeatmapNet(nn.Module):
    """Small fixed-shape network that exports cleanly to Core ML."""

    def __init__(self, channels: int = len(CORE_SYMBOL_KINDS)) -> None:
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Conv2d(1, 32, 5, stride=2, padding=2),
            nn.ReLU(),
            nn.Conv2d(32, 64, 3, stride=2, padding=1),
            nn.ReLU(),
            nn.Conv2d(64, 96, 3, padding=1),
            nn.ReLU(),
            nn.Conv2d(96, channels, 1),
        )

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        return self.encoder(image)


@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> dict[str, float]:
    model.eval()
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=torch.tensor(20.0, device=device))
    total_loss = 0.0
    positives = 0
    predicted_positives = 0
    batches = 0
    for images, target in loader:
        logits = model(images.to(device))
        total_loss += float(loss_fn(logits, target.to(device)).item())
        predicted_positives += int((logits.sigmoid() >= 0.5).sum().item())
        positives += int(target.sum().item())
        batches += 1
    return {
        "loss": total_loss / max(1, batches),
        "target_positive_pixels": positives,
        "predicted_positive_pixels": predicted_positives,
        "examples": len(loader.dataset),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--validation-manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--metrics-output", type=Path)
    parser.add_argument("--checkpoint-dir", type=Path)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--validation-limit", type=int)
    parser.add_argument("--device", choices=("auto", "cpu", "mps"), default="auto")
    parser.add_argument("--seed", type=int, default=20260711)
    args = parser.parse_args()
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    train_rows = load_rows(args.manifest, args.limit)
    validation_rows = load_rows(args.validation_manifest, args.validation_limit) if args.validation_manifest else []
    if not train_rows:
        raise SystemExit("No training rows found")
    if args.device == "mps" or (args.device == "auto" and torch.backends.mps.is_available()):
        device = torch.device("mps")
    else:
        device = torch.device("cpu")
    train_loader = DataLoader(SymbolDataset(train_rows, augment=True), batch_size=1, shuffle=True)
    validation_loader = DataLoader(SymbolDataset(validation_rows, augment=False), batch_size=1, shuffle=False) if validation_rows else None
    model = SymbolHeatmapNet().to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4)
    loss_fn = nn.BCEWithLogitsLoss(pos_weight=torch.tensor(20.0, device=device))
    history = []
    best_loss = float("inf")
    for epoch in range(1, args.epochs + 1):
        model.train()
        total_loss = 0.0
        for images, target in train_loader:
            loss = loss_fn(model(images.to(device)), target.to(device))
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            total_loss += float(loss.item())
        record = {"epoch": epoch, "train_loss": total_loss / max(1, len(train_loader))}
        if validation_loader is not None:
            record["validation"] = evaluate(model, validation_loader, device)
            current_loss = float(record["validation"]["loss"])
        else:
            current_loss = float(record["train_loss"])
        history.append(record)
        print(json.dumps(record), flush=True)
        if current_loss < best_loss:
            best_loss = current_loss
            if args.checkpoint_dir:
                args.checkpoint_dir.mkdir(parents=True, exist_ok=True)
                torch.save({"state_dict": model.state_dict(), "schema": list(CORE_SYMBOL_KINDS), "width": WIDTH, "height": HEIGHT, "output_scale": OUTPUT_SCALE, "epoch": epoch}, args.checkpoint_dir / "best-symbol-heatmap.pt")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "schema": list(CORE_SYMBOL_KINDS), "width": WIDTH, "height": HEIGHT, "output_scale": OUTPUT_SCALE}, args.output)
    metrics = {"checkpoint": str(args.output), "device": str(device), "examples": len(train_rows), "classes": list(CORE_SYMBOL_KINDS), "epochs": args.epochs, "history": history, "warning": "A one-record or small smoke test is not evidence of generalization."}
    metrics_path = args.metrics_output or args.output.with_suffix(".metrics.json")
    metrics_path.parent.mkdir(parents=True, exist_ok=True)
    metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
