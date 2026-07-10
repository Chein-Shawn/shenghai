#!/usr/bin/env python3
"""Extract paired OpenScore HF Parquet rows for OMR evaluation.

The HF dataset stores image bytes and MusicXML together in Parquet. This
script materializes a small, traceable evaluation pack on the external SSD.
It intentionally keeps real IMSLP scans separate from clean MuseScore renders.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path

from choral_omr_workspace import workspace_paths


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def safe_name(value: str) -> str:
    return "_".join(part for part in value.replace("\\", "/").split("/") if part)[:180]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path)
    parser.add_argument("--limit", type=int, default=20)
    args = parser.parse_args()

    paths = workspace_paths()
    source = args.source or paths["raw"] / "openscore-stringquartets-hf" / "data"
    shards = sorted(source.rglob("*.parquet"))
    if not shards:
        raise FileNotFoundError(f"no Parquet files under {source}")

    output_root = paths["normalized"] / "openscore-stringquartets-hf" / "evaluation-20"
    scan_root = output_root / "image_imslp"
    render_root = output_root / "image_mscore"
    xml_root = output_root / "musicxml"
    for directory in (scan_root, render_root, xml_root):
        directory.mkdir(parents=True, exist_ok=True)
    manifest_path = output_root / "manifest.jsonl"
    stats_path = output_root / "stats.json"

    try:
        import pyarrow.parquet as pq
    except ImportError as exc:
        raise SystemExit("Install pyarrow in the local VocalDive data environment first.") from exc

    count = 0
    with manifest_path.open("w", encoding="utf-8") as manifest:
        for shard in shards:
            parquet = pq.ParquetFile(shard)
            for batch in parquet.iter_batches(
                batch_size=8,
                columns=["image_imslp", "image_mscore", "musicxml", "filename"],
            ):
                for row in batch.to_pylist():
                    if count >= args.limit:
                        break
                    base = f"{count:04d}__{safe_name(row['filename'])}"
                    scan_bytes = row["image_imslp"]["bytes"]
                    render_bytes = row["image_mscore"]["bytes"]
                    scan_path = scan_root / f"{base}.png"
                    render_path = render_root / f"{base}.png"
                    xml_path = xml_root / f"{base}.musicxml"
                    scan_path.write_bytes(scan_bytes)
                    render_path.write_bytes(render_bytes)
                    xml_path.write_text(row["musicxml"], encoding="utf-8")
                    record = {
                        "id": base,
                        "dataset_id": "openscore_string_quartets_hf",
                        "kind": "real_scan_and_rendered_page_pair",
                        "row_index": count,
                        "filename": row["filename"],
                        "image_imslp_path": str(scan_path),
                        "image_mscore_path": str(render_path),
                        "musicxml_path": str(xml_path),
                        "image_imslp_sha256": sha256_bytes(scan_bytes),
                        "image_mscore_sha256": sha256_bytes(render_bytes),
                        "musicxml_chars": len(row["musicxml"]),
                        "created_at": datetime.now(timezone.utc).isoformat(),
                    }
                    manifest.write(json.dumps(record, ensure_ascii=False) + "\n")
                    count += 1
                if count >= args.limit:
                    break
            if count >= args.limit:
                break

    stats = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "dataset_id": "openscore_string_quartets_hf",
        "source": str(source),
        "source_shards": [str(shard) for shard in shards],
        "examples": count,
        "real_scan_field": "image_imslp",
        "clean_render_field": "image_mscore",
        "ground_truth_field": "musicxml",
        "warning": "String quartet pages are multi-staff OMR evaluation data, not SATB choir training data.",
    }
    stats_path.write_text(json.dumps(stats, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest_path), "stats": str(stats_path), "examples": count}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
