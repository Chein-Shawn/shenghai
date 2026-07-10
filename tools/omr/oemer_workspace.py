#!/usr/bin/env python3
"""Helpers for finding the local oemer ML workspace.

The workspace intentionally lives outside git history because checkpoints,
converted packages, and Python environments are large. The location may be on an
external SSD, so scripts should not hardcode a single path.
"""

from __future__ import annotations

import os
from pathlib import Path


def candidate_workspace_roots() -> list[Path]:
    env = os.environ.get("VOCALDIVE_OEMER_WORKSPACE")
    candidates: list[Path] = []
    if env:
        candidates.append(Path(env).expanduser())

    home = Path.home()
    candidates.append(home / "Documents" / "Codex" / "vocaldive-ml" / "oemer")

    volumes = Path("/Volumes")
    if volumes.exists():
        for volume in sorted(volumes.iterdir()):
            candidates.append(volume / "vocaldive-ml" / "oemer")

    deduped: list[Path] = []
    seen: set[str] = set()
    for candidate in candidates:
        key = str(candidate)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(candidate)
    return deduped


def resolve_workspace_root(preferred: str | Path | None = None, *, must_exist: bool = False) -> Path:
    if preferred:
        path = Path(preferred).expanduser()
        return path.resolve() if path.exists() else path

    scored: list[tuple[int, Path]] = []
    for candidate in candidate_workspace_roots():
        score = 0
        if candidate.exists():
            score += 1
        if (candidate / "checkpoints").exists():
            score += 3
        if (candidate / "venv").exists():
            score += 2
        if (candidate / "models").exists():
            score += 1
        scored.append((score, candidate))

    scored.sort(key=lambda item: (-item[0], str(item[1])))
    best = scored[0][1] if scored else Path.home() / "Documents" / "Codex" / "vocaldive-ml" / "oemer"
    if must_exist and not best.exists():
        checked = [str(path) for _, path in scored]
        raise FileNotFoundError(f"oemer workspace not found; checked {checked}")
    return best.resolve() if best.exists() else best


def workspace_paths(workspace_root: str | Path | None = None) -> dict[str, Path]:
    root = resolve_workspace_root(workspace_root)
    return {
        "root": root,
        "checkpoints": root / "checkpoints",
        "models": root / "models",
        "logs": root / "logs",
        "venv": root / "venv",
    }


def conversion_site_packages(workspace_root: str | Path | None = None) -> Path | None:
    venv_root = workspace_paths(workspace_root)["venv"] / "conversion" / "lib"
    if not venv_root.exists():
        return None
    for python_dir in sorted(venv_root.glob('python*/site-packages')):
        if python_dir.exists():
            return python_dir
    return None
