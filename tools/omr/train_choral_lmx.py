#!/usr/bin/env python3
"""Small MPS-friendly staff-image to LMX training baseline."""

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


class StaffDataset(Dataset):
    def __init__(self, manifest: Path, vocab: dict[str, int], width: int, height: int, *, limit: int | None = None, preserve_aspect: bool = True, augment: bool = False) -> None:
        rows = [json.loads(line) for line in manifest.read_text(encoding="utf-8").splitlines() if line.strip()]
        self.rows = rows[:limit] if limit else rows
        self.vocab, self.width, self.height = vocab, width, height
        self.preserve_aspect, self.augment = preserve_aspect, augment

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        row = self.rows[index]
        image = Image.open(row["image_path"]).convert("L")
        left, top, width, height = row["bounds"]
        image = image.crop((left, top, left + width, top + height))
        if self.augment:
            if random.random() < 0.5:
                image = ImageEnhance.Contrast(image).enhance(random.uniform(0.8, 1.2))
            if random.random() < 0.25:
                image = ImageEnhance.Brightness(image).enhance(random.uniform(0.9, 1.1))
        if self.preserve_aspect:
            contained = ImageOps.contain(image, (self.width, self.height), Image.Resampling.LANCZOS)
            canvas = Image.new("L", (self.width, self.height), 255)
            canvas.paste(contained, ((self.width - contained.width) // 2, (self.height - contained.height) // 2))
            image = canvas
        else:
            image = image.resize((self.width, self.height), Image.Resampling.LANCZOS)
        pixels = torch.from_numpy(np.asarray(image, dtype=np.float32) / 255.0).unsqueeze(0)
        ids = [self.vocab.get(token, self.vocab["<unk>"]) for token in row["tokens"]]
        return pixels, torch.tensor(ids, dtype=torch.long)


class StaffToLMX(nn.Module):
    def __init__(self, vocab_size: int, hidden: int = 128) -> None:
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Conv2d(1, 32, 5, stride=2, padding=2), nn.GELU(),
            nn.Conv2d(32, 64, 3, stride=2, padding=1), nn.GELU(),
            nn.Conv2d(64, hidden, 3, stride=2, padding=1), nn.GELU(),
        )
        self.embedding = nn.Embedding(vocab_size, hidden)
        self.position = nn.Embedding(1024, hidden)
        layer = nn.TransformerDecoderLayer(d_model=hidden, nhead=4, dim_feedforward=hidden * 4, dropout=0.1, batch_first=True)
        self.decoder = nn.TransformerDecoder(layer, num_layers=2)
        self.head = nn.Linear(hidden, vocab_size)

    def forward(self, image: torch.Tensor, target_in: torch.Tensor) -> torch.Tensor:
        features = self.encoder(image).flatten(2).transpose(1, 2)
        positions = torch.arange(target_in.size(1), device=target_in.device).unsqueeze(0)
        target = self.embedding(target_in) + self.position(positions)
        mask = nn.Transformer.generate_square_subsequent_mask(target_in.size(1), device=target_in.device)
        return self.head(self.decoder(target, features, tgt_mask=mask))


def build_vocab(manifest: Path) -> dict[str, int]:
    tokens = {"<pad>", "<unk>"}
    for line in manifest.read_text(encoding="utf-8").splitlines():
        if line.strip():
            tokens.update(json.loads(line)["tokens"])
    return {token: index for index, token in enumerate(sorted(tokens))}


def collate(batch: list[tuple[torch.Tensor, torch.Tensor]], pad: int) -> tuple[torch.Tensor, torch.Tensor]:
    images, sequences = zip(*batch)
    target = torch.full((len(sequences), max(sequence.size(0) for sequence in sequences)), pad, dtype=torch.long)
    for index, sequence in enumerate(sequences):
        target[index, :sequence.size(0)] = sequence
    return torch.stack(list(images)), target


@torch.no_grad()
def evaluate(model: nn.Module, loader: DataLoader, pad: int, device: torch.device) -> dict[str, float]:
    model.eval()
    total_loss = 0.0
    batches = 0
    correct = 0
    tokens = 0
    exact = 0
    examples = 0
    criterion = nn.CrossEntropyLoss(ignore_index=pad)
    for images, target in loader:
        if target.size(1) < 2:
            continue
        target_in = target[:, :-1].to(device)
        target_out = target[:, 1:].to(device)
        logits = model(images.to(device), target_in)
        total_loss += float(criterion(logits.reshape(-1, logits.size(-1)), target_out.reshape(-1)).item())
        batches += 1
        prediction = logits.argmax(dim=-1)
        mask = target_out != pad
        correct += int(((prediction == target_out) & mask).sum().item())
        tokens += int(mask.sum().item())
        exact += int(((prediction == target_out) | ~mask).all(dim=1).sum().item())
        examples += target.size(0)
    return {
        "loss": total_loss / batches if batches else 0.0,
        "token_accuracy": correct / tokens if tokens else 0.0,
        "exact_sequence_accuracy": exact / examples if examples else 0.0,
        "examples": examples,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--width", type=int, default=768)
    parser.add_argument("--height", type=int, default=192)
    parser.add_argument("--validation-manifest", type=Path)
    parser.add_argument("--test-manifest", type=Path)
    parser.add_argument("--metrics-output", type=Path)
    parser.add_argument("--checkpoint-dir", type=Path)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--stretch", action="store_true", help="Use legacy distortion instead of aspect-preserving padding")
    parser.add_argument("--augmentation", action="store_true")
    parser.add_argument("--patience", type=int, default=4)
    parser.add_argument("--device", choices=("auto", "cpu", "mps"), default="auto")
    parser.add_argument("--seed", type=int, default=20260711)
    args = parser.parse_args()
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    vocab = build_vocab(args.manifest)
    if args.device == "mps" or (args.device == "auto" and torch.backends.mps.is_available()):
        device = torch.device("mps")
    else:
        device = torch.device("cpu")
    dataset = StaffDataset(args.manifest, vocab, args.width, args.height, limit=args.limit, preserve_aspect=not args.stretch, augment=args.augmentation)
    loader = DataLoader(dataset, batch_size=1, shuffle=True, collate_fn=lambda batch: collate(batch, vocab["<pad>"]))
    validation_loader = None
    test_loader = None
    if args.validation_manifest:
        validation_loader = DataLoader(
            StaffDataset(args.validation_manifest, vocab, args.width, args.height, preserve_aspect=not args.stretch),
            batch_size=1,
            shuffle=False,
            collate_fn=lambda batch: collate(batch, vocab["<pad>"]),
        )
    if args.test_manifest:
        test_loader = DataLoader(
            StaffDataset(args.test_manifest, vocab, args.width, args.height, preserve_aspect=not args.stretch),
            batch_size=1,
            shuffle=False,
            collate_fn=lambda batch: collate(batch, vocab["<pad>"]),
        )
    model = StaffToLMX(len(vocab)).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4)
    criterion = nn.CrossEntropyLoss(ignore_index=vocab["<pad>"])
    history = []
    best_validation_loss = float("inf")
    stale_epochs = 0
    model.train()
    for epoch in range(1, args.epochs + 1):
        epoch_loss = 0.0
        batches = 0
        for images, target in loader:
            logits = model(images.to(device), target[:, :-1].to(device))
            loss = criterion(logits.reshape(-1, logits.size(-1)), target[:, 1:].to(device).reshape(-1))
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 5.0)
            optimizer.step()
            epoch_loss += float(loss.item())
            batches += 1
        record = {"epoch": epoch, "train_loss": epoch_loss / batches if batches else 0.0}
        if validation_loader is not None:
            record["validation"] = evaluate(model, validation_loader, vocab["<pad>"], device)
        if test_loader is not None:
            record["test"] = evaluate(model, test_loader, vocab["<pad>"], device)
        history.append(record)
        print(json.dumps(record), flush=True)
        if validation_loader is not None:
            validation_loss = float(record["validation"]["loss"])
            if validation_loss < best_validation_loss - 1e-4:
                best_validation_loss = validation_loss
                stale_epochs = 0
                if args.checkpoint_dir:
                    args.checkpoint_dir.mkdir(parents=True, exist_ok=True)
                    torch.save({"state_dict": model.state_dict(), "vocab": vocab, "width": args.width, "height": args.height, "epoch": epoch, "validation_loss": validation_loss}, args.checkpoint_dir / "best.pt")
            else:
                stale_epochs += 1
                if stale_epochs >= args.patience:
                    break
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "vocab": vocab, "width": args.width, "height": args.height}, args.output)
    metrics = {
        "checkpoint": str(args.output),
        "device": str(device),
        "examples": len(dataset),
        "vocab": len(vocab),
        "epochs": args.epochs,
        "completed_epochs": len(history),
        "preserve_aspect": not args.stretch,
        "augmentation": args.augmentation,
        "early_stopping_patience": args.patience,
        "seed": args.seed,
        "history": history,
    }
    metrics_output = args.metrics_output or args.output.with_suffix(".metrics.json")
    metrics_output.parent.mkdir(parents=True, exist_ok=True)
    metrics_output.write_text(json.dumps(metrics, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(metrics))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
