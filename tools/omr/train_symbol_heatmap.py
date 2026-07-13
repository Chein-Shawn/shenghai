#!/usr/bin/env python3
"""Train the fixed-shape VocalDive symbol heatmap detector.

The same Core ML-friendly network is used for DeepScores visual pretraining
and later CPDL fine-tuning. CPDL rows can explicitly mask channels that have
not been exhaustively annotated, so optional labels never become false
background examples.
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn.functional as F
from PIL import Image, ImageEnhance
from torch import nn
from torch.utils.data import DataLoader, Dataset

from omr_v1_schema import CORE_SYMBOL_KINDS, PRIMARY_SYMBOL_KINDS, target_index


WIDTH = 1024
HEIGHT = 256
OUTPUT_SCALE = 4


def load_rows(path: Path, limit: int | None = None, seed: int = 0) -> list[dict[str, object]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    if limit and limit < len(rows):
        return random.Random(seed).sample(rows, limit)
    return rows


def contain_geometry(source_width: int, source_height: int) -> tuple[int, int, int, int]:
    scale = min(WIDTH / source_width, HEIGHT / source_height)
    resized_width = max(1, round(source_width * scale))
    resized_height = max(1, round(source_height * scale))
    return resized_width, resized_height, (WIDTH - resized_width) // 2, (HEIGHT - resized_height) // 2


def supervision_mask(row: dict[str, object]) -> torch.Tensor:
    declared = row.get("supervised_model_kinds")
    kinds = declared if isinstance(declared, list) else CORE_SYMBOL_KINDS
    enabled = {str(kind) for kind in kinds}
    return torch.tensor([1.0 if kind in enabled else 0.0 for kind in CORE_SYMBOL_KINDS], dtype=torch.float32)


def crop_and_target(row: dict[str, object], augment: bool) -> tuple[Image.Image, torch.Tensor, torch.Tensor]:
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
    mask = supervision_mask(row)
    for symbol in row.get("symbols", []):
        index = target_index(str(symbol.get("source_kind", symbol.get("kind", "other"))))
        if index is None or not symbol.get("trainable", True) or mask[index] == 0:
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
    return canvas, target, mask


class SymbolDataset(Dataset):
    def __init__(self, rows: list[dict[str, object]], augment: bool) -> None:
        self.rows = rows
        self.augment = augment

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
        image, target, mask = crop_and_target(self.rows[index], self.augment)
        pixels = torch.from_numpy(np.asarray(image, dtype=np.float32) / 255.0).unsqueeze(0)
        return pixels, target, mask


class SymbolHeatmapNet(nn.Module):
    """Small fixed-shape detector that exports cleanly to Core ML."""

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


def masked_loss(logits: torch.Tensor, target: torch.Tensor, channel_mask: torch.Tensor, pos_weight: torch.Tensor) -> torch.Tensor:
    raw = F.binary_cross_entropy_with_logits(logits, target, pos_weight=pos_weight, reduction="none")
    mask = channel_mask[:, :, None, None].expand_as(raw)
    return (raw * mask).sum() / mask.sum().clamp_min(1.0)


def empty_counts() -> dict[str, dict[str, int]]:
    return {kind: {"tp": 0, "fp": 0, "fn": 0, "support": 0} for kind in CORE_SYMBOL_KINDS}


def update_counts(counts: dict[str, dict[str, int]], logits: torch.Tensor, target: torch.Tensor, channel_mask: torch.Tensor, threshold: float) -> None:
    predicted = logits.sigmoid() >= threshold
    expected = target >= 0.5
    for index, kind in enumerate(CORE_SYMBOL_KINDS):
        eligible = channel_mask[:, index] >= 0.5
        if not bool(eligible.any()):
            continue
        valid_predicted = predicted[eligible, index]
        valid_expected = expected[eligible, index]
        counts[kind]["tp"] += int((valid_predicted & valid_expected).sum().item())
        counts[kind]["fp"] += int((valid_predicted & ~valid_expected).sum().item())
        counts[kind]["fn"] += int((~valid_predicted & valid_expected).sum().item())
        counts[kind]["support"] += int(valid_expected.sum().item())


def summarize_counts(counts: dict[str, dict[str, int]]) -> dict[str, object]:
    per_class: dict[str, dict[str, float | int]] = {}
    primary_iou = []
    for kind, values in counts.items():
        tp, fp, fn = values["tp"], values["fp"], values["fn"]
        precision = tp / max(1, tp + fp)
        recall = tp / max(1, tp + fn)
        iou = tp / max(1, tp + fp + fn)
        per_class[kind] = {**values, "precision": precision, "recall": recall, "iou": iou}
        if kind in PRIMARY_SYMBOL_KINDS and values["support"]:
            primary_iou.append(iou)
    return {"per_class": per_class, "primary_mean_iou": sum(primary_iou) / max(1, len(primary_iou))}


@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader, device: torch.device, pos_weight: torch.Tensor, thresholds: list[float]) -> dict[str, object]:
    model.eval()
    total_loss = 0.0
    batches = 0
    counts_by_threshold = {threshold: empty_counts() for threshold in thresholds}
    for images, target, channel_mask in loader:
        images, target, channel_mask = images.to(device), target.to(device), channel_mask.to(device)
        logits = model(images)
        total_loss += float(masked_loss(logits, target, channel_mask, pos_weight).item())
        for threshold, counts in counts_by_threshold.items():
            update_counts(counts, logits, target, channel_mask, threshold)
        batches += 1
    threshold_metrics = {str(threshold): summarize_counts(counts) for threshold, counts in counts_by_threshold.items()}
    best_threshold = max(thresholds, key=lambda threshold: float(threshold_metrics[str(threshold)]["primary_mean_iou"]))
    selected = threshold_metrics[str(best_threshold)]
    return {
        "loss": total_loss / max(1, batches),
        "examples": len(loader.dataset),
        "best_threshold": best_threshold,
        "threshold_metrics": threshold_metrics,
        **selected,
    }


def select_device(requested: str) -> torch.device:
    if requested == "mps" or (requested == "auto" and torch.backends.mps.is_available()):
        return torch.device("mps")
    return torch.device("cpu")


def load_checkpoint(model: SymbolHeatmapNet, path: Path) -> None:
    payload = torch.load(path, map_location="cpu", weights_only=False)
    schema = payload.get("schema")
    if schema and list(schema) != list(CORE_SYMBOL_KINDS):
        raise ValueError(f"Checkpoint schema does not match v1: {path}")
    model.load_state_dict(payload["state_dict"])


def write_json(path: Path, payload: dict[str, object]) -> None:
    """Persist progress after each epoch so an interrupted long run stays auditable."""
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--validation-manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--metrics-output", type=Path)
    parser.add_argument("--checkpoint-dir", type=Path)
    parser.add_argument("--init-checkpoint", type=Path)
    parser.add_argument("--epochs", type=int, default=10)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--validation-limit", type=int)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--num-workers", type=int, default=0)
    parser.add_argument("--learning-rate", type=float, default=3e-4)
    parser.add_argument("--metric-thresholds", default="0.1,0.2,0.3,0.4,0.5", help="Comma-separated probability thresholds for detector metrics")
    parser.add_argument("--device", choices=("auto", "cpu", "mps"), default="auto")
    parser.add_argument("--seed", type=int, default=20260713)
    args = parser.parse_args()

    thresholds = sorted({float(value) for value in args.metric_thresholds.split(",") if value.strip()})
    if not thresholds or any(value <= 0 or value >= 1 for value in thresholds):
        raise SystemExit("Metric thresholds must be comma-separated values between 0 and 1.")

    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    train_rows = load_rows(args.manifest, args.limit, args.seed)
    validation_rows = load_rows(args.validation_manifest, args.validation_limit, args.seed + 1) if args.validation_manifest else []
    if not train_rows:
        raise SystemExit("No training rows found")
    device = select_device(args.device)
    loader_options = {"num_workers": max(0, args.num_workers)}
    if args.num_workers > 0:
        loader_options["persistent_workers"] = True
    train_loader = DataLoader(SymbolDataset(train_rows, augment=True), batch_size=args.batch_size, shuffle=True, **loader_options)
    validation_loader = DataLoader(SymbolDataset(validation_rows, augment=False), batch_size=args.batch_size, shuffle=False, **loader_options) if validation_rows else None
    model = SymbolHeatmapNet()
    if args.init_checkpoint:
        load_checkpoint(model, args.init_checkpoint.expanduser().resolve())
    model = model.to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=args.learning_rate)
    pos_weight = torch.tensor(20.0, device=device)
    history = []
    best_score = float("-inf")
    best_epoch: int | None = None
    best_checkpoint: str | None = None
    metrics_path = args.metrics_output or args.output.with_suffix(".metrics.json")
    for epoch in range(1, args.epochs + 1):
        model.train()
        total_loss = 0.0
        batches = 0
        for images, target, channel_mask in train_loader:
            images, target, channel_mask = images.to(device), target.to(device), channel_mask.to(device)
            loss = masked_loss(model(images), target, channel_mask, pos_weight)
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            total_loss += float(loss.item())
            batches += 1
        record: dict[str, object] = {"epoch": epoch, "train_loss": total_loss / max(1, batches)}
        if validation_loader is not None:
            validation = evaluate(model, validation_loader, device, pos_weight, thresholds)
            record["validation"] = validation
            score = float(validation["primary_mean_iou"])
        else:
            score = -float(record["train_loss"])
        history.append(record)
        print(json.dumps(record), flush=True)
        if score > best_score:
            best_score = score
            best_epoch = epoch
            if args.checkpoint_dir:
                args.checkpoint_dir.mkdir(parents=True, exist_ok=True)
                checkpoint_path = args.checkpoint_dir / "best-symbol-heatmap.pt"
                torch.save({"state_dict": model.state_dict(), "schema": list(CORE_SYMBOL_KINDS), "width": WIDTH, "height": HEIGHT, "output_scale": OUTPUT_SCALE, "epoch": epoch, "metric": score}, checkpoint_path)
                best_checkpoint = str(checkpoint_path)
        write_json(metrics_path, {
            "checkpoint": str(args.output), "device": str(device), "examples": len(train_rows), "validation_examples": len(validation_rows),
            "classes": list(CORE_SYMBOL_KINDS), "primary_trainable_classes": list(PRIMARY_SYMBOL_KINDS), "epochs_requested": args.epochs,
            "batch_size": args.batch_size, "num_workers": args.num_workers, "metric_thresholds": thresholds, "history": history,
            "best": {"epoch": best_epoch, "primary_mean_iou": best_score, "checkpoint": best_checkpoint},
            "completed": False,
            "warning": "A small run is a pipeline check, not evidence of choir-domain generalization.",
        })
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "schema": list(CORE_SYMBOL_KINDS), "width": WIDTH, "height": HEIGHT, "output_scale": OUTPUT_SCALE}, args.output)
    metrics = {
        "checkpoint": str(args.output), "device": str(device), "examples": len(train_rows), "validation_examples": len(validation_rows),
        "classes": list(CORE_SYMBOL_KINDS), "primary_trainable_classes": list(PRIMARY_SYMBOL_KINDS), "epochs": args.epochs,
        "batch_size": args.batch_size, "num_workers": args.num_workers, "metric_thresholds": thresholds, "history": history,
        "best": {"epoch": best_epoch, "primary_mean_iou": best_score, "checkpoint": best_checkpoint},
        "warning": "A small run is a pipeline check, not evidence of choir-domain generalization.",
    }
    metrics["completed"] = True
    write_json(metrics_path, metrics)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
