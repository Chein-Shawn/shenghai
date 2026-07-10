#!/usr/bin/env python3
"""Inspect downloaded oemer ONNX checkpoints without modifying them.

Usage:
    python tools/omr/audit_oemer_onnx.py
    python tools/omr/audit_oemer_onnx.py /path/to/checkpoints
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from oemer_workspace import conversion_site_packages, workspace_paths

site_packages = conversion_site_packages()
if site_packages and str(site_packages) not in sys.path:
    sys.path.insert(0, str(site_packages))


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> int:
    if len(sys.argv) > 2:
        print("usage: audit_oemer_onnx.py [path/to/checkpoints]", file=sys.stderr)
        return 2

    try:
        import onnx
        import onnxruntime as ort
    except ImportError as exc:
        print(f"missing dependency: {exc}", file=sys.stderr)
        if site_packages:
            print(f"expected site-packages: {site_packages}", file=sys.stderr)
        return 2

    defaults = workspace_paths()
    root = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) == 2 else defaults["checkpoints"]
    report: dict[str, object] = {"workspace": str(defaults["root"]), "checkpoints": str(root)}
    for name in ("1st_model.onnx", "2nd_model.onnx"):
        path = root / name
        if not path.exists():
            report[name] = {"error": "missing"}
            continue

        model = onnx.load(path)
        onnx.checker.check_model(model)
        session = ort.InferenceSession(str(path), providers=["CPUExecutionProvider"])
        report[name] = {
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
            "inputs": [
                {"name": item.name, "shape": item.shape, "type": item.type}
                for item in session.get_inputs()
            ],
            "outputs": [
                {"name": item.name, "shape": item.shape, "type": item.type}
                for item in session.get_outputs()
            ],
            "op_types": sorted({node.op_type for node in model.graph.node}),
            "op_count": len(model.graph.node),
        }

    print(json.dumps(report, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
