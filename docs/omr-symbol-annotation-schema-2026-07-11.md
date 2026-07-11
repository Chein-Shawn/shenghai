# VocalDive Symbol Annotation Schema

The CPDL system manifest remains read-only. Symbol annotations are stored in:

```text
/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1/symbols/symbol-annotation-manifest.jsonl
```

Each row keeps the reviewed system identity, source page path, system bounds,
measure range, and normalized symbol boxes:

```json
{
  "id": "score-p001-s01",
  "annotation_status": "annotated",
  "symbols": [
    {"kind": "notehead", "x": 0.31, "y": 0.22, "width": 0.01, "height": 0.02}
  ],
  "annotation_note": "optional human note"
}
```

Allowed kinds are `notehead`, `rest`, `barline`, `clef`, `key_signature`,
`time_signature`, `accidental`, `stem`, `beam`, `dot`, `lyric`, and `other`.
Coordinates are normalized to the full source page; later preprocessing
converts them to system-relative coordinates. Only `alignment_status=verified`
rows enter the queue. Existing derived rows are preserved and writes are
atomic, so the browser can be closed and resumed later.
