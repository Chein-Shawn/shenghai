#!/usr/bin/env python3
import json
import pathlib
import re
import sys

REPO_ROOT = pathlib.Path("/Users/shawn/Documents/Codex/shenghai")
SOURCE_ROOT = REPO_ROOT / "ios-app" / "ShenghaiCore" / "Sources"
RESOURCE_ROOT = SOURCE_ROOT / "ShenghaiApp" / "Resources"
ALIASES_PATH = RESOURCE_ROOT / "LocalizationAliases.json"
REQUIRED_LANGUAGES = [
    "en",
    "zh-Hant",
    "zh-Hans",
    "yue",
    "es",
    "ar",
    "ru",
    "pt",
    "id",
    "ja",
    "ko",
    "th",
    "it",
    "de",
]

SAME_AS_ENGLISH_VALUE_ALLOWLIST = {
    "Shenghai",
    "MusicXML",
    "MIDI",
    "OMR",
    "ScoreDocument",
    "homr",
    "oemer",
    "TestFlight",
    "GitHub",
    "Audiveris",
    "YIN",
    "CREPE",
    "pYIN",
    "SATB",
    "AVAudioEngine",
    "JDK 25",
    "AGPL-3.0",
    "b",
    "#",
    "2",
    "3",
    "4",
    "6",
    "8",
    "2/4",
    "3/4",
    "4/4",
    "6/8",
    "C4",
    "F#4",
    "shanewn931131@gmail.com",
    "+886 0901230875",
}

CALL_RE = re.compile(r'L10n\.tr\("([^"]*)"')
TOKEN_RE = re.compile(r'LocalizedTextToken\("([^"]*)"')
STRINGS_RE = re.compile(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$')
RAW_LITERAL_ALLOWLIST = {
    "2/4", "3/4", "4/4", "6/8", "2", "3", "4", "6", "8",
    "b", "#", "S",
    "shanewn931131@gmail.com", "+886 0901230875",
}


def read_aliases() -> dict[str, str]:
    return json.loads(ALIASES_PATH.read_text())


def used_keys() -> set[str]:
    keys = set()
    for path in SOURCE_ROOT.rglob("*.swift"):
        text = path.read_text()
        keys.update(CALL_RE.findall(text))
        keys.update(TOKEN_RE.findall(text))
    return keys


def read_strings(language: str) -> dict[str, str]:
    path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
    values = {}
    for line in path.read_text().splitlines():
        match = STRINGS_RE.match(line.strip())
        if not match:
            continue
        key = bytes(match.group(1), "utf-8").decode("unicode_escape")
        value = bytes(match.group(2), "utf-8").decode("unicode_escape")
        values[key] = value
    return values


def raw_string_violations() -> list[str]:
    violations = []
    pattern = re.compile(r'(Text|Label|Button|Picker|navigationTitle)\("([^"]+)"')
    for path in SOURCE_ROOT.joinpath("ShenghaiApp").rglob("*.swift"):
        text = path.read_text()
        for _, literal in pattern.findall(text):
            if literal in RAW_LITERAL_ALLOWLIST:
                continue
            if literal.startswith("\\("):
                continue
            violations.append(f"{path}: {literal}")
    return violations


def main() -> int:
    aliases = read_aliases()
    missing = []
    untranslated = []
    english_table = read_strings("en")
    used = used_keys()
    for language in REQUIRED_LANGUAGES:
        table = read_strings(language)
        for key in used:
            resource_key = aliases.get(key, key)
            if resource_key not in table:
                missing.append(f"{language}: {key} -> {resource_key}")
                continue

            if language == "en":
                continue

            english_value = english_table.get(resource_key)
            localized_value = table.get(resource_key)
            if (
                english_value
                and localized_value == english_value
                and localized_value not in SAME_AS_ENGLISH_VALUE_ALLOWLIST
            ):
                untranslated.append(f"{language}: {resource_key} = {localized_value}")

    raw_violations = raw_string_violations()

    if missing or untranslated or raw_violations:
        if missing:
            print("Missing localized keys:")
            print("\n".join(missing))
        if untranslated:
            print("Untranslated values matching English:")
            print("\n".join(untranslated))
        if raw_violations:
            print("Raw string violations:")
            print("\n".join(raw_violations))
        return 1

    print("Localization coverage passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
