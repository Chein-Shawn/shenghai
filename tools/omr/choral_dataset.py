#!/usr/bin/env python3
"""Create a traceable manifest for real-image, paired-MusicXML OMR research."""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from choral_lmx import linearize_musicxml
from choral_omr_workspace import workspace_paths


CATALOG = {
    "vocaldive_fixture": {"role": "pipeline smoke test", "url": "local repository fixture"},
    "doremi": {"role": "typeset pretraining", "url": "https://github.com/steinbergmedia/DoReMi/releases"},
    "olimpic": {"role": "real-scan external evaluation", "url": "https://huggingface.co/datasets/zzsi/olimpic"},
    "openscore_string_quartets": {"role": "real-scan multi-staff paired training", "url": "https://huggingface.co/datasets/guangyangmusic/OpenScore-StringQuartets"},
    "openscore_lieder": {"role": "voice-plus-accompaniment paired training", "url": "https://github.com/OpenScore/Lieder"},
    "seils": {"role": "five-voice structural research", "url": "https://github.com/OMR-Research/OMR-Datasets"},
    "deepscoresv2_dense": {"role": "visual symbol pretraining", "url": "https://zenodo.org/records/4012193"},
    "muscima_pp": {"role": "handwritten robustness research", "url": "https://ufal.mff.cuni.cz/muscima"},
    "cvc_muscima": {"role": "distortion and staffline research", "url": "https://dag.cvc.uab.es/dataset/cvc-muscima/"},
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def initialize() -> dict[str, Path]:
    paths = workspace_paths()
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    registry = paths["manifests"] / "dataset_registry.json"
    payload = {
        "created_at": utc_now(),
        "storage_note": "JSONL is canonical because this external SSD cannot support SQLite journaling. A local SQLite index may be rebuilt later.",
        "datasets": CATALOG,
    }
    registry.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return {**paths, "registry": registry}


def register_staff(args: argparse.Namespace) -> dict[str, object]:
    paths = initialize()
    image = args.image.expanduser().resolve()
    musicxml = args.musicxml.expanduser().resolve()
    if not image.is_file() or not musicxml.is_file():
        raise FileNotFoundError("image and MusicXML must both exist")
    tokens = linearize_musicxml(musicxml.read_text(encoding="utf-8"), part_id=args.part_id)
    record = {
        "id": args.id,
        "dataset_id": args.dataset,
        "image_path": str(image),
        "musicxml_path": str(musicxml),
        "part_id": args.part_id,
        "page_index": args.page_index,
        "system_index": args.system_index,
        "staff_index": args.staff_index,
        "bounds": [args.left, args.top, args.width, args.height],
        "tokens": tokens,
        "image_sha256": sha256(image),
        "created_at": utc_now(),
    }
    manifest = paths["manifests"] / "staff_examples.jsonl"
    with manifest.open("a", encoding="utf-8") as stream:
        stream.write(json.dumps(record, ensure_ascii=False) + "\n")
    return {"manifest": str(manifest), "record": record}


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("init")
    register = sub.add_parser("register-staff")
    register.add_argument("--id", required=True)
    register.add_argument("--dataset", required=True, choices=sorted(CATALOG))
    register.add_argument("--image", type=Path, required=True)
    register.add_argument("--musicxml", type=Path, required=True)
    register.add_argument("--part-id")
    register.add_argument("--page-index", type=int, required=True)
    register.add_argument("--system-index", type=int, required=True)
    register.add_argument("--staff-index", type=int, required=True)
    register.add_argument("--left", type=int, required=True)
    register.add_argument("--top", type=int, required=True)
    register.add_argument("--width", type=int, required=True)
    register.add_argument("--height", type=int, required=True)
    args = parser.parse_args()
    result = initialize() if args.command == "init" else register_staff(args)
    print(json.dumps({key: str(value) if isinstance(value, Path) else value for key, value in result.items()}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
