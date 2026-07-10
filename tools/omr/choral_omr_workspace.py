#!/usr/bin/env python3
"""Locate the external-SSD workspace for VocalDive's choral OMR research."""

from __future__ import annotations

import os
from pathlib import Path


def resolve_workspace_root() -> Path:
    explicit = os.environ.get("VOCALDIVE_CHORAL_OMR_WORKSPACE")
    if explicit:
        return Path(explicit).expanduser()

    candidates = []
    volumes = Path("/Volumes")
    if volumes.exists():
        candidates.extend(volume / "vocaldive-ml" / "choral-omr" for volume in sorted(volumes.iterdir()))
    candidates.append(Path.home() / "Documents" / "Codex" / "vocaldive-ml" / "choral-omr")
    return next((path for path in candidates if path.exists()), candidates[0])


def workspace_paths() -> dict[str, Path]:
    root = resolve_workspace_root()
    return {
        "root": root,
        "raw": root / "raw",
        "normalized": root / "normalized",
        "crops": root / "crops",
        "manifests": root / "manifests",
        "checkpoints": root / "checkpoints",
        "evaluations": root / "evaluations",
        "reports": root / "reports",
    }
