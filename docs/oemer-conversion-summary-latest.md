# oemer Core ML Conversion Summary

log: /Volumes/Crucial X6/vocaldive-ml/oemer/logs/conversion-20260709T152211Z.json
created_at: 2026-07-09T15:17:58.484661+00:00
python: 3.11.5 (v3.11.5:cce6ba91b3, Aug 24 2023, 10:50:31) [Clang 13.0.0 (clang-1300.0.29.30)]
workspace: /Volumes/Crucial X6/vocaldive-ml/oemer
checkpoint_dir: /Volumes/Crucial X6/vocaldive-ml/oemer/checkpoints
output_dir: /Volumes/Crucial X6/vocaldive-ml/oemer/models
log_dir: /Volumes/Crucial X6/vocaldive-ml/oemer/logs

## 1st_model.onnx
source: /Volumes/Crucial X6/vocaldive-ml/oemer/checkpoints/1st_model.onnx
exists: True
onnx inputs: [{'name': 'input', 'shape': ['unk__19859', 256, 256, 3], 'type': 'tensor(uint8)'}]
onnx outputs: [{'name': 'prediction', 'shape': ['unk__19860', 256, 256, 3], 'type': 'tensor(float)'}]
leading nodes: [{'op_type': 'Cast', 'inputs': ['input'], 'outputs': ['model/Cast:0']}, {'op_type': 'Transpose', 'inputs': ['model/Cast:0'], 'outputs': ['model/conv2d/BiasAdd__17141:0']}, {'op_type': 'Conv', 'inputs': ['model/conv2d/BiasAdd__17141:0', 'model/conv2d/Conv2D/ReadVariableOp:0', 'model/conv2d/BiasAdd/ReadVariableOp:0'], 'outputs': ['model/conv2d/BiasAdd:0'], 'weight_shape': [128, 3, 7, 7]}, {'op_type': 'Conv', 'inputs': ['model/conv2d/BiasAdd:0', 'model/conv2d_3/Conv2D/ReadVariableOp:0', 'model/c...
op count: 1577

### Direct Core ML
ok: False
reason: coremltools has no ONNX converter in this version

### ONNX -> TF -> Core ML
ok: False
stage: all conversion attempts

#### NCHW rewrite
ok: True
consumer_count: 1
removed_transpose: model/conv2d/BiasAdd__17141

#### Attempts
- [failed] attempt 0: strategy=baseline branch=-
  stage: onnx2tf
- [failed] attempt 1: strategy=static_shape_only branch=-
  stage: onnx2tf
- [failed] attempt 2: strategy=static_keep_nhwc branch=-
  stage: onnx2tf
- [failed] attempt 3: strategy=static_keep_absolute branch=-
  stage: onnx2tf
- [failed] attempt 4: strategy=baseline_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 5: strategy=static_shape_only_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 6: strategy=static_keep_nhwc_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 7: strategy=static_keep_absolute_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 8: strategy=baseline branch=-
  stage: onnx2tf
- [failed] attempt 9: strategy=static_shape_only branch=-
  stage: onnx2tf
- [failed] attempt 10: strategy=baseline_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 11: strategy=static_shape_only_auto_json branch=-
  stage: onnx2tf

## 2nd_model.onnx
source: /Volumes/Crucial X6/vocaldive-ml/oemer/checkpoints/2nd_model.onnx
exists: True
onnx inputs: [{'name': 'input', 'shape': ['unk__2740', 288, 288, 3], 'type': 'tensor(uint8)'}]
onnx outputs: [{'name': 'conv2d_25', 'shape': ['unk__2741', 288, 288, 4], 'type': 'tensor(float)'}]
leading nodes: [{'op_type': 'Cast', 'inputs': ['input'], 'outputs': ['model/Cast:0']}, {'op_type': 'Transpose', 'inputs': ['model/Cast:0'], 'outputs': ['model/separable_conv2d/separable_conv2d/depthwise__156:0']}, {'op_type': 'Conv', 'inputs': ['model/separable_conv2d/separable_conv2d/depthwise__156:0', 'const_fold_opt__2690'], 'outputs': ['model/separable_conv2d/separable_conv2d/depthwise:0'], 'weight_shape': [3, 1, 3, 3]}, {'op_type': 'Conv', 'inputs': ['model/separable_conv2d/separable_conv2d/depthwise:0...
op count: 1619

### Direct Core ML
ok: False
reason: coremltools has no ONNX converter in this version

### ONNX -> TF -> Core ML
ok: False
stage: all conversion attempts

#### NCHW rewrite
ok: True
consumer_count: 1
removed_transpose: model/separable_conv2d/separable_conv2d/depthwise__156

#### Attempts
- [failed] attempt 0: strategy=baseline branch=-
  stage: onnx2tf
- [failed] attempt 1: strategy=static_shape_only branch=-
  stage: onnx2tf
- [failed] attempt 2: strategy=static_keep_nhwc branch=-
  stage: onnx2tf
- [failed] attempt 3: strategy=static_keep_absolute branch=-
  stage: onnx2tf
- [failed] attempt 4: strategy=baseline_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 5: strategy=static_shape_only_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 6: strategy=static_keep_nhwc_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 7: strategy=static_keep_absolute_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 8: strategy=baseline branch=-
  stage: onnx2tf
- [failed] attempt 9: strategy=static_shape_only branch=-
  stage: onnx2tf
- [failed] attempt 10: strategy=baseline_auto_json branch=-
  stage: onnx2tf
- [failed] attempt 11: strategy=static_shape_only_auto_json branch=-
  stage: onnx2tf

## 2026-07-10 Graph Repair Experiment

- Targeted `2nd_model_nchw_input.onnx` first because its initial NCHW input rewrite succeeds.
- Added `tools/omr/repair_oemer_onnx.py` to generate reproducible TensorFlow-friendly graph variants on the external SSD.
- The repair tool found 21 residual Add transpose pairs and bypassed the `[0,3,1,2] -> Add -> [0,2,3,1]` pattern.
- This moved conversion past the original `model/add/add` blocker; the next blocker is `ConvTranspose__2063`, where onnx2tf loses the input shape inside its ConvTranspose wrapper.
- Concrete ConvTranspose shape hints were measured from the valid NCHW ONNX model and written into the repaired variant, but onnx2tf still reports `graph_node_input_shape` as `None`.
- Current status: no `.mlpackage` or `.mlmodelc` yet. The app still must treat bundled oemer Core ML models as unavailable until this conversion blocker is solved.

Artifacts kept outside git:

- `/Volumes/Crucial X6/vocaldive-ml/oemer/models/graph_repair/2nd_model_nchw_input_bypass_all_add_transposes_shape_hinted.onnx`
- `/Volumes/Crucial X6/vocaldive-ml/oemer/models/graph_repair/2nd_model_nchw_input_bypass_all_add_transposes_shape_hinted.json`

Next technical branch:

- Try onnx2tf parameter replacement or model partitioning specifically around `ConvTranspose__2063`.
- If ConvTranspose remains blocked, evaluate ONNX Runtime packaging or a PyTorch/Core ML wrapper for the model path before rewriting more graph topology.
