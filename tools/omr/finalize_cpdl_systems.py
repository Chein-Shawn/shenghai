#!/usr/bin/env python3
"""Turn manually verified CPDL system rows into LMX training examples.

Reviewers edit the external JSONL candidate manifest and set:
  alignment_status = "verified"
  measure_start / measure_end = integer MusicXML measure numbers

Rows still marked manual_review_required are deliberately ignored.
"""

from __future__ import annotations

import argparse
import copy
import json
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from choral_lmx import linearize_musicxml


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def read_musicxml(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as archive:
            container = ET.fromstring(archive.read("META-INF/container.xml"))
            rootfile = next(node for node in container.iter() if local(node.tag) == "rootfile")
            return ET.fromstring(archive.read(rootfile.attrib["full-path"]))
    return ET.parse(path).getroot()


def write_fragment(source: Path, start: int, end: int, output: Path) -> None:
    root = copy.deepcopy(read_musicxml(source))
    for part in root:
        if local(part.tag) != "part":
            continue
        for child in list(part):
            if local(child.tag) != "measure":
                continue
            number = child.attrib.get("number", "0").split(".", 1)[0]
            try:
                value = int(number)
            except ValueError:
                value = 0
            if value < start or value > end:
                part.remove(child)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=Path, default=Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1"))
    args = parser.parse_args()
    version = args.version.expanduser().resolve()
    source = version / "manifests/system-candidate-manifest.jsonl"
    output = version / "manifests/lmx-training-manifest.jsonl"
    rows = []
    skipped = 0
    for line in source.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        if row.get("alignment_status") != "verified" or row.get("measure_start") is None or row.get("measure_end") is None:
            skipped += 1
            continue
        start, end = int(row["measure_start"]), int(row["measure_end"])
        fragment = version / "musicxml-fragments" / f"{row['id']}.musicxml"
        write_fragment(Path(row["musicxml_path"]), start, end, fragment)
        row["musicxml_fragment_path"] = str(fragment)
        row["tokens"] = linearize_musicxml(fragment.read_text(encoding="utf-8"))
        row["lmx_token_count"] = len(row["tokens"])
        rows.append(row)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    print(json.dumps({"manifest": str(output), "verified_examples": len(rows), "skipped_unverified": skipped}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
