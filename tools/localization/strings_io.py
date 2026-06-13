#!/usr/bin/env python3
import pathlib
import re

STRINGS_RE = re.compile(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$')


def repair_mojibake(value: str) -> str:
    previous = None
    current = value
    for _ in range(5):
        if current == previous:
            break
        previous = current
        try:
            current = current.encode("latin1").decode("utf-8")
        except (UnicodeEncodeError, UnicodeDecodeError):
            break
    return current


def decode_text(path: pathlib.Path) -> str:
    raw = path.read_bytes()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("latin1")


def read_strings(path: pathlib.Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in decode_text(path).splitlines():
        match = STRINGS_RE.match(line.strip())
        if not match:
            continue
        key = bytes(match.group(1), "utf-8").decode("unicode_escape")
        value = bytes(match.group(2), "utf-8").decode("unicode_escape")
        values[key] = repair_mojibake(value)
    return values


def escape_strings_value(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def write_strings(path: pathlib.Path, values: dict[str, str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        f'"{escape_strings_value(key)}" = "{escape_strings_value(value)}";'
        for key, value in sorted(values.items())
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
