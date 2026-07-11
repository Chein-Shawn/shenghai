# VocalDive OMR v1: Public Dataset Training Contract

## Purpose

VocalDive v1 uses a staged OMR pipeline. Public datasets teach visual symbol
appearance and relationships; CPDL and the Jordan SATB fixture teach the
target score domain. No dataset is treated as a complete SATB photo-to-
MusicXML ground truth without validation.

## Dataset roles

| Dataset | Role | Boundary |
| --- | --- | --- |
| DeepScoresV2 dense subset | symbol appearance pretraining | digitally rendered, not real camera scans |
| DoReMi | printed-score symbol and structure baseline | clean/typeset domain |
| MUSCIMA++ | symbol masks and notation relationships | handwritten, not complete MusicXML |
| OpenScore String Quartets | real-scan multi-staff evaluation | instrumental, not SATB |
| OLiMPiC | real-scan robustness evaluation | not the primary choral target |
| CPDL verified systems | choral domain adaptation | only reviewed systems enter supervised data |
| Jordan SATB fixture | independent target-domain holdout | never used in CPDL training splits |

## Fixed v1 symbol vocabulary

The model predicts 14 fixed channels:

```text
notehead, rest, barline, clef, key_signature, time_signature,
accidental, stem, beam, dot, articulation, slur_or_tie,
lyric_or_text, repeat_or_direction
```

The annotation reviewer may still add detailed kinds such as `part_name`,
`dynamic`, `crescendo`, `decrescendo`, or `fermata`. Those labels remain in
the derived manifest as metadata, but do not silently change the v1 model
vocabulary. They can become supervised classes in a later dataset version.

## Input/output contract

The first Core ML-friendly detector uses grayscale system tiles of 1024 by
256 pixels. Resizing preserves aspect ratio and pads with white pixels; long
systems are processed as overlapping tiles. The model emits one heatmap per
fixed class at quarter input resolution. Swift postprocessing converts peaks
and regions into symbol geometry, then reconstructs measures, notes, rests,
voices, and MusicXML.

DeepScoresV2 is imported through `tools/omr/ingest_deepscores_dense.py`.
It converts page-level object boxes into overlapping tile records without
duplicating the source images. The adapter maps the original vocabulary into
the fixed v1 classes and preserves the original class name in every symbol
record.

The reproducible baseline command is:

```text
PYTHONPATH=tools/omr python3 tools/omr/train_symbol_heatmap.py \
  --manifest /Volumes/Crucial X6/vocaldive-ml/choral-omr/prepared/cpdl-v1/symbols/omr-v1-symbol-manifest.jsonl \
  --output /Volumes/Crucial X6/vocaldive-ml/choral-omr/checkpoints/cpdl-v1-symbol-heatmap.pt
```

This is a pipeline smoke test until the public symbol datasets and roughly
100-200 representative choral systems have been annotated. A checkpoint
produced from one or a few systems must not be used as an app model.

## Data integrity rules

- Raw downloads and the original CPDL manifest are immutable.
- Splits are assigned by `score_id`, never by page or system.
- Unreviewed systems remain outside supervised MusicXML training.
- Unsupported or ambiguous annotations are preserved and reported, not
  silently relabeled as correct.
- The external SSD contains binaries and derived manifests; Git contains only
  tools, schemas, documentation, and sanitized reports.
