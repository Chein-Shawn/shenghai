#!/usr/bin/env python3
"""Download and verify official oemer ONNX checkpoints.

This script intentionally stores large model files outside the git repo by default.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import subprocess
import urllib.error
import urllib.request
from pathlib import Path

ASSETS = {
    "1st_model.onnx": {
        "url": "https://github.com/BreezeWhite/oemer/releases/download/checkpoints/1st_model.onnx",
        "sha256": "37512e858731096439746f60b377c049f07055b4a23ec6eb9a178ce92cfba174",
        "bytes": 70767752,
    },
    "2nd_model.onnx": {
        "url": "https://github.com/BreezeWhite/oemer/releases/download/checkpoints/2nd_model.onnx",
        "sha256": "ed2e1a86ea75712ee6cdc740e96f7a36753543cf9bb980227c071c9256d9d82e",
        "bytes": 38448467,
    },
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(url) as response, destination.open("wb") as output:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
    except urllib.error.URLError:
        # Some macOS Python installs do not have a usable certificate bundle.
        # Fall back to system curl, then still verify the SHA-256 below.
        completed = subprocess.run(["curl", "-L", "-o", str(destination), url], text=True)
        if completed.returncode != 0:
            raise


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output-dir",
        default="/Users/shawn/Documents/Codex/vocaldive-ml/oemer/checkpoints",
        help="Directory for downloaded ONNX checkpoints.",
    )
    parser.add_argument("--manifest", help="Optional JSON manifest output path.")
    args = parser.parse_args()

    output_dir = Path(args.output_dir).expanduser().resolve()
    report = {}
    for filename, metadata in ASSETS.items():
        path = output_dir / filename
        if not path.exists():
            print(f"downloading {filename}...")
            download(metadata["url"], path)
        digest = sha256(path)
        size = path.stat().st_size
        ok = digest == metadata["sha256"] and size == metadata["bytes"]
        report[filename] = {
            "path": str(path),
            "url": metadata["url"],
            "bytes": size,
            "sha256": digest,
            "expected_sha256": metadata["sha256"],
            "verified": ok,
        }
        if not ok:
            print(json.dumps(report[filename], indent=2), file=sys.stderr)
            return 1

    if args.manifest:
        manifest_path = Path(args.manifest).expanduser().resolve()
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
