#!/usr/bin/env python3
import json
import pathlib
import re
import sys

from strings_io import read_strings

REPO_ROOT = pathlib.Path("/Users/shawn/Documents/Codex/vocaldive")
SOURCE_ROOT = REPO_ROOT / "ios-app" / "VocalDiveCore" / "Sources"
RESOURCE_ROOT = SOURCE_ROOT / "VocalDiveApp" / "Resources"
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
PRIMARY_QA_LANGUAGES = [
    "zh-Hant",
    "ja",
]

SAME_AS_ENGLISH_VALUE_ALLOWLIST = {
    "VocalDive",
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
    "PDF",
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
RAW_LITERAL_ALLOWLIST = {
    "2/4", "3/4", "4/4", "6/8", "2", "3", "4", "6", "8",
    "b", "#", "S",
    "shanewn931131@gmail.com", "+886 0901230875",
    "C4", "C#4", "D4", "Eb4", "E4", "F4", "F#4", "G4", "Ab4", "A4", "Bb4", "B4", "C5",
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


def read_strings_table(language: str) -> dict[str, str]:
    path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
    return read_strings(path)


def raw_string_violations() -> list[str]:
    violations = []
    pattern = re.compile(r'(Text|Label|Button|Picker|navigationTitle)\("([^"]+)"')
    for path in SOURCE_ROOT.joinpath("VocalDiveApp").rglob("*.swift"):
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
    english_table = read_strings_table("en")
    used = used_keys()
    for language in REQUIRED_LANGUAGES:
        table = read_strings_table(language)
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
                language in PRIMARY_QA_LANGUAGES
                and english_value
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
