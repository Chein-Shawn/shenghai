#!/usr/bin/env python3
"""Stable label contract for the first VocalDive symbol model.

The reviewer may contain more detailed labels than the model.  This module
keeps the model vocabulary stable while preserving the original annotation
kind in derived manifests for later model versions.
"""

from __future__ import annotations

import re


CORE_SYMBOL_KINDS = (
    "notehead",
    "rest",
    "barline",
    "clef",
    "key_signature",
    "time_signature",
    "accidental",
    "stem",
    "beam",
    "dot",
    "articulation",
    "slur_or_tie",
    "lyric_or_text",
    "repeat_or_direction",
)

MODEL_SCHEMA_VERSION = "vocaldive-symbols-v1"
UNSUPPORTED_FALLBACK = "other"


def normalize_kind(value: str) -> str:
    """Normalize reviewer labels without changing their meaning."""

    value = re.sub(r"[^a-z0-9]+", "_", value.strip().lower())
    return value.strip("_")


def model_kind(source_kind: str) -> str | None:
    """Map a detailed annotation to a v1 model class.

    ``None`` means that the annotation remains useful metadata but is not a
    supervised target for the first detector.  This is intentional for part
    names, dynamics, and rare markings: dropping them from v1 targets must not
    erase the original annotation.
    """

    kind = normalize_kind(source_kind)
    aliases = {
        "note": "notehead",
        "full_notehead": "notehead",
        "empty_notehead": "notehead",
        "grace_notehead": "notehead",
        "notehead_full": "notehead",
        "notehead_empty": "notehead",
        "measure_separator": "barline",
        "key_signature_accidental": "key_signature",
        "time": "time_signature",
        "sharp": "accidental",
        "flat": "accidental",
        "natural": "accidental",
        "tie": "slur_or_tie",
        "slur": "slur_or_tie",
        "lyric": "lyric_or_text",
        "text": "lyric_or_text",
        "repeat_start": "repeat_or_direction",
        "repeat_end": "repeat_or_direction",
        "ending": "repeat_or_direction",
        "direction": "repeat_or_direction",
        "tempo": "repeat_or_direction",
    }
    kind = aliases.get(kind, kind)
    if kind.startswith("notehead"):
        return "notehead"
    if kind.startswith("rest"):
        return "rest"
    if kind.startswith("barline") or kind in {"measure_separator", "thin_barline", "double_barline"}:
        return "barline"
    if kind.startswith("clef"):
        return "clef"
    if kind.startswith("key_sig") or kind.startswith("keysig"):
        return "key_signature"
    if kind.startswith("time_sig") or kind.startswith("timesig"):
        return "time_signature"
    if kind.startswith("accidental") or kind in {"sharp", "flat", "natural"}:
        return "accidental"
    if kind.startswith("stem"):
        return "stem"
    if kind.startswith("beam") or kind.startswith("flag"):
        return "beam"
    if kind.startswith("augmentationdot") or kind.startswith("dot"):
        return "dot"
    if kind.startswith("articulation"):
        return "articulation"
    if kind.startswith("slur") or kind.startswith("tie"):
        return "slur_or_tie"
    if kind.startswith("lyric") or kind.startswith("text"):
        return "lyric_or_text"
    if kind.startswith("repeat") or kind.startswith("dynamic") or kind.startswith("crescendo") or kind.startswith("decrescendo") or kind in {"coda", "segno", "volta", "dynamics"}:
        return "repeat_or_direction"
    return kind if kind in CORE_SYMBOL_KINDS else None


def target_index(source_kind: str) -> int | None:
    """Return the fixed v1 channel index for a source annotation."""

    kind = model_kind(source_kind)
    return CORE_SYMBOL_KINDS.index(kind) if kind is not None else None


def schema_payload() -> dict[str, object]:
    return {
        "schema_version": MODEL_SCHEMA_VERSION,
        "classes": list(CORE_SYMBOL_KINDS),
        "unsupported_annotation_fallback": UNSUPPORTED_FALLBACK,
        "input": {
            "color": "grayscale",
            "width": 1024,
            "height": 256,
            "resize": "aspect_preserving_white_padding",
        },
        "output": {
            "kind": "class_heatmaps",
            "channels": len(CORE_SYMBOL_KINDS),
            "resolution": "quarter_input",
        },
    }
