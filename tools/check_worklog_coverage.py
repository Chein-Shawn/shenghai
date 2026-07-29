#!/usr/bin/env python3
"""Keep the active worklog aligned with every versioned implementation day."""

from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
from pathlib import Path


DATE_HEADING = re.compile(r"^## (\d{4}-\d{2}-\d{2})(?:\b|\s)", re.MULTILINE)
WORKLOG_PATH = Path("docs/worklog.md")


def git_lines(*args: str) -> list[str]:
    result = subprocess.run(
        ["git", *args],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--require-current-day",
        action="store_true",
        help="Require an entry for today when staged work outside the log exists.",
    )
    parser.add_argument(
        "--date",
        help="Override today's date (YYYY-MM-DD); useful for deterministic checks.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not WORKLOG_PATH.exists():
        print(f"Missing active worklog: {WORKLOG_PATH}", file=sys.stderr)
        return 1

    headings = DATE_HEADING.findall(WORKLOG_PATH.read_text(encoding="utf-8"))
    duplicate_dates = sorted({date for date in headings if headings.count(date) > 1})
    commit_dates = set(git_lines("log", "HEAD", "--date=short", "--format=%ad"))
    missing_dates = sorted(commit_dates - set(headings))

    failures: list[str] = []
    if duplicate_dates:
        failures.append("Duplicate worklog dates: " + ", ".join(duplicate_dates))
    if missing_dates:
        failures.append("Commit dates missing from worklog: " + ", ".join(missing_dates))

    if args.require_current_day:
        staged_paths = git_lines("diff", "--cached", "--name-only")
        substantive_work = [path for path in staged_paths if path != str(WORKLOG_PATH)]
        today = args.date or dt.date.today().isoformat()
        if substantive_work and today not in headings:
            failures.append(
                f"Staged work requires a {today} entry in {WORKLOG_PATH}."
            )

    if failures:
        print("Worklog coverage check failed:", file=sys.stderr)
        print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
        return 1

    print(
        f"Worklog coverage ready: {len(headings)} dated entries cover "
        f"{len(commit_dates)} committed workdays."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
