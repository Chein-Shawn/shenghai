#!/usr/bin/env python3
"""Convert a small subset of MusicXML into Shenghai ScoreDocument JSON and MIDI.

This prototype intentionally avoids third-party dependencies so it can run before
the OMR toolchain is installed. It supports enough MusicXML to prove the path:

    MusicXML -> ScoreDocument -> MIDI
"""

from __future__ import annotations

import argparse
import json
import struct
import xml.etree.ElementTree as ET
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Iterable


STEP_TO_SEMITONE = {
    "C": 0,
    "D": 2,
    "E": 4,
    "F": 5,
    "G": 7,
    "A": 9,
    "B": 11,
}


@dataclass
class Note:
    step: str | None
    alter: int
    octave: int | None
    duration: int
    note_type: str | None
    rest: bool
    midi: int | None
    start_tick: int
    duration_tick: int


@dataclass
class Measure:
    number: str
    notes: list[Note]


@dataclass
class Part:
    id: str
    name: str
    measures: list[Measure]


@dataclass
class ScoreDocument:
    schema_version: str
    source_format: str
    divisions: int
    ticks_per_quarter: int
    tempo_bpm: int
    parts: list[Part]
    expanded_measure_order: list[dict]
    corrections: list[dict]


def text(node: ET.Element | None, default: str = "") -> str:
    if node is None or node.text is None:
        return default
    return node.text.strip()


def midi_number(step: str, alter: int, octave: int) -> int:
    return (octave + 1) * 12 + STEP_TO_SEMITONE[step] + alter


def parse_musicxml(path: Path, tempo_bpm: int = 96, ticks_per_quarter: int = 480) -> ScoreDocument:
    root = ET.parse(path).getroot()
    part_names = {}
    for score_part in root.findall("./part-list/score-part"):
        part_id = score_part.attrib.get("id", "")
        part_names[part_id] = text(score_part.find("./part-name"), part_id)

    global_divisions = 1
    parts: list[Part] = []
    expanded_measure_order: list[dict] = []

    for part_element in root.findall("./part"):
        part_id = part_element.attrib.get("id", "")
        measures: list[Measure] = []
        current_tick = 0
        divisions = global_divisions

        for measure_element in part_element.findall("./measure"):
            number = measure_element.attrib.get("number", str(len(measures) + 1))
            attributes = measure_element.find("./attributes")
            if attributes is not None:
                divisions_text = text(attributes.find("./divisions"))
                if divisions_text:
                    divisions = int(divisions_text)
                    global_divisions = divisions

            measure_notes: list[Note] = []
            for note_element in measure_element.findall("./note"):
                duration = int(text(note_element.find("./duration"), "0") or "0")
                duration_tick = int(duration * ticks_per_quarter / max(divisions, 1))
                note_type = text(note_element.find("./type"), "") or None
                rest = note_element.find("./rest") is not None
                pitch = note_element.find("./pitch")
                step = alter = octave = midi = None
                alter_value = 0
                octave_value = None
                if pitch is not None and not rest:
                    step = text(pitch.find("./step"))
                    alter_value = int(text(pitch.find("./alter"), "0") or "0")
                    octave_value = int(text(pitch.find("./octave"), "4") or "4")
                    midi = midi_number(step, alter_value, octave_value)

                measure_notes.append(
                    Note(
                        step=step,
                        alter=alter_value,
                        octave=octave_value,
                        duration=duration,
                        note_type=note_type,
                        rest=rest,
                        midi=midi,
                        start_tick=current_tick,
                        duration_tick=duration_tick,
                    )
                )
                current_tick += duration_tick

            measures.append(Measure(number=number, notes=measure_notes))
            expanded_measure_order.append({"part_id": part_id, "measure_number": number})

        parts.append(Part(id=part_id, name=part_names.get(part_id, part_id), measures=measures))

    return ScoreDocument(
        schema_version="0.1",
        source_format="MusicXML",
        divisions=global_divisions,
        ticks_per_quarter=ticks_per_quarter,
        tempo_bpm=tempo_bpm,
        parts=parts,
        expanded_measure_order=expanded_measure_order,
        corrections=[],
    )


def var_len(value: int) -> bytes:
    buffer = value & 0x7F
    value >>= 7
    while value:
        buffer <<= 8
        buffer |= ((value & 0x7F) | 0x80)
        value >>= 7
    out = bytearray()
    while True:
        out.append(buffer & 0xFF)
        if buffer & 0x80:
            buffer >>= 8
        else:
            break
    return bytes(out)


def iter_note_events(score: ScoreDocument) -> Iterable[tuple[int, bytes]]:
    # Prototype uses the first part only.
    if not score.parts:
        return
    events: list[tuple[int, bytes]] = []
    for measure in score.parts[0].measures:
        for note in measure.notes:
            if note.rest or note.midi is None:
                continue
            events.append((note.start_tick, bytes([0x90, note.midi, 84])))
            events.append((note.start_tick + note.duration_tick, bytes([0x80, note.midi, 0])))
    for event in sorted(events, key=lambda item: (item[0], item[1][0])):
        yield event


def write_midi(score: ScoreDocument, path: Path) -> None:
    microseconds_per_quarter = int(60_000_000 / score.tempo_bpm)
    track = bytearray()
    track.extend(b"\x00\xFF\x51\x03")
    track.extend(struct.pack(">I", microseconds_per_quarter)[1:])
    track.extend(b"\x00\xC0\x00")

    previous_tick = 0
    for tick, payload in iter_note_events(score):
        delta = tick - previous_tick
        track.extend(var_len(delta))
        track.extend(payload)
        previous_tick = tick

    track.extend(b"\x00\xFF\x2F\x00")
    header = b"MThd" + struct.pack(">IHHH", 6, 0, 1, score.ticks_per_quarter)
    chunk = b"MTrk" + struct.pack(">I", len(track)) + bytes(track)
    path.write_bytes(header + chunk)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("musicxml", type=Path)
    parser.add_argument("--out-json", type=Path, required=True)
    parser.add_argument("--out-midi", type=Path, required=True)
    parser.add_argument("--tempo", type=int, default=96)
    args = parser.parse_args()

    score = parse_musicxml(args.musicxml, tempo_bpm=args.tempo)
    args.out_json.write_text(json.dumps(asdict(score), ensure_ascii=False, indent=2), encoding="utf-8")
    write_midi(score, args.out_midi)
    print(f"Wrote {args.out_json}")
    print(f"Wrote {args.out_midi}")


if __name__ == "__main__":
    main()

