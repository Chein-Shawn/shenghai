# VocalDive Real-Image Choral OMR Training Pipeline

## Objective

Train a private-research staff-wise model that reads a real scanned/PDF/photo score and emits a Linearized MusicXML (LMX) fragment. A score assembler uses page, system, staff, and measure metadata to make a complete MusicXML score for the existing editor.

## Dataset Roles

| Dataset | Role | Use |
| --- | --- | --- |
| DoReMi | symbol and sequence pretraining | typeset images plus MusicXML/MEI/MIDI and symbol metadata |
| DeepScoresV2 dense | visual pretraining | masks and boxes for small notation primitives |
| OLiMPiC | real-scan external evaluation | IMSLP system image paired with LMX/MusicXML |
| OpenScore String Quartets | multi-staff paired-score source and real-scan pairing target | the GitHub repo provides CC0 MuseScore `.mscx` source; the gated paired dataset provides IMSLP scan images plus MusicXML |
| OpenScore Lieder | vocal layout training | voice plus accompaniment material |
| SEILS | multi-voice structural research | five-voice madrigals and original images |
| MUSCIMA++ and CVC-MUSCIMA | robustness research | handwritten, distortion, staffline and layout checks |
| VocalDive choir holdout | target evaluation | real choir pages plus corrected MusicXML; never train on the holdout |

## Manifest Contract

Each `staff_examples.jsonl` row has a source image, matching MusicXML file, page/system/staff order, crop bounds, part identifier, LMX tokens, source dataset ID, and an image checksum. It does not require a manually drawn box around every note. JSONL is canonical because the current external SSD cannot support SQLite journaling; a local SQLite index may be recreated later if query performance becomes necessary.

## Workflow

1. Download original data into `raw/` and record its provenance in the registry.
2. Pair an actual image with its corresponding MusicXML; do not substitute a rendered image as the source image. OpenScore `.mscx` renders are useful for parser and renderer checks, but are not real scan training images.
3. Detect or verify staff crop bounds, then record the matching part and measure range.
4. Tokenize the MusicXML fragment into LMX and train the staff-image decoder.
5. Assemble fragments in page/system/staff/measure order, validate generated MusicXML, then inspect it in VocalDive's editor.
6. Add only corrected real target examples to later fine-tuning data; retain a fixed choir holdout set for honest evaluation.

`tools/omr/download_choral_datasets.py` downloads one source at a time and writes a receipt inside the SSD `raw/` directory. The first download order is OpenScore String Quartets, OLiMPiC, then DeepScoresV2 dense. This keeps real multi-staff data ahead of synthetic visual pretraining.

`tools/omr/ingest_olimpic.py` extracts OLiMPiC's real scan image bytes, MusicXML, LMX and page/system metadata into a separate system-level evaluation manifest. OLiMPiC remains external evaluation rather than pretending to be SATB training data.

`tools/omr/convert_openscore_stringquartets.py` converts a small `.mscx` sample with the installed MuseScore CLI into MusicXML and clean PDF renders under the external SSD. These outputs verify symbolic parsing and MusicXML rendering; they are deliberately kept separate from real photographed/scanned inputs. The GitHub repository itself does not contain the quartet score PDFs; its PDF files are analysis plots.

## Local Resource Budget

All large data remains under `/Volumes/Crucial X6/vocaldive-ml/choral-omr/`. The first download budget is 60 GB. DeepScoresV2 dense is used rather than the 80.9 GB complete package. Training defaults are MPS, batch size one, 768 x 192 staff crops, and resumable checkpoints.
