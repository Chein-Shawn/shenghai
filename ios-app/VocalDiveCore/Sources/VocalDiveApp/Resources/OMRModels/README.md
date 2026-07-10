# VocalDive OMR Models

This folder is the app bundle destination for compiled on-device OMR models.

Expected local build artifacts:

- `oemer_1st_model.mlmodelc`
- `oemer_2nd_model.mlmodelc`

The original ONNX checkpoints, conversion virtual environment, TensorFlow SavedModel
intermediates, and generated `.mlpackage` folders are intentionally kept outside git
under the discovered local oemer workspace, usually `~/Documents/Codex/vocaldive-ml/oemer/` or `/Volumes/*/vocaldive-ml/oemer/`.

Do not commit large generated model artifacts through normal git history unless Git
LFS or a release-asset workflow has been explicitly set up.
