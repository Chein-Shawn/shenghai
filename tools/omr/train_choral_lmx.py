#!/usr/bin/env python3
"""Small MPS-friendly staff-image to LMX training baseline."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
import torch
from PIL import Image
from torch import nn
from torch.utils.data import DataLoader, Dataset


class StaffDataset(Dataset):
    def __init__(self, manifest: Path, vocab: dict[str, int], width: int, height: int) -> None:
        self.rows = [json.loads(line) for line in manifest.read_text(encoding="utf-8").splitlines() if line.strip()]
        self.vocab, self.width, self.height = vocab, width, height

    def __len__(self) -> int:
        return len(self.rows)

    def __getitem__(self, index: int) -> tuple[torch.Tensor, torch.Tensor]:
        row = self.rows[index]
        image = Image.open(row["image_path"]).convert("L")
        left, top, width, height = row["bounds"]
        image = image.crop((left, top, left + width, top + height)).resize((self.width, self.height))
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
        layer = nn.TransformerDecoderLayer(d_model=hidden, nhead=4, dim_feedforward=hidden * 4, batch_first=True)
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--epochs", type=int, default=1)
    parser.add_argument("--width", type=int, default=768)
    parser.add_argument("--height", type=int, default=192)
    args = parser.parse_args()
    vocab = build_vocab(args.manifest)
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    dataset = StaffDataset(args.manifest, vocab, args.width, args.height)
    loader = DataLoader(dataset, batch_size=1, shuffle=True, collate_fn=lambda batch: collate(batch, vocab["<pad>"]))
    model = StaffToLMX(len(vocab)).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=3e-4)
    criterion = nn.CrossEntropyLoss(ignore_index=vocab["<pad>"])
    model.train()
    for _ in range(args.epochs):
        for images, target in loader:
            logits = model(images.to(device), target[:, :-1].to(device))
            loss = criterion(logits.reshape(-1, logits.size(-1)), target[:, 1:].to(device).reshape(-1))
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    torch.save({"state_dict": model.state_dict(), "vocab": vocab, "width": args.width, "height": args.height}, args.output)
    print(json.dumps({"checkpoint": str(args.output), "device": str(device), "examples": len(dataset), "vocab": len(vocab)}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
