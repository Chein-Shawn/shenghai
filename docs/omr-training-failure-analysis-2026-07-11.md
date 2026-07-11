# VocalDive OMR Training Failure Analysis

## Baseline finding

The first CPDL LMX baseline is a valid pipeline checkpoint, but not an app
model. Training loss fell from 7.22 to 2.55 while validation loss increased;
validation token accuracy stayed near 2.43%, test token accuracy near 4.06%,
and exact sequence accuracy remained 0%. This is overfitting, not evidence
that the Mac could not train the model.

The training split contains 267 systems from 30 scores. It contains 2,426
unique tokens, including 791 tokens seen only once. Sequence lengths range
from 10 to 435 tokens. This is too sparse for a small model that must generate
complete multi-part MusicXML directly from one image crop.

## Revised experiment boundary

`tools/omr/diagnose_choral_dataset.py` now reports token sparsity, sequence
lengths, image and crop aspect ratios, missing images, fragment parse status,
selected parts, review notes, and duplicate IDs. Reports are written to the
external SSD.

`train_choral_lmx.py` now supports aspect-preserving padding, optional light
contrast/brightness augmentation, gradient clipping, validation checkpointing,
early stopping, a small-example limit, and explicit device selection. The
legacy stretching path remains available with `--stretch` for comparison.

`train_choral_ctc.py` provides a separate staff/system CTC diagnostic. It is
not the final choral recognizer; it tests whether a horizontally ordered
image-to-symbol task is learnable without making raw MusicXML autoregression
the only route. PyTorch builds where `torch.ctc_loss` is unavailable on MPS
use CPU for this diagnostic; the LMX model can still use MPS.

## Smoke-test result

The revised LMX pipeline was run on 16 training examples for 40 epochs with
aspect-preserving padding on MPS. Loss decreased to 0.34. This confirms that
the data loader, image crop, model, and optimizer can fit a tiny controlled
set. It does not establish generalization.

## Decision

Do not simply extend the original 267-row training run. The next product
model should use a staged design:

```text
page -> system/staff -> symbol maps -> musical events -> MusicXML
```

Large visual datasets may pretrain symbol/layout detection, while real CPDL
and the Jordan SATB fixture remain the domain evaluation. MusicXML should be
assembled from structured events rather than generated as one unconstrained
token stream. Core ML export waits until a real holdout shows stable gains.

## Storage rule

Dataset binaries, rendered images, virtual environments, and checkpoints stay
on `/Volumes/Crucial X6/vocaldive-ml/`. The repository stores tools, reports,
schemas, and decisions only. Training commands should set `TMPDIR` to the
external workspace because the internal disk has repeatedly approached zero
free space.
