#!/usr/bin/env python3
"""Download public OMR research datasets into the external SSD workspace.

The script intentionally downloads one named dataset at a time. It never puts
large raw assets into git and records a small receipt next to every download.
"""

from __future__ import annotations

import argparse
import json
import shutil
import ssl
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

from choral_omr_workspace import workspace_paths


HF_DATASETS = {
    "olimpic": "zzsi/olimpic",
    "openscore_string_quartets": "guangyangmusic/OpenScore-StringQuartets",
    "openscore_lieder_paired": "guangyangmusic/OpenScore-Lieder",
    "muse_omr_benchmark": "musegroup/omr_benchmark",
}

DIRECT_DOWNLOADS = {
    "deepscoresv2_dense": "https://zenodo.org/records/4012193/files/ds2_dense.tar.gz?download=1",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_receipt(destination: Path, payload: dict[str, object]) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "vocaldive-download-receipt.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def download_hf(name: str) -> Path:
    try:
        from huggingface_hub import snapshot_download
    except ImportError as exc:
        raise SystemExit("Install huggingface-hub in the external data venv first: python -m pip install huggingface-hub") from exc
    paths = workspace_paths()
    destination = paths["raw"] / name
    snapshot_download(repo_id=HF_DATASETS[name], repo_type="dataset", local_dir=destination)
    write_receipt(destination, {"dataset": name, "source": HF_DATASETS[name], "downloaded_at": utc_now(), "kind": "huggingface"})
    return destination


def download_direct(name: str) -> Path:
    paths = workspace_paths()
    destination = paths["raw"] / name
    destination.mkdir(parents=True, exist_ok=True)
    output = destination / "source.tar.gz"
    try:
        import certifi
        context = ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        context = ssl.create_default_context()
    with urllib.request.urlopen(DIRECT_DOWNLOADS[name], context=context) as source, output.open("wb") as target:
        shutil.copyfileobj(source, target)
    write_receipt(destination, {"dataset": name, "source": DIRECT_DOWNLOADS[name], "downloaded_at": utc_now(), "kind": "direct"})
    return output


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dataset", choices=sorted({*HF_DATASETS, *DIRECT_DOWNLOADS}))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    source = HF_DATASETS.get(args.dataset) or DIRECT_DOWNLOADS[args.dataset]
    if args.dry_run:
        print(json.dumps({"dataset": args.dataset, "source": source, "workspace": str(workspace_paths()["raw"])}, indent=2))
        return 0
    destination = download_hf(args.dataset) if args.dataset in HF_DATASETS else download_direct(args.dataset)
    print(json.dumps({"dataset": args.dataset, "destination": str(destination)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
