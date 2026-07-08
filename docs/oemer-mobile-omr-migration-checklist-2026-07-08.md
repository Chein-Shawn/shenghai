# oemer Mobile OMR Migration Checklist

Date: 2026-07-08

## Canonical Repo Root

- Active repo root: `/Users/shawn/Developer/vocaldive`
- Until the Codex thread is reopened directly at that root, treat this path as the source of truth for implementation.

## Goal

Move `oemer` from a research reference into a deployable Apple-platform OMR pipeline without embedding the Python app itself inside iPhone or iPad builds.

The portable target is:

`PDF/photo score -> native preprocessing -> mobile model inference -> Swift postprocess -> MusicXML candidate -> VocalDive editor/review`

## What We Are Porting

We are porting the pipeline in layers, not copying the original Python runtime whole:

1. Input and preprocessing
2. Model inference
3. Symbol reconstruction
4. Score semantics and MusicXML export
5. Editor handoff and review UX

## Phase A - Parity Inventory

Create a one-sheet parity matrix before more app UI work.

For each capability, mark `matched`, `partial`, or `missing`:

- staff and system detection
- noteheads
- stems, beams, flags, dots
- rests
- clefs
- accidentals
- barlines
- time signatures
- key signatures
- multi-staff grouping
- piano-style score layout
- MusicXML export

Also mark the blocker type for each gap:

- `model`
- `postprocess`
- `export`
- `ui`

## Phase B - Model Packaging Audit

Inventory the actual `oemer` deployable model pieces we need:

- checkpoint files and sizes
- ONNX inputs and outputs
- preprocessing assumptions for page resolution, normalization, and tiling
- whether one or multiple models are required for the current best result

Deliverables:

- exact model filenames
- exact input tensor shapes
- exact output tensor semantics
- memory estimate for iPhone and iPad deployment

## Phase C - ONNX To Apple Runtime Path

For each ONNX model, test:

1. can it be loaded in `onnxruntime` on macOS for baseline validation
2. can it be converted to Core ML with acceptable operator support
3. if not, which layers block conversion
4. whether it is better to keep one model in Core ML and replace the rest with Swift rules

Decision rule:

- if conversion is clean and size/runtime are reasonable, prefer Core ML
- if conversion is blocked by unsupported operators, either simplify the model or retrain an Apple-friendly variant

## Phase D - Swift Postprocess Port

Move the score-building logic into shared Swift core in this order:

1. page ordering and multi-page stitching
2. staff and system grouping
3. measure segmentation
4. note/rest event reconstruction
5. clef, key, and time propagation
6. multi-staff and piano grouping
7. MusicXML export

Important rule:

- `VocalDiveCore` stays localization-free
- all debug labels and user-facing text remain in the app layer

## Phase E - Fixture-Driven Validation

Use two fixed fixture families:

### `twinkle_intact`

Use for strict correctness checks:

- parser/import success
- page count
- measure count
- playable note count
- pitch sequence
- editor open/save success

### `twinkle_scanned`

Use for tolerance-based checks:

- no crash
- candidate MusicXML exists
- review session opens
- source pages remain visible for correction
- obvious measure-order corruption is detected

## Phase F - App Integration

The user-facing path should remain one clear surface:

- `Scan to MusicXML`
- result opens the same MusicXML editor/review workspace
- original pages stay visible in the sidebar
- corrected MusicXML becomes the source for playback and practice

Research-only provider controls should stay out of the main user surface.

## Immediate Next Moves

1. remove remaining user-facing references that imply `homr` or `oemer` already run inside the app
2. keep `VocalDive Native OMR` as the single product-facing scan path
3. convert the current heuristic native path into a parity-tracked placeholder, not a fake production promise
4. audit the actual `oemer` model assets and conversion blockers before adding more scan UI complexity
5. verify each milestone against `twinkle_intact` before broadening feature scope
