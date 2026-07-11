#!/usr/bin/env python3
"""Build a versioned CPDL paired dataset outside the VocalDive git repo.

The raw CPDL manifest remains the source of truth. This tool validates files,
splits by score (never by page), and optionally rasterizes paired PDFs. It does
not claim that a PDF and MusicXML are the same edition; that remains a review
field for later system/measure alignment.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import random
import re
import subprocess
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET


WORKSPACE = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr")
MANIFEST = WORKSPACE / "normalized/cpdl/manifests/cpdl-manifest.jsonl"


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def safe_name(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("_")[:120] or "score"


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def xml_stats(path: Path) -> dict[str, object]:
    try:
        if path.suffix.lower() == ".mxl":
            with zipfile.ZipFile(path) as archive:
                container = ET.fromstring(archive.read("META-INF/container.xml"))
                rootfile = next(node for node in container.iter() if node.tag.rsplit("}", 1)[-1] == "rootfile")
                root = ET.fromstring(archive.read(rootfile.attrib["full-path"]))
        else:
            root = ET.parse(path).getroot()
        local = lambda tag: tag.rsplit("}", 1)[-1]
        parts = [node for node in root if local(node.tag) == "part"]
        measures = sum(1 for part in parts for node in part if local(node.tag) == "measure")
        notes = sum(1 for node in root.iter() if local(node.tag) == "note" and not any(local(x.tag) == "rest" for x in node))
        lyrics = sum(1 for node in root.iter() if local(node.tag) == "lyric")
        return {"valid": True, "parts": len(parts), "measures": measures, "playable_notes": notes, "lyrics": lyrics}
    except (ET.ParseError, KeyError, StopIteration, zipfile.BadZipFile, OSError) as error:
        return {"valid": False, "error": str(error)}


def pdf_stats(path: Path) -> dict[str, object]:
    try:
        if path.read_bytes()[:4] != b"%PDF":
            return {"valid": False, "error": "missing PDF magic bytes"}
        result = subprocess.run(["pdfinfo", str(path)], check=True, capture_output=True, text=True)
        pages = next((int(line.split(":", 1)[1].strip()) for line in result.stdout.splitlines() if line.startswith("Pages:")), 0)
        return {"valid": pages > 0, "pages": pages}
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        return {"valid": False, "error": str(error)}


def load_rows() -> list[dict[str, object]]:
    if not MANIFEST.exists():
        raise SystemExit(f"Missing CPDL manifest: {MANIFEST}")
    latest: dict[str, dict[str, object]] = {}
    for line in MANIFEST.read_text(encoding="utf-8").splitlines():
        if line.strip():
            row = json.loads(line)
            latest[str(row.get("title", ""))] = row
    return list(latest.values())


def quality_report(version: Path) -> list[dict[str, object]]:
    rows = []
    for row in load_rows():
        if row.get("pairing_status") != "paired":
            continue
        pdf = Path(str(row["pdf_path"]))
        musicxml = Path(str(row["musicxml_path"]))
        pdf_info = pdf_stats(pdf) if pdf.is_file() else {"valid": False, "error": "PDF missing"}
        xml_info = xml_stats(musicxml) if musicxml.is_file() else {"valid": False, "error": "MusicXML missing"}
        valid = bool(pdf_info.get("valid") and xml_info.get("valid") and xml_info.get("parts", 0) and xml_info.get("measures", 0))
        rows.append({
            "score_id": safe_name(str(row.get("title", "score"))),
            "title": row.get("title"),
            "voicing": row.get("voicing"),
            "voice_counts": row.get("voice_counts", {}),
            "kind": row.get("kind"),
            "pdf_path": str(pdf),
            "musicxml_path": str(musicxml),
            "pdf_sha256": file_sha256(pdf) if pdf.is_file() else None,
            "musicxml_sha256": file_sha256(musicxml) if musicxml.is_file() else None,
            "pdf": pdf_info,
            "musicxml": xml_info,
            "quality_status": "candidate" if valid else "review-needed",
            "edition_alignment": "manual_review_required",
            "research_only": True,
            "created_at": now(),
        })
    version.mkdir(parents=True, exist_ok=True)
    output = version / "manifests/quality-report.jsonl"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    summary = {
        "created_at": now(),
        "version": version.name,
        "records": len(rows),
        "quality": dict(Counter(row["quality_status"] for row in rows)),
        "note": "Candidate means parseable and paired; PDF/MusicXML edition alignment still requires review.",
    }
    (version / "reports").mkdir(exist_ok=True)
    (version / "reports/quality-summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))
    return rows


def split_dataset(version: Path, seed: int) -> None:
    source = version / "manifests/quality-report.jsonl"
    rows = [json.loads(line) for line in source.read_text().splitlines() if line.strip() and '"quality_status": "candidate"' in line]
    random.Random(seed).shuffle(rows)
    n = len(rows)
    train_end = round(n * 0.70)
    validation_end = train_end + round(n * 0.15)
    for name, subset in (("train", rows[:train_end]), ("validation", rows[train_end:validation_end]), ("test", rows[validation_end:])):
        path = version / f"splits/{name}.jsonl"
        path.parent.mkdir(parents=True, exist_ok=True)
        for row in subset:
            row["split"] = name
        path.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in subset), encoding="utf-8")
    report = {"version": version.name, "seed": seed, "split_by": "score_id", "train": train_end, "validation": len(rows[train_end:validation_end]), "test": len(rows[validation_end:])}
    (version / "reports/split-summary.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


def render_dataset(version: Path, dpi: int) -> None:
    rows = []
    for split in ("train", "validation", "test"):
        path = version / f"splits/{split}.jsonl"
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            if line.strip():
                rows.append((split, json.loads(line)))
    output = version / "manifests/page-manifest.jsonl"
    rendered = []
    for split, row in rows:
        destination = version / f"pages/{split}/{row['score_id']}"
        destination.mkdir(parents=True, exist_ok=True)
        prefix = destination / "page"
        subprocess.run(["pdftoppm", "-png", "-r", str(dpi), row["pdf_path"], str(prefix)], check=True, capture_output=True)
        pages = [str(path) for path in sorted(destination.glob("page-*.png"))]
        rendered.append({"score_id": row["score_id"], "title": row["title"], "split": split, "pdf_path": row["pdf_path"], "musicxml_path": row["musicxml_path"], "page_png_paths": pages, "alignment_status": "system_review_required"})
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rendered), encoding="utf-8")
    print(json.dumps({"version": version.name, "scores": len(rendered), "pages": sum(len(row["page_png_paths"]) for row in rendered), "dpi": dpi, "manifest": str(output)}, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("quality-report", "split", "render"):
        item = sub.add_parser(command)
        item.add_argument("--version", type=Path, default=WORKSPACE / "prepared/cpdl-v1")
        item.add_argument("--seed", type=int, default=20260711)
        item.add_argument("--dpi", type=int, default=300)
    args = parser.parse_args()
    version = args.version.expanduser().resolve()
    if args.command == "quality-report":
        quality_report(version)
    elif args.command == "split":
        split_dataset(version, args.seed)
    else:
        render_dataset(version, args.dpi)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
