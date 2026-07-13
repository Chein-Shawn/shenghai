# VocalDive Symbol OMR Training: Stage One

## Purpose

VocalDive is moving away from a fragile "image to complete MusicXML text"
experiment. The first deployable route is deliberately staged:

```text
page image
-> staff and system geometry
-> printed-symbol detector
-> music-event reconstruction rules
-> MusicXML assembler
-> editor review
```

The detector learns where common printed symbols are. It does not write
MusicXML itself and does not decide how SATB voices should be split.

## Data Roles

| Source | Role | Not used for |
| --- | --- | --- |
| DeepScoresV2 dense | visual pretraining for printed symbols | proof of real-scan or SATB performance |
| CPDL verified systems | later real-choral fine-tuning | automatic ground truth before human review |
| Jordan SATB | blind choir-domain holdout | training or threshold tuning |

The CPDL reviewer preserves a human decision, measure range, note, and
symbol boxes independently from raw CPDL files. A saved system is eligible
for core-symbol fine-tuning only when its reviewer explicitly confirms that
every visible primary symbol has been boxed.

## Stable Model Contract

The Core ML-friendly detector keeps a fixed 14-channel schema. The initial
quality gate measures these ten primary classes:

```text
notehead, rest, barline, clef, key_signature,
time_signature, accidental, stem, beam, dot
```

Lyrics, dynamics, ties/slurs, repeats, and rare markings may be recorded in
the reviewer now. They remain metadata until enough consistently labeled
examples exist for a later fixed-schema model release.

## First DeepScores Result

The deterministic stage-one run used 1,024 training tiles, 256 held-out
tiles, a batch size of 32, and five MPS epochs. Primary mean IoU rose from
`0.0649` at epoch one to `0.0846` at epoch five. The checkpoint is useful
only as a rough annotation visual aid: notehead, beam, and stem maps show
signal, but rest, clef, accidental, dot, time-signature, and key-signature
quality are still insufficient for OMR output.

The larger 8,192-tile expansion reached its best held-out primary mean IoU of
`0.1190` at epoch two. Epoch three fell slightly to `0.1173`, so the run was
stopped instead of treating more compute as an improvement strategy. The best
checkpoint now creates non-destructive prediction previews for the 150-system
CPDL reviewer queue. Predictions are never copied into CPDL labels
automatically.

## Decision Gates

1. Train on a larger held-out DeepScores subset and inspect per-class IoU.
2. Render CPDL suggestion previews only if their overlays are visibly useful.
3. Begin an exploratory CPDL fine-tune after 30-50 core-complete systems.
4. Begin the serious CPDL fine-tune at 150 core-complete systems.
5. Require stable held-out CPDL detection of noteheads, stems, and barlines,
   plus usable clef/rest/accidental behavior, before Core ML export.
6. Test the exported model on Jordan without using Jordan for training.

Downloaded scores, rendered tiles, predictions, and checkpoints remain on the
external SSD. Git stores only reproducible code, schemas, reports, and docs.
