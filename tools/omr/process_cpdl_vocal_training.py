#!/usr/bin/env python3
"""Build a traceable vocal-only CPDL training release from reviewed systems.

The original CPDL-v1 manifest is immutable input. This tool creates derived
JSONL records and MusicXML fragments under the external-SSD processed folder.
Ambiguous part mappings are quarantined instead of guessed.
"""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import random
import re
import zipfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path
from xml.etree import ElementTree as ET

from choral_lmx import linearize_musicxml


DEFAULT_VERSION = Path("/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1")
RELEASE_VERSION = "cpdl-v1-vocal-processed-1"

VOICE_WORDS = {
    "soprano", "sop", "alto", "tenor", "bass", "voice", "vocal", "canto", "s", "a", "t", "b",
    "choir", "sa", "tb", "satb", "s1", "s2", "a1", "a2", "t1", "t2", "b1", "b2",
}
INSTRUMENT_WORDS = {
    "piano", "violin", "violino", "viola", "cello", "guitar", "organ", "organo",
    "instrument", "bc", "continuo", "harpsichord", "treble viol", "tenor viol",
    "basso continuo",
}
HARD_REJECT_PATTERNS = (
    r"not useable", r"unusable", r"not usable", r"broken", r"different from",
    r"wrong,?\s*(do not|don't)?\s*use", r"not music score", r"only a website",
    r"only lyric", r"description,? not score",
)
PART_MAPPING_PATTERNS = (
    r"\bpart\s*[0-9]", r"first voice", r"second voice", r"first part", r"second part",
    r"musicxml part", r"instrument part", r"voice part",
)


def now() -> str:
    return datetime.now(timezone.utc).isoformat()


def local(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def load_jsonl(path: Path) -> list[dict[str, object]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")


def read_musicxml(path: Path) -> ET.Element:
    if path.suffix.lower() == ".mxl":
        with zipfile.ZipFile(path) as archive:
            container = ET.fromstring(archive.read("META-INF/container.xml"))
            rootfile = next(node for node in container.iter() if local(node.tag) == "rootfile")
            return ET.fromstring(archive.read(rootfile.attrib["full-path"]))
    return ET.parse(path).getroot()


def text_of(parent: ET.Element, name: str) -> str:
    child = next((node for node in parent if local(node.tag) == name), None)
    return (child.text or "").strip() if child is not None else ""


def part_catalog(root: ET.Element) -> dict[str, dict[str, str]]:
    catalog: dict[str, dict[str, str]] = {}
    part_list = next((node for node in root if local(node.tag) == "part-list"), None)
    if part_list is None:
        return catalog
    for score_part in part_list:
        if local(score_part.tag) != "score-part":
            continue
        part_id = score_part.attrib.get("id", "")
        name = text_of(score_part, "part-name")
        abbreviation = text_of(score_part, "part-abbreviation")
        catalog[part_id] = {"name": name, "abbreviation": abbreviation}
    return catalog


def normalized_words(value: str) -> set[str]:
    return set(re.findall(r"[a-z0-9]+(?:\s+[a-z0-9]+)?", value.lower()))


def classify_part(name: str, abbreviation: str) -> str:
    value = f"{name} {abbreviation}".lower().strip()
    compact = re.sub(r"[^a-z0-9]", "", value)
    if any(token in value or token.replace(" ", "") in compact for token in INSTRUMENT_WORDS):
        return "instrument"
    if value in VOICE_WORDS or compact in {"singstimme", "cantus", "bassus", "coro", "chorus"} or any(re.search(rf"\b{re.escape(token)}\b", value) for token in VOICE_WORDS):
        return "voice"
    return "unknown"


def parse_pitch_shift(note: str) -> int:
    value = note.lower()
    if "octave" in value and ("higher" in value or "raised" in value or "up" in value):
        return -12
    if "whole tone" in value and ("higher" in value or "raised" in value or "up" in value):
        return -2
    match = re.search(r"(?:raised|higher|up)\s+by\s+(\d+)\s+semitone", value)
    if match:
        return -int(match.group(1))
    return 0


def parse_note(note: str) -> dict[str, object]:
    original = note.strip()
    value = original.lower()
    tags: list[str] = []
    if not original:
        return {"raw": original, "tags": tags, "decision": "candidate", "pitch_shift_semitones": 0}
    if any(re.search(pattern, value) for pattern in HARD_REJECT_PATTERNS):
        tags.append("hard_reject")
    has_instrument = any(re.search(rf"\b{re.escape(token)}\b", value) for token in INSTRUMENT_WORDS)
    has_voice = any(re.search(rf"\b{re.escape(token)}\b", value) for token in VOICE_WORDS)
    if has_instrument:
        tags.append("instrument_reference")
    if has_voice:
        tags.append("voice_reference")
    if any(re.search(pattern, value) for pattern in PART_MAPPING_PATTERNS):
        tags.append("part_mapping_reference")
    pitch_shift = parse_pitch_shift(original)
    if pitch_shift:
        tags.append("pitch_shift")
    decision = "candidate"
    if "hard_reject" in tags:
        decision = "exclude"
    elif "part_mapping_reference" in tags:
        decision = "mapping_review"
    elif has_instrument and not has_voice:
        decision = "instrument_only"
    return {
        "raw": original,
        "tags": tags,
        "decision": decision,
        "pitch_shift_semitones": pitch_shift,
    }


def explicit_part_names(note: str, prefix: str) -> list[str]:
    match = re.search(rf"{prefix}\s*:\s*([^;]+)", note, flags=re.IGNORECASE)
    if not match:
        return []
    return [item.strip() for item in match.group(1).split(",") if item.strip()]


def select_parts(root: ET.Element, note: str, parsed: dict[str, object]) -> tuple[list[str], list[str], list[str]]:
    catalog = part_catalog(root)
    if not catalog:
        return [], [], ["missing_part_list"]
    keep_names = explicit_part_names(note, "KEEP_PARTS")
    drop_names = explicit_part_names(note, "DROP_PARTS")
    selected: list[str] = []
    excluded: list[str] = []
    reasons: list[str] = []
    part_nodes = {part.attrib.get("id", ""): part for part in root if local(part.tag) == "part"}
    for part_id, details in catalog.items():
        name = details["name"]
        classification = classify_part(name, details["abbreviation"])
        part_node = part_nodes.get(part_id)
        has_lyrics = part_node is not None and any(local(node.tag) == "lyric" for node in part_node.iter())
        if classification == "unknown" and has_lyrics:
            classification = "voice"
        if keep_names and any(item.lower() in f"{name} {details['abbreviation']}".lower() for item in keep_names):
            selected.append(part_id)
        elif drop_names and any(item.lower() in f"{name} {details['abbreviation']}".lower() for item in drop_names):
            excluded.append(part_id)
        elif classification == "voice":
            selected.append(part_id)
        elif classification == "instrument":
            excluded.append(part_id)
        else:
            reasons.append(f"unknown_part_name:{part_id}:{name}")
    if parsed["decision"] == "instrument_only" and not selected:
        return [], list(catalog), ["instrument_only_note"]
    if not selected:
        reasons.append("no_unambiguous_vocal_parts")
    if reasons and not selected:
        return [], excluded, reasons
    if reasons and parsed["decision"] == "mapping_review":
        return [], excluded, reasons
    return selected, excluded, reasons


STEP_VALUES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
CHROMATIC = [("C", 0), ("C", 1), ("D", 0), ("D", 1), ("E", 0), ("F", 0), ("F", 1), ("G", 0), ("G", 1), ("A", 0), ("A", 1), ("B", 0)]


def transpose_pitch(pitch: ET.Element, semitones: int) -> None:
    step_node = next((node for node in pitch if local(node.tag) == "step"), None)
    octave_node = next((node for node in pitch if local(node.tag) == "octave"), None)
    alter_node = next((node for node in pitch if local(node.tag) == "alter"), None)
    if step_node is None or octave_node is None:
        return
    step = (step_node.text or "C").strip().upper()
    octave = int(octave_node.text or "0")
    alter = float(alter_node.text or "0") if alter_node is not None else 0.0
    midi = (octave + 1) * 12 + STEP_VALUES.get(step, 0) + alter + semitones
    midi_int = int(round(midi))
    new_octave, semitone = divmod(midi_int, 12)
    new_step, new_alter = CHROMATIC[semitone]
    step_node.text = new_step
    octave_node.text = str(new_octave - 1)
    if new_alter:
        if alter_node is None:
            alter_node = ET.Element("alter")
            pitch.append(alter_node)
        alter_node.text = str(new_alter)
    elif alter_node is not None:
        pitch.remove(alter_node)


def trim_and_transform(root: ET.Element, start: int, end: int, selected: list[str], shift: int, first_duplicate: bool) -> tuple[int, int]:
    kept_measures = 0
    playable_notes = 0
    part_list = next((node for node in root if local(node.tag) == "part-list"), None)
    if part_list is not None:
        for child in list(part_list):
            if local(child.tag) == "score-part" and child.attrib.get("id") not in selected:
                part_list.remove(child)
    for part in list(root):
        if local(part.tag) != "part":
            continue
        if part.attrib.get("id") not in selected:
            root.remove(part)
            continue
        duplicate_count = 0
        for measure in list(part):
            if local(measure.tag) != "measure":
                continue
            number = measure.attrib.get("number", "0").split(".", 1)[0]
            try:
                value = int(number)
            except ValueError:
                value = 0
            if value == 13:
                duplicate_count += 1
            keep = start <= value <= end
            if first_duplicate and value == 13 and duplicate_count > 1:
                keep = False
            if not keep:
                part.remove(measure)
                continue
            kept_measures += 1
            for note in measure.iter():
                if local(note.tag) == "note":
                    if next((child for child in note if local(child.tag) == "rest"), None) is None:
                        playable_notes += 1
                    pitch = next((child for child in note if local(child.tag) == "pitch"), None)
                    if pitch is not None and shift:
                        transpose_pitch(pitch, shift)
    return kept_measures, playable_notes


def fragment_path(root: ET.Element, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(ET.tostring(root, encoding="utf-8", xml_declaration=True))


def build_splits(rows: list[dict[str, object]], output: Path, seed: int) -> dict[str, list[dict[str, object]]]:
    score_ids = sorted({str(row["score_id"]) for row in rows})
    random.Random(seed).shuffle(score_ids)
    train_end = round(len(score_ids) * 0.70)
    validation_end = train_end + round(len(score_ids) * 0.15)
    groups = {
        "train": set(score_ids[:train_end]),
        "validation": set(score_ids[train_end:validation_end]),
        "test": set(score_ids[validation_end:]),
    }
    result: dict[str, list[dict[str, object]]] = {}
    for split, ids in groups.items():
        result[split] = [row for row in rows if str(row["score_id"]) in ids]
        write_jsonl(output / "splits" / f"{split}.jsonl", result[split])
    return result


def process(version: Path, seed: int) -> dict[str, object]:
    source_manifest = version / "manifests/system-candidate-manifest.jsonl"
    output = version / "processed"
    output.mkdir(parents=True, exist_ok=True)
    rows = load_jsonl(source_manifest)
    decisions: list[dict[str, object]] = []
    training: list[dict[str, object]] = []
    quarantine: list[dict[str, object]] = []
    counts = Counter()
    pitch_counts = Counter()
    for row in rows:
        note = str(row.get("review_note") or "")
        parsed = parse_note(note)
        decision: dict[str, object] = {
            "id": row.get("id"),
            "score_id": row.get("score_id"),
            "title": row.get("title"),
            "alignment_status": row.get("alignment_status"),
            "source_review_note": note,
            "parsed_note": parsed,
            "decision": "unreviewed",
            "reason": "not_manually_reviewed",
        }
        if row.get("alignment_status") == "rejected":
            decision.update(decision="exclude", reason="manual_rejected")
            counts["excluded_manual_rejected"] += 1
            decisions.append(decision)
            continue
        if row.get("alignment_status") != "verified":
            counts["unreviewed"] += 1
            decisions.append(decision)
            continue
        try:
            source = Path(str(row["musicxml_path"]))
            root = read_musicxml(source)
            start, end = int(row["measure_start"]), int(row["measure_end"])
        except Exception as error:
            decision.update(decision="quarantine", reason="source_musicxml_unreadable", error=str(error))
            counts["quarantine_unreadable"] += 1
            quarantine.append(decision)
            decisions.append(decision)
            continue
        selected, excluded, part_reasons = select_parts(root, note, parsed)
        if parsed["decision"] in {"mapping_review", "instrument_only"} and part_reasons:
            decision.update(decision="quarantine", reason=";".join(part_reasons), selected_parts=selected, excluded_parts=excluded)
            counts["quarantine_part_mapping"] += 1
            quarantine.append(decision)
            decisions.append(decision)
            continue
        if not selected:
            decision.update(decision="quarantine", reason=";".join(part_reasons) or "no_vocal_parts", selected_parts=[], excluded_parts=excluded)
            counts["quarantine_no_vocal_parts"] += 1
            quarantine.append(decision)
            decisions.append(decision)
            continue
        shift = int(parsed["pitch_shift_semitones"])
        first_duplicate = "first 13" in note.lower() or "first measure 13" in note.lower()
        kept_measures, playable_notes = trim_and_transform(root, start, end, selected, shift, first_duplicate)
        if kept_measures == 0:
            decision.update(decision="quarantine", reason="empty_measure_fragment", selected_parts=selected, excluded_parts=excluded)
            counts["quarantine_empty_fragment"] += 1
            quarantine.append(decision)
            decisions.append(decision)
            continue
        fragment = output / "musicxml-fragments" / f"{row['id']}.musicxml"
        fragment_path(root, fragment)
        try:
            tokens = linearize_musicxml(fragment.read_text(encoding="utf-8"))
        except Exception as error:
            decision.update(decision="quarantine", reason="fragment_tokenization_failed", error=str(error))
            counts["quarantine_tokenization"] += 1
            quarantine.append(decision)
            decisions.append(decision)
            continue
        training_row = copy.deepcopy(row)
        training_row.update({
            "dataset_release": RELEASE_VERSION,
            "decision": "include",
            "source_review_note": note,
            "parsed_note": parsed,
            "selected_parts": selected,
            "excluded_parts": excluded,
            "pitch_shift_semitones": shift,
            "musicxml_fragment_path": str(fragment),
            "tokens": tokens,
            "lmx_token_count": len(tokens),
            "fragment_measure_count": kept_measures,
            "fragment_playable_note_count": playable_notes,
        })
        training.append(training_row)
        decisions.append({**decision, "decision": "include", "reason": "verified_and_processed", "selected_parts": selected, "excluded_parts": excluded, "pitch_shift_semitones": shift, "musicxml_fragment_path": str(fragment), "fragment_measure_count": kept_measures, "fragment_playable_note_count": playable_notes})
        counts["included"] += 1
        pitch_counts[str(shift)] += 1
    write_jsonl(output / "review-decisions.jsonl", decisions)
    write_jsonl(output / "training-manifest.jsonl", training)
    write_jsonl(output / "quarantine-manifest.jsonl", quarantine)
    splits = build_splits(training, output, seed)
    reports = output / "reports"
    reports.mkdir(parents=True, exist_ok=True)
    summary = {
        "created_at": now(),
        "release": RELEASE_VERSION,
        "source_manifest": str(source_manifest),
        "source_manifest_sha256": sha256(source_manifest),
        "source_rows": len(rows),
        "counts": dict(counts),
        "pitch_shift_counts": dict(pitch_counts),
        "training_rows": len(training),
        "quarantine_rows": len(quarantine),
        "split_scores": {key: len({str(row['score_id']) for row in value}) for key, value in splits.items()},
        "split_rows": {key: len(value) for key, value in splits.items()},
        "raw_input_unchanged": True,
    }
    (reports / "dataset-release.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return summary


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", type=Path, default=DEFAULT_VERSION)
    parser.add_argument("--seed", type=int, default=20260711)
    args = parser.parse_args()
    print(json.dumps(process(args.version.expanduser().resolve(), args.seed), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
