# oemer Model Audit And Core ML Conversion

Date: 2026-07-09

## Current Decision

VocalDive will not keep presenting `homr`, `oemer`, or `VocalDive Native` as user-selectable scan providers. The product-facing path is now one path: `Scan to MusicXML`.

The app must not produce fake MusicXML when the real model is missing. Until converted Core ML models are bundled, scanning stops at the model stage with an explicit missing-model error.

## Official oemer Assets Checked

Source repo: <https://github.com/BreezeWhite/oemer>

Release tag: <https://github.com/BreezeWhite/oemer/releases/tag/checkpoints>

License file checked: MIT license in the upstream repository. The release assets are attached to the same upstream project, but model-weight redistribution should still be treated as a release checklist item before App Store submission.

Downloaded to temporary local workspace only:

| Asset | Size | SHA-256 |
| --- | ---: | --- |
| `1st_model.onnx` | 70,767,752 bytes | `37512e858731096439746f60b377c049f07055b4a23ec6eb9a178ce92cfba174` |
| `2nd_model.onnx` | 38,448,467 bytes | `ed2e1a86ea75712ee6cdc740e96f7a36753543cf9bb980227c071c9256d9d82e` |

The `.h5` assets were not bundled or committed in this pass because the iOS/macOS target should use Core ML, not TensorFlow weights.

## ONNX Inspection

Both ONNX files passed `onnx.checker.check_model` and loaded in `onnxruntime`.

| Model | Input | Output | Notes |
| --- | --- | --- | --- |
| `1st_model.onnx` | `input`: `[batch, 256, 256, 3]` `uint8` | `prediction`: `[batch, 256, 256, 3]` `float` | First-stage segmentation path. |
| `2nd_model.onnx` | `input`: `[batch, 288, 288, 3]` `uint8` | `conv2d_25`: `[batch, 288, 288, 4]` `float` | Second-stage symbol segmentation path. |

Observed ONNX op set includes common convolutional segmentation ops: `Conv`, `ConvTranspose`, `BatchNormalization`, `Relu`, `Softmax`, `Transpose`, `Slice`, `Concat`, `Reshape`, and shape/gather helpers.

## Core ML Conversion Result

Initial direct-conversion environment:

- Python 3.11.5
- `onnx 1.22.0`
- `onnxruntime 1.27.0`
- `coremltools 9.0`
- `onnx-coreml 1.3`

Result:

- `coremltools 9.0` no longer exposes an ONNX converter.
- `onnx-coreml 1.3` cannot run with modern `coremltools` because it imports removed module `coremltools.converters.nnssa`.
- Therefore direct ONNX-to-Core-ML conversion is blocked in the current environment.

Second conversion branch attempted:

- Workspace: auto-discovered through `tools/omr/oemer_workspace.py`, supporting either `~/Documents/Codex/vocaldive-ml/oemer/` or `/Volumes/*/vocaldive-ml/oemer/`
- Scripted downloader: `tools/omr/download_oemer_checkpoints.py`
- Scripted converter: `tools/omr/convert_oemer_coreml.py`
- Pinned conversion requirements: `tools/omr/oemer_conversion_requirements.txt`
- Checkpoint manifest: `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/checkpoint-manifest.json`

The pinned environment can import TensorFlow, ONNX, ONNX Runtime, Core ML Tools, and `onnx2tf`. The latest run had enough local disk space to execute all scripted attempts; the remaining blocker is graph layout/shape conversion, not missing checkpoints or app-side loading.

Latest conversion logs:

- `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/conversion-20260709T014226Z.json`
- `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/conversion-20260709T014256Z.json`
- `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/conversion-20260709T014330Z.json`
- `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/conversion-20260709T014428Z.json`
- `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/logs/conversion-20260709T054220Z.json`

Observed `onnx2tf` blockers and fixes:

1. `onnx2tf` was not found when running the converter through the venv Python directly. The script now checks the active venv's `bin/onnx2tf` before falling back to `PATH`.
2. Missing conversion dependencies were installed in the isolated venv: `tf_keras`, `onnx-graphsurgeon`, `sng4onnx`, `psutil`, and `ai-edge-litert`.
3. `onnx2tf` expects a fixed test sample named `calibration_image_sample_data_20x128x128x3_float32.npy` in the current working directory. The script now generates this file in the ML output directory and runs `onnx2tf` from there, so the converter no longer depends on downloading that sample during conversion.
4. The converter now reaches real ONNX graph conversion with baseline, static shape, `-kt input`, `-kat input`, and generated `*_auto.json` retries. No strategy has produced a SavedModel or `.mlpackage` yet.
5. Current graph blockers are layout/shape mismatches, not missing files. The latest tooling now also tests an `NCHW` input rewrite that removes the initial input transpose before retrying `onnx2tf`:
   - `1st_model.onnx`: `model/add_2/add`, with shapes like `[?,?,128,128]` vs `[?,64,64,128]`
   - `1st_model.onnx`: first convolution can receive `[1,3,256,256]` while the TF convolution expects NHWC depth `3`
   - `2nd_model.onnx`: `model/add/add`, with shapes like `[?,144,144,64]` vs `[?,?,64,?]`
   - `2nd_model.onnx`: `model/separable_conv2d/separable_conv2d/depthwise`, where the converted depthwise filter shape does not match TensorFlow's expected grouped convolution shape
6. `onnx2tf` generated parameter-replacement JSON candidates under the ML workspace, but the automatic retries still fail. The next pass needs hand-edited replacement JSON or a different conversion branch such as an ONNX Runtime based bridge, PyTorch wrapper, or Apple-friendly re-export.

The converter script now tries multiple strategies:

- baseline `onnx2tf`
- static input shape only
- static input shape with `-kt input`
- static input shape with `-kat input`
- automatic retry with generated `*_auto.json` when available
- an `NCHW` input rewrite branch that removes the first `Transpose` and retries conversion on the rewritten ONNX
- `PYTHONPATH`-bootstrapped `onnx2tf` execution so moved external-SSD workspaces do not break on stale venv shebangs

The latest run had enough disk space to attempt conversion, but still did not produce `.mlpackage` or `.mlmodelc` artifacts.

Recommended next conversion branch:

1. Hand-edit the generated onnx2tf parameter-replacement JSON for the first blocking nodes listed above, then rerun the scripted converter.
2. In parallel, prototype an ONNX Runtime inference bridge on macOS only to inspect actual prediction-map values and channel semantics; this can guide Swift postprocess even before Core ML succeeds.
3. If the TensorFlow route remains blocked, try ONNX -> PyTorch wrapper -> traced TorchScript -> Core ML, or re-export/train an Apple-friendly segmentation model with fixed NHWC image inputs.

## App Integration State

Implemented in this pass:

- App-side Core ML loader expects:
  - `OMRModels/oemer_1st_model.mlmodelc`
  - `OMRModels/oemer_2nd_model.mlmodelc`
- App resources now include `OMRModels/README.md` documenting the expected compiled model destination and the large-artifact rule.
- The app-side predictor now supports either Core ML image inputs or `MLMultiArray` inputs, and it parses NHWC/HWC plus NCHW/CHW `MLMultiArray` outputs into prediction maps instead of reducing the model output to one confidence number.
- The first-stage staffline prediction map is blended into the staff/system projection used by the score reconstruction stage.
- Scan progress now reports stages and percentage.
- PDF/image scan no longer routes to external `homr/oemer` provider UI.
- If the Core ML models are missing, scan fails explicitly instead of using heuristic fake recognition.

Still blocked:

- No `.mlpackage`, `.mlmodel`, or `.mlmodelc` was produced in the latest run.
- Full oemer postprocessing has not been ported to Swift yet.
- The current Swift postprocess consumes staffline maps, but notehead/rest/clef/key/time reconstruction still needs the remaining oemer geometry and symbol logic.
- The next blocker is conversion graph repair, not disk space or app-side model loading.

## 2026-07-10 graph repair update

`2nd_model_nchw_input.onnx` is now the active conversion target. A reproducible repair tool, `tools/omr/repair_oemer_onnx.py`, creates a TensorFlow-oriented graph variant by bypassing 21 residual Add transpose pairs. This moved conversion past the original `model/add/add` blocker. The current blocker is `ConvTranspose__2063`: onnx2tf still loses the ConvTranspose input shape even after concrete shape hints are written into the repaired ONNX. No app-bundled Core ML model is available yet.

## 2026-07-10 decision gate result

Two bounded conversion attempts used the valid `2nd_model_nchw_input.onnx` as source and kept the graph intact. Each applied one conservative onnx2tf replacement profile to the 21 residual Add inputs:

| Profile | Result |
| --- | --- |
| `decision_gate_conservative_add_profile_0132.json` | Failed at `model/add/add`: `[1,144,144,64]` versus `[?,?,64,?]` |
| `decision_gate_conservative_add_profile_0231.json` | Failed at the same node and same incompatible shapes |

The successful ONNX Runtime benchmark remains evidence that the oemer weights are valid. The two conversion attempts are evidence that this onnx2tf/Core ML route is not deployable without deeper model re-export work. The conversion budget is now exhausted: no `.mlpackage` or `.mlmodelc` will be claimed or placed in the app from this route. oemer remains a research reference while the Apple deployment route moves to the staff-wise, real-image LMX model scaffold.
