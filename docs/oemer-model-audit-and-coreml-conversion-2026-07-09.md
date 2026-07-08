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

Temporary conversion environment:

- Python 3.11.5
- `onnx 1.22.0`
- `onnxruntime 1.27.0`
- `coremltools 9.0`
- `onnx-coreml 1.3`

Result:

- `coremltools 9.0` no longer exposes an ONNX converter.
- `onnx-coreml 1.3` cannot run with modern `coremltools` because it imports removed module `coremltools.converters.nnssa`.
- Therefore direct ONNX-to-Core-ML conversion is blocked in the current environment.

Recommended next conversion branch:

1. Try ONNX -> TensorFlow/SavedModel -> Core ML in a pinned conversion venv.
2. If that fails, try ONNX -> PyTorch wrapper -> traced TorchScript -> Core ML.
3. If either model still has unsupported conversion behavior, train or export an Apple-friendly segmentation model with fixed image input shapes.

## App Integration State

Implemented in this pass:

- App-side Core ML loader expects:
  - `OMRModels/oemer_1st_model.mlmodelc`
  - `OMRModels/oemer_2nd_model.mlmodelc`
- Scan progress now reports stages and percentage.
- PDF/image scan no longer routes to external `homr/oemer` provider UI.
- If the Core ML models are missing, scan fails explicitly instead of using heuristic fake recognition.

Still blocked:

- No `.mlmodel` or `.mlmodelc` is committed yet.
- Full oemer postprocessing has not been ported to Swift yet.
- The current app-side predictor can load and execute the expected Core ML model names after conversion, but the semantic reconstruction still needs the real prediction-map parser.

