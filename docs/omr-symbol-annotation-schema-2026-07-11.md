# VocalDive Symbol Annotation Schema

The CPDL system manifest remains read-only. Symbol annotations are stored in:

```text
/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1/symbols/symbol-annotation-manifest.jsonl
```

The editable dropdown configuration is stored separately at:

```text
/Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1/symbols/symbol-kinds.json
```

Use the `Add type` and `Remove selected type` controls in the annotation page.
New keys are normalized to lowercase English `snake_case`, while an optional
display name controls what appears in the menu. Removing a type only removes
it from the active menu; old annotation boxes using that key remain preserved.

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

Allowed kinds are grouped as follows:

- notation: `notehead`, `rest`, `barline`, `clef`, `key_signature`, `time_signature`, `accidental`, `stem`, `beam`, `dot`, `articulation`, `slur`, `tie`, `fermata`
- text and expression: `part_name`, `lyric`, `dynamic`, `crescendo`, `decrescendo`, `direction`, `tempo`, `rehearsal_mark`
- navigation: `repeat_start`, `repeat_end`, `ending`
- fallback: `other`

Use `dynamic` for markings such as `p`, `f`, `mp`, and `mf`; use separate
`crescendo` and `decrescendo` for hairpins or gradual dynamic markings. Use
`repeat_start` and `repeat_end` for repeat barline signs. `part_name` is for
printed labels such as Soprano, Alto, Tenor, or Bass.
Coordinates are normalized to the full source page; later preprocessing
converts them to system-relative coordinates. Only `alignment_status=verified`
rows enter the queue. Existing derived rows are preserved and writes are
atomic, so the browser can be closed and resumed later.
