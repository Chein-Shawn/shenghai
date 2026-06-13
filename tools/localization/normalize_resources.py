#!/usr/bin/env python3
import json
import pathlib

from strings_io import read_strings, write_strings

REPO_ROOT = pathlib.Path("/Users/shawn/Documents/Codex/shenghai")
RESOURCE_ROOT = REPO_ROOT / "ios-app" / "ShenghaiCore" / "Sources" / "ShenghaiApp" / "Resources"
ALIASES_PATH = RESOURCE_ROOT / "LocalizationAliases.json"
LANGUAGES = [
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

STALE_ALIAS_KEYS = {
    "Experimental Singing Support Lab",
    "Gentle Call-and-Response",
    "Safety Boundary",
    "Evidence Notes",
    "Research Map",
}

STALE_RESOURCE_KEYS = {
    "nav.experimental_singing_support_lab",
    "text.gentle_call_and_response",
    "text.safety_boundary",
    "text.evidence_notes",
    "research.research_map",
}


def main() -> int:
    aliases = json.loads(ALIASES_PATH.read_text())
    aliases = {key: value for key, value in aliases.items() if key not in STALE_ALIAS_KEYS}
    ALIASES_PATH.write_text(json.dumps(aliases, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    for language in LANGUAGES:
        path = RESOURCE_ROOT / f"{language}.lproj" / "Localizable.strings"
        values = read_strings(path)
        for stale_key in STALE_RESOURCE_KEYS:
            values.pop(stale_key, None)
        write_strings(path, values)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
