#!/usr/bin/env python3
"""Convert a small OpenScore String Quartets .mscx sample to MusicXML/PDF.

The generated PDF is a clean MuseScore render. It is useful for parser and
renderer checks, but it is not a real scanned-page input for OMR evaluation.
Large conversion runs belong on the external ML workspace, not in git.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from choral_omr_workspace import workspace_paths


def find_sources(root: Path, limit: int | None) -> list[Path]:
    sources = sorted(
        path for path in (root / "scores").rglob("*.mscx")
        if not path.name.startswith("._")
    )
    return sources if limit is None else sources[:limit]


def safe_stem(source: Path, root: Path) -> str:
    relative = source.relative_to(root / "scores").with_suffix("")
    return "__".join(part.replace(" ", "_") for part in relative.parts)


def convert(executable: Path, source: Path, output_dir: Path) -> dict[str, object]:
    # Use the source path relative to the repository so output names stay stable.
    scores_root = next(parent for parent in source.parents if parent.name == "scores")
    stem = safe_stem(source, scores_root.parent)
    xml_path = output_dir / f"{stem}.musicxml"
    pdf_path = output_dir / f"{stem}.pdf"
    record: dict[str, object] = {
        "source": str(source),
        "musicxml": str(xml_path),
        "pdf": str(pdf_path),
        "ok": False,
    }
    for destination in (xml_path, pdf_path):
        command = [str(executable), "-o", str(destination), str(source)]
        completed = subprocess.run(command, text=True, capture_output=True)
        if completed.returncode != 0:
            record["error"] = completed.stderr[-2000:] or completed.stdout[-2000:]
            record["failed_output"] = str(destination)
            return record
    record["ok"] = True
    return record


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source-root", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--musescore", type=Path, default=Path("/Applications/MuseScore 4.app/Contents/MacOS/mscore"))
    parser.add_argument("--limit", type=int, default=3)
    args = parser.parse_args()

    paths = workspace_paths()
    source_root = args.source_root or (paths["raw"] / "openscore-string-quartets")
    output_dir = args.output_dir or (paths["normalized"] / "openscore-string-quartets" / "clean-renders")
    executable = args.musescore.expanduser()
    if not executable.exists():
        raise SystemExit(f"MuseScore executable not found: {executable}")
    sources = find_sources(source_root, args.limit)
    if not sources:
        raise SystemExit(f"No .mscx files found under {source_root / 'scores'}")
    output_dir.mkdir(parents=True, exist_ok=True)
    records = [convert(executable, source, output_dir) for source in sources]
    receipt = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "dataset": "openscore-string-quartets",
        "source_repository": "https://github.com/OpenScore/StringQuartets",
        "source_format": "MuseScore .mscx",
        "rendering_tool": str(executable),
        "note": "PDF outputs are clean renders, not real scanned pages.",
        "records": records,
    }
    receipt_path = output_dir.parent / "openscore-stringquartets-conversion-receipt.json"
    receipt_path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(receipt, ensure_ascii=False, indent=2))
    return 0 if all(record["ok"] for record in records) else 1


if __name__ == "__main__":
    raise SystemExit(main())
