#!/usr/bin/env python3
"""Prepare the first real SATB VocalDive fixture from scanned/clean PDFs + MXL."""

from __future__ import annotations

import argparse
import copy
import json
import re
import subprocess
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

from choral_lmx import linearize_musicxml
from choral_omr_workspace import workspace_paths


SOURCES = {
    "scanned_pdf": "I stood on the river of Jordan_scanned.pdf",
    "clean_pdf": "I stood on the river of Jordan_clean.pdf",
    "mxl": "I stood on the river of Jordan.mxl",
}

# Manually verified from the three photographed pages. Coordinates are relative
# to each page so the same layout works for the different scanned/clean sizes.
SYSTEM_LAYOUT = [
    {"page": 1, "measure_start": 1, "measure_end": 4, "y": 0.16, "height": 0.20},
    {"page": 1, "measure_start": 5, "measure_end": 8, "y": 0.38, "height": 0.20},
    {"page": 1, "measure_start": 9, "measure_end": 12, "y": 0.59, "height": 0.20},
    {"page": 1, "measure_start": 13, "measure_end": 16, "y": 0.79, "height": 0.18},
    {"page": 2, "measure_start": 17, "measure_end": 20, "y": 0.09, "height": 0.20},
    {"page": 2, "measure_start": 21, "measure_end": 24, "y": 0.33, "height": 0.20},
    {"page": 2, "measure_start": 25, "measure_end": 28, "y": 0.57, "height": 0.20},
    {"page": 2, "measure_start": 29, "measure_end": 32, "y": 0.80, "height": 0.17},
    {"page": 3, "measure_start": 33, "measure_end": 36, "y": 0.09, "height": 0.20},
    {"page": 3, "measure_start": 37, "measure_end": 40, "y": 0.33, "height": 0.20},
    {"page": 3, "measure_start": 41, "measure_end": 44, "y": 0.57, "height": 0.20},
    {"page": 3, "measure_start": 45, "measure_end": 49, "y": 0.80, "height": 0.17},
]


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def safe_name(value: str) -> str:
    value = re.sub(r"[^A-Za-z0-9._-]+", "_", value)
    return value.strip("_") or "satb-score"


def render_pdf(pdf: Path, output_dir: Path, prefix: str) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    base = output_dir / prefix
    subprocess.run(
        ["pdftoppm", "-png", "-r", "150", str(pdf), str(base)],
        check=True,
        capture_output=True,
        text=True,
    )
    return sorted(output_dir.glob(f"{prefix}-*.png"))


def extract_mxl(mxl: Path, destination: Path) -> ET.Element:
    with zipfile.ZipFile(mxl) as archive:
        container = ET.fromstring(archive.read("META-INF/container.xml"))
        rootfile = next(node for node in container.iter() if local_name(node.tag) == "rootfile")
        xml = archive.read(rootfile.attrib["full-path"])
    destination.write_bytes(xml)
    return ET.fromstring(xml)


def part_metadata(root: ET.Element) -> tuple[list[str], dict[str, dict[str, object]]]:
    part_list = next((node for node in root if local_name(node.tag) == "part-list"), None)
    names: list[str] = []
    if part_list is not None:
        for node in part_list:
            if local_name(node.tag) == "score-part":
                names.append(node.attrib.get("id", ""))
    metadata: dict[str, dict[str, object]] = {}
    for part in root:
        if local_name(part.tag) != "part":
            continue
        voices = sorted({
            child.text or ""
            for child in part.iter()
            if local_name(child.tag) == "voice"
        })
        has_lyrics = any(local_name(child.tag) == "lyric" for child in part.iter())
        metadata[part.attrib.get("id", "")] = {
            "voices": voices,
            "has_lyrics": has_lyrics,
        }
    return names, metadata


def write_fragment(root: ET.Element, start: int, end: int, destination: Path) -> None:
    fragment = copy.deepcopy(root)
    for part in fragment:
        if local_name(part.tag) != "part":
            continue
        for child in list(part):
            if local_name(child.tag) != "measure":
                continue
            try:
                number = int(re.match(r"\d+", child.attrib.get("number", "0")).group())
            except (AttributeError, ValueError):
                number = 0
            if number < start or number > end:
                part.remove(child)
    destination.write_bytes(ET.tostring(fragment, encoding="utf-8", xml_declaration=True))


def crop(image_path: Path, destination: Path, y: float, height: float) -> list[int]:
    from PIL import Image

    with Image.open(image_path) as image:
        width, image_height = image.size
        bounds = [0, round(y * image_height), width, round((y + height) * image_height)]
        image.crop(tuple(bounds)).save(destination)
    return bounds


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--score-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()

    score_dir = args.score_dir.expanduser().resolve()
    paths = workspace_paths()
    output = args.output_dir or paths["normalized"] / "vocaldive-jordan-satb"
    pages = output / "pages"
    crops = output / "system-crops"
    fragments = output / "musicxml-fragments"
    for directory in (pages / "scanned", pages / "clean", crops / "scanned", crops / "clean", fragments):
        directory.mkdir(parents=True, exist_ok=True)

    source_paths = {kind: score_dir / filename for kind, filename in SOURCES.items()}
    missing = [str(path) for path in source_paths.values() if not path.is_file()]
    if missing:
        raise FileNotFoundError("Missing source files:\n" + "\n".join(missing))

    scanned_pages = render_pdf(source_paths["scanned_pdf"], pages / "scanned", "page")
    clean_pages = render_pdf(source_paths["clean_pdf"], pages / "clean", "page")
    if len(scanned_pages) != 3 or len(clean_pages) != 3:
        raise RuntimeError(f"Expected 3 pages, got scanned={len(scanned_pages)}, clean={len(clean_pages)}")

    source_musicxml = output / "ground-truth.musicxml"
    root = extract_mxl(source_paths["mxl"], source_musicxml)
    part_ids, metadata = part_metadata(root)
    manifest = output / "system-manifest.jsonl"
    with manifest.open("w", encoding="utf-8") as stream:
        for index, layout in enumerate(SYSTEM_LAYOUT, start=1):
            page = layout["page"]
            stem = f"system-{index:02d}"
            scanned_crop = crops / "scanned" / f"{stem}.png"
            clean_crop = crops / "clean" / f"{stem}.png"
            scanned_bounds = crop(scanned_pages[page - 1], scanned_crop, layout["y"], layout["height"])
            clean_bounds = crop(clean_pages[page - 1], clean_crop, layout["y"], layout["height"])
            fragment_path = fragments / f"{stem}.musicxml"
            write_fragment(root, layout["measure_start"], layout["measure_end"], fragment_path)
            lmx_tokens = linearize_musicxml(fragment_path.read_text(encoding="utf-8"))
            from PIL import Image

            with Image.open(scanned_crop) as scanned_image:
                crop_width, crop_height = scanned_image.size
            record = {
                "id": stem,
                "dataset_id": "vocaldive_jordan_satb",
                "kind": "real_satb_system_pair",
                "page_index": page,
                "system_index": index,
                "measure_start": layout["measure_start"],
                "measure_end": layout["measure_end"],
                "visible_staff_count": 2,
                "bounds_normalized": [0.0, layout["y"], 1.0, layout["height"]],
                "scanned_page_path": str(scanned_pages[page - 1]),
                "clean_page_path": str(clean_pages[page - 1]),
                "scanned_crop_path": str(scanned_crop),
                "clean_crop_path": str(clean_crop),
                "image_path": str(scanned_crop),
                "bounds": [0, 0, crop_width, crop_height],
                "musicxml_path": str(fragment_path),
                "source_musicxml_path": str(source_musicxml),
                "part_ids": part_ids,
                "part_voice_metadata": metadata,
                "has_lyrics": any(bool(item["has_lyrics"]) for item in metadata.values()),
                "tokens": lmx_tokens,
                "lmx_token_count": len(lmx_tokens),
                "bounds_scanned_pixels": scanned_bounds,
                "bounds_clean_pixels": clean_bounds,
                "annotation_status": "needs_music_review",
                "created_at": datetime.now(timezone.utc).isoformat(),
            }
            stream.write(json.dumps(record, ensure_ascii=False) + "\n")

    summary = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "source_dir": str(score_dir),
        "output_dir": str(output),
        "scanned_pages": len(scanned_pages),
        "clean_pages": len(clean_pages),
        "systems": len(SYSTEM_LAYOUT),
        "measures": [1, 49],
        "part_ids": part_ids,
        "note": "System boundaries and page breaks are manually verified metadata and remain reviewable.",
    }
    (output / "fixture-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"manifest": str(manifest), "systems": len(SYSTEM_LAYOUT), "output": str(output)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
