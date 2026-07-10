#!/usr/bin/env python3
"""Extract real OLiMPiC scan/MusicXML pairs into VocalDive evaluation assets."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from choral_omr_workspace import workspace_paths


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--split", default="train")
    parser.add_argument("--limit", type=int, default=250)
    args = parser.parse_args()
    try:
        import pyarrow.parquet as pq
    except ImportError as exc:
        raise SystemExit("Install pyarrow in the data environment before ingesting OLiMPiC.") from exc

    paths = workspace_paths()
    source = args.source or paths["raw"] / "olimpic" / "data"
    shards = sorted(source.glob(f"{args.split}-*.parquet"))
    if not shards:
        raise FileNotFoundError(f"no {args.split} parquet shards under {source}")
    output_root = paths["normalized"] / "olimpic" / args.split
    image_root, xml_root = output_root / "images", output_root / "musicxml"
    image_root.mkdir(parents=True, exist_ok=True)
    xml_root.mkdir(parents=True, exist_ok=True)
    manifest_path = paths["manifests"] / f"olimpic_{args.split}_systems.jsonl"
    count = 0
    with manifest_path.open("w", encoding="utf-8") as manifest:
        for shard in shards:
            table = pq.ParquetFile(shard).read(columns=["image", "lmx", "musicxml", "score_id", "page_system", "source", "split"])
            for row in table.to_pylist():
                if count >= args.limit:
                    break
                identifier = f"{row['score_id']}__{row['page_system']}".replace("/", "_")
                image_path = image_root / f"{identifier}.png"
                xml_path = xml_root / f"{identifier}.musicxml"
                image_path.write_bytes(row["image"]["bytes"])
                xml_path.write_text(row["musicxml"], encoding="utf-8")
                record = {
                    "id": identifier,
                    "dataset_id": "olimpic",
                    "kind": "real_scan_system",
                    "image_path": str(image_path),
                    "musicxml_path": str(xml_path),
                    "lmx": row["lmx"],
                    "score_id": row["score_id"],
                    "page_system": row["page_system"],
                    "source": row["source"],
                    "split": row["split"],
                }
                manifest.write(json.dumps(record, ensure_ascii=False) + "\n")
                count += 1
            if count >= args.limit:
                break
    print(json.dumps({"manifest": str(manifest_path), "examples": count, "source": str(source)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
