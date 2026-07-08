#!/usr/bin/env python3
import json
import pathlib
import re

from strings_io import read_strings, write_strings

REPO_ROOT = pathlib.Path("/Users/shawn/Documents/Codex/vocaldive")
SOURCE_ROOT = REPO_ROOT / "ios-app" / "VocalDiveCore" / "Sources"
RESOURCE_ROOT = SOURCE_ROOT / "VocalDiveApp" / "Resources"

LANGUAGE_ORDER = [
    ("english", "en"),
    ("traditionalChinese", "zh-Hant"),
    ("simplifiedChinese", "zh-Hans"),
    ("cantonese", "yue"),
    ("spanish", "es"),
    ("arabic", "ar"),
    ("russian", "ru"),
    ("portuguese", "pt"),
    ("indonesian", "id"),
    ("japanese", "ja"),
    ("korean", "ko"),
    ("thai", "th"),
    ("italian", "it"),
    ("german", "de"),
]

CALL_RE = re.compile(r'L10n\.tr\("([^"]*)"')
ALIAS_PREFIXES = (
    ("Overview", "nav"),
    ("Compose", "nav"),
    ("Score", "nav"),
    ("Practice", "nav"),
    ("Experimental", "nav"),
    ("Settings", "nav"),
    ("VocalDive", "app"),
    ("Official Website", "support"),
    ("Display Language", "settings"),
    ("User Manual", "support"),
    ("Changelog", "support"),
    ("Feedback", "support"),
    ("Play", "practice"),
    ("Stop", "practice"),
    ("Metronome", "practice"),
    ("Tuning Fork", "practice"),
    ("Pitch", "practice"),
    ("Score ", "score"),
    ("MusicXML", "score"),
    ("Import", "score"),
    ("Export", "score"),
    ("Playback", "practice"),
    ("Research", "research"),
    ("Annotation", "annotation"),
)

def extract_used_keys() -> list[str]:
    keys: list[str] = []
    for path in SOURCE_ROOT.rglob("*.swift"):
        text = path.read_text()
        for key in CALL_RE.findall(text):
            if key not in keys:
                keys.append(key)
    return keys


def extract_legacy_keys(used_keys: list[str]) -> list[str]:
    return [key for key in used_keys if "." not in key]


def slugify(text: str) -> str:
    text = text.lower()
    text = text.replace("%@", "placeholder")
    text = text.replace("%d", "number")
    text = text.replace("%.1f", "decimal1")
    text = text.replace("%.2f", "decimal2")
    text = re.sub(r"[^a-z0-9]+", "_", text)
    return text.strip("_")


def semantic_key(legacy_key: str, taken: set[str]) -> str:
    prefix = "text"
    for sample, candidate in ALIAS_PREFIXES:
        if legacy_key.startswith(sample):
            prefix = candidate
            break
    base = f"{prefix}.{slugify(legacy_key)}"
    key = base
    counter = 2
    while key in taken:
        key = f"{base}_{counter}"
        counter += 1
    taken.add(key)
    return key


def build_files() -> None:
    used_keys = extract_used_keys()
    legacy_keys = extract_legacy_keys(used_keys)

    RESOURCE_ROOT.mkdir(parents=True, exist_ok=True)

    aliases = read_existing_aliases()
    taken: set[str] = set()
    taken.update(aliases.values())
    for legacy_key in legacy_keys:
        aliases.setdefault(legacy_key, semantic_key(legacy_key, taken))

    (RESOURCE_ROOT / "LocalizationAliases.json").write_text(
        json.dumps(aliases, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    )

    for _, language_code in LANGUAGE_ORDER:
        current_values = read_strings_file(language_code)
        for legacy_key in legacy_keys:
            current_values.setdefault(aliases[legacy_key], legacy_key)
        write_strings_file(language_code, current_values)


def read_existing_aliases() -> dict[str, str]:
    path = RESOURCE_ROOT / "LocalizationAliases.json"
    if not path.exists():
        return {}
    return json.loads(path.read_text())


def read_strings_file(language_code: str) -> dict[str, str]:
    path = RESOURCE_ROOT / f"{language_code}.lproj" / "Localizable.strings"
    if not path.exists():
        return {}
    return read_strings(path)


def write_strings_file(language_code: str, values: dict[str, str]) -> None:
    write_strings(RESOURCE_ROOT / f"{language_code}.lproj" / "Localizable.strings", values)


if __name__ == "__main__":
    build_files()
