# CPDL-v1 Processing And Training Report

Date: 2026-07-11

## What Was Processed

The original CPDL-v1 system candidate manifest remains immutable on the
external SSD. Its SHA-256 is:

3c3c4231788f43f92babb59f3782536ae5bd814a56fbea097b66ea21887c39b4

Current review state:

| State | Systems |
|---|---:|
| Verified | 435 |
| Rejected | 40 |
| Not reviewed yet | 2,618 |
| Total | 3,093 |

Only verified systems were considered for supervised training. The 2,618
unreviewed systems remain available in the HTML reviewer but are not training
labels.

## Derived Vocal Dataset

The processor reads each review note, identifies vocal and instrumental parts,
applies explicit pitch corrections, and creates a new MusicXML fragment. The
raw PDF, raw MusicXML, and source review manifest are never modified.

First derived release: cpdl-v1-vocal-processed-1

| Result | Systems |
|---|---:|
| Included in training manifest | 403 |
| Quarantined for ambiguous part mapping | 32 |
| Manually rejected | 40 |
| Still unreviewed | 2,618 |

The included fragments all passed XML parsing. Twenty included systems used a
-12 semitone correction because the MusicXML was one octave above the scanned
score. Unclear generic part names were quarantined instead of guessed.

The derived files remain on the external SSD under:

prepared/cpdl-v1/processed/

The canonical indexes are JSONL because the external SSD does not reliably
support SQLite journaling. They contain source paths, checksums, review notes,
part decisions, transformations, and quarantine reasons.

## Split And Baseline

The 403 accepted systems were split by score, not by page:

| Split | Scores | Systems |
|---|---:|---:|
| Train | 30 | 267 |
| Validation | 6 | 87 |
| Test | 7 | 49 |

The first MPS baseline was trained for 10 epochs. It is a pipeline checkpoint,
not an app-ready OMR model:

| Metric | Result |
|---|---:|
| Training loss, epoch 1 | 7.22 |
| Training loss, epoch 10 | 2.55 |
| Best validation token accuracy | 2.43% |
| Best test token accuracy | 4.06% |
| Exact sequence accuracy | 0% |

Training loss decreased while validation loss eventually increased. This is
overfitting: the small first release is not yet general enough to generate
reliable MusicXML. No Core ML export or app integration should happen from
this checkpoint.

## Backup Boundary

The repository stores the processor, training metrics support, rules,
architecture notes, and this summary. CPDL PDFs, MusicXML/MXL files, rendered
images, checkpoints, and virtual environments remain outside git because of
size and source-license uncertainty.

The GitHub copy protects the reproducible method and metadata. A second disk
or cloud backup is still required to protect the downloaded score binaries.
