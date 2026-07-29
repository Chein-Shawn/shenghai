"""Create a consistent, restorable snapshot of the 714 CRM database."""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--audit-manifest", type=Path, required=True)
    args = parser.parse_args()

    if not args.database.exists():
        raise SystemExit(f"CRM database is missing: {args.database}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.audit_manifest.parent.mkdir(parents=True, exist_ok=True)

    source = sqlite3.connect(args.database)
    destination = sqlite3.connect(args.output)
    try:
        source.backup(destination)
        integrity = destination.execute("PRAGMA integrity_check").fetchone()[0]
        schema = destination.execute(
            "SELECT value FROM schema_metadata WHERE key = 'schema_version'"
        ).fetchone()
    finally:
        destination.close()
        source.close()

    if integrity != "ok":
        raise SystemExit(f"Snapshot integrity check failed: {integrity}")
    manifest = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "database": args.output.name,
        "bytes": args.output.stat().st_size,
        "sha256": sha256(args.output),
        "integrity_check": integrity,
        "schema_version": schema[0] if schema else None,
    }
    args.audit_manifest.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest))


if __name__ == "__main__":
    main()
