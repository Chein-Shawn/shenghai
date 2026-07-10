#!/usr/bin/env python3
"""Deterministic Linearized MusicXML for staff-wise OMR research."""

from __future__ import annotations

import argparse
import json
import re
import xml.etree.ElementTree as ET
from pathlib import Path


def tag_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def children(element: ET.Element, name: str) -> list[ET.Element]:
    return [item for item in element if tag_name(item) == name]


def child_text(element: ET.Element, name: str, default: str = "") -> str:
    found = next(iter(children(element, name)), None)
    return (found.text or default).strip() if found is not None else default


def clean_token(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9#_+.-]", "_", value.strip()) or "unknown"


def linearize_musicxml(xml_text: str, *, part_id: str | None = None) -> list[str]:
    root = ET.fromstring(xml_text)
    parts = [item for item in root if tag_name(item) == "part"]
    if part_id:
        parts = [item for item in parts if item.get("id") == part_id]
    tokens = ["<bos>"]
    for part in parts:
        tokens.append(f"PART:{clean_token(part.get('id', 'part'))}")
        for measure_index, measure in enumerate(children(part, "measure"), start=1):
            tokens.append(f"MEASURE:{clean_token(measure.get('number', str(measure_index)))}")
            for item in measure:
                name = tag_name(item)
                if name == "attributes":
                    for key in children(item, "key"):
                        tokens.append(f"KEY:{clean_token(child_text(key, 'fifths', '0'))}")
                    for time in children(item, "time"):
                        tokens.append(f"TIME:{clean_token(child_text(time, 'beats', '4'))}/{clean_token(child_text(time, 'beat-type', '4'))}")
                    for clef in children(item, "clef"):
                        tokens.append(f"CLEF:{clean_token(child_text(clef, 'sign', 'G'))}:{clean_token(child_text(clef, 'line', '2'))}")
                elif name == "note":
                    staff = clean_token(child_text(item, "staff", "1"))
                    duration = clean_token(child_text(item, "duration", "0"))
                    if children(item, "rest"):
                        tokens.append(f"REST:{duration}:STAFF:{staff}")
                    else:
                        pitch = next(iter(children(item, "pitch")), None)
                        if pitch is not None:
                            step = clean_token(child_text(pitch, "step", "C"))
                            alter = clean_token(child_text(pitch, "alter", "0"))
                            octave = clean_token(child_text(pitch, "octave", "4"))
                            tokens.append(f"NOTE:{step}:{alter}:{octave}:{duration}:STAFF:{staff}")
                    for lyric in children(item, "lyric"):
                        text = clean_token(child_text(lyric, "text", ""))
                        if text != "unknown":
                            tokens.append(f"LYRIC:{text}")
    return [*tokens, "<eos>"]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--part-id")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    payload = {"source": str(args.input), "part_id": args.part_id, "tokens": linearize_musicxml(args.input.read_text(encoding="utf-8"), part_id=args.part_id)}
    text = json.dumps(payload, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
