#!/usr/bin/env python3
"""Small staff/system CTC baseline for image-to-sequence diagnostics."""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
from PIL import Image, ImageEnhance, ImageOps
from torch import nn
from torch.utils.data import DataLoader, Dataset


def load_rows(path: Path, limit: int | None) -> list[dict[str, object]]:
    rows = [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    return rows[:limit] if limit else rows


def pad_crop(image: Image.Image, bounds: list[int], width: int, height: int, augment: bool) -> Image.Image:
    left, top, crop_width, crop_height = bounds
    crop = image.crop((left, top, left + crop_width, top + crop_height)).convert("L")
    if augment:
        if random.random() < 0.5: crop = ImageEnhance.Contrast(crop).enhance(random.uniform(0.8, 1.2))
        if random.random() < 0.25: crop = ImageEnhance.Brightness(crop).enhance(random.uniform(0.9, 1.1))
    contained = ImageOps.contain(crop, (width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("L", (width, height), 255)
    canvas.paste(contained, ((width - contained.width) // 2, (height - contained.height) // 2))
    return canvas


class StaffDataset(Dataset):
    def __init__(self, rows: list[dict[str, object]], vocab: dict[str, int], width: int, height: int, augment: bool) -> None:
        self.rows, self.vocab = rows, vocab; self.width, self.height, self.augment = width, height, augment

    def __len__(self) -> int: return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        row = self.rows[index]
        with Image.open(str(row["image_path"])) as source: image = pad_crop(source, list(row["bounds"]), self.width, self.height, self.augment)
        pixels = torch.from_numpy(np.asarray(image, dtype=np.float32) / 255.0).unsqueeze(0)
        tokens = row.get("tokens") or row.get("lmx_tokens") or []
        return pixels, torch.tensor([self.vocab[str(token)] for token in tokens], dtype=torch.long)


class CTCRecognizer(nn.Module):
    def __init__(self, vocabulary_size: int, hidden: int = 128) -> None:
        super().__init__()
        self.encoder = nn.Sequential(nn.Conv2d(1, 32, 5, stride=2, padding=2), nn.BatchNorm2d(32), nn.ReLU(), nn.Conv2d(32, 64, 3, stride=2, padding=1), nn.BatchNorm2d(64), nn.ReLU(), nn.Conv2d(64, hidden, 3, stride=2, padding=1), nn.BatchNorm2d(hidden), nn.ReLU())
        self.rnn = nn.LSTM(hidden, hidden, num_layers=2, bidirectional=True, batch_first=True, dropout=0.1)
        self.head = nn.Linear(hidden * 2, vocabulary_size)

    def forward(self, image: torch.Tensor) -> torch.Tensor:
        features = self.encoder(image).mean(dim=2).transpose(1, 2); logits, _ = self.rnn(features)
        return self.head(logits).log_softmax(dim=-1).transpose(0, 1)


def make_vocab(rows: list[dict[str, object]]) -> dict[str, int]:
    tokens = sorted({str(token) for row in rows for token in (row.get("tokens") or row.get("lmx_tokens") or [])})
    return {token: index + 1 for index, token in enumerate(tokens)}


def collate(batch: list[tuple[torch.Tensor, torch.Tensor]]) -> tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
    images, targets = zip(*batch); lengths = torch.tensor([target.numel() for target in targets], dtype=torch.long)
    return torch.stack(images), torch.cat(list(targets)), lengths


def evaluate(model: nn.Module, loader: DataLoader, device: torch.device) -> dict[str, float]:
    model.eval(); loss_fn = nn.CTCLoss(blank=0, zero_infinity=True); total = 0.0
    with torch.no_grad():
        for images, targets, target_lengths in loader:
            logits = model(images.to(device)); input_lengths = torch.full((images.size(0),), logits.size(0), dtype=torch.long)
            total += float(loss_fn(logits, targets.to(device), input_lengths, target_lengths).item())
    return {"loss": total / max(1, len(loader)), "examples": len(loader.dataset)}


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--manifest", type=Path, required=True); parser.add_argument("--validation-manifest", type=Path); parser.add_argument("--output", type=Path, required=True); parser.add_argument("--metrics-output", type=Path); parser.add_argument("--epochs", type=int, default=10); parser.add_argument("--limit", type=int); parser.add_argument("--width", type=int, default=1024); parser.add_argument("--height", type=int, default=128); parser.add_argument("--lr", type=float, default=3e-4); parser.add_argument("--seed", type=int, default=20260711); parser.add_argument("--device", choices=("auto", "cpu", "mps"), default="auto")
    args = parser.parse_args(); random.seed(args.seed); np.random.seed(args.seed); torch.manual_seed(args.seed)
    train_rows = load_rows(args.manifest, args.limit); validation_rows = load_rows(args.validation_manifest, None) if args.validation_manifest else []; vocab = make_vocab(train_rows)
    # torch.ctc_loss is not implemented on MPS in some PyTorch releases; use CPU by default.
    device = torch.device("mps" if args.device == "mps" else "cpu")
    train_loader = DataLoader(StaffDataset(train_rows, vocab, args.width, args.height, True), batch_size=1, shuffle=True, collate_fn=collate)
    validation_loader = DataLoader(StaffDataset(validation_rows, vocab, args.width, args.height, False), batch_size=1, shuffle=False, collate_fn=collate) if validation_rows else None
    model = CTCRecognizer(len(vocab) + 1).to(device); optimizer = torch.optim.AdamW(model.parameters(), lr=args.lr); loss_fn = nn.CTCLoss(blank=0, zero_infinity=True); history = []
    for epoch in range(1, args.epochs + 1):
        model.train(); total = 0.0
        for images, targets, target_lengths in train_loader:
            logits = model(images.to(device)); input_lengths = torch.full((images.size(0),), logits.size(0), dtype=torch.long); loss = loss_fn(logits, targets.to(device), input_lengths, target_lengths)
            optimizer.zero_grad(); loss.backward(); torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0); optimizer.step(); total += float(loss.item())
        record = {"epoch": epoch, "train_loss": total / max(1, len(train_loader))}
        if validation_loader is not None: record["validation"] = evaluate(model, validation_loader, device)
        history.append(record); print(json.dumps(record), flush=True)
    args.output.parent.mkdir(parents=True, exist_ok=True); torch.save({"state_dict": model.state_dict(), "vocab": vocab, "width": args.width, "height": args.height, "blank": 0}, args.output)
    metrics = {"checkpoint": str(args.output), "device": str(device), "examples": len(train_rows), "vocabulary": len(vocab), "epochs": args.epochs, "history": history}; metrics_path = args.metrics_output or args.output.with_suffix(".metrics.json"); metrics_path.parent.mkdir(parents=True, exist_ok=True); metrics_path.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8"); return 0


if __name__ == "__main__": raise SystemExit(main())
