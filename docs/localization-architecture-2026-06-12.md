# Shenghai Localization Architecture

## Goal
- One shared localization system for iPhone, iPad, and macOS
- User can change display language inside the app
- Current supported language list:
  - English
  - Traditional Chinese
  - Simplified Chinese
  - Cantonese
  - Spanish
  - Arabic
  - Russian
  - Portuguese
  - Indonesian
  - Japanese
  - Korean
  - Thai
  - Italian
  - German

## Current Structure
1. `AppLanguage`
   - Source of truth for supported languages
   - Stores locale code, native language name, RTL behavior

2. `AppSettingsStore`
   - Persists user-selected display language in `UserDefaults`
   - Shared to the whole app through `environmentObject`

3. `L10n.tr(...)`
   - Single translation entrypoint for visible UI strings
   - Supports plain strings and formatted strings

4. `ShenghaiApp`
   - Applies selected language to the running app
   - Applies right-to-left layout for Arabic
   - Forces UI refresh when display language changes

5. `SupportView`
   - Exposes the language picker to users

## Best Management Pattern
- Never leave user-facing text directly hardcoded in a view
- Route all visible strings through `L10n.tr(...)`
- Keep English as the canonical source key in v1
- Use formatted keys for dynamic strings
- Keep music-note names like `C4` and `F#4` unchanged unless there is a teaching reason

## Recommended Evolution
### v1
- Current dictionary-based localization is acceptable for fast iteration
- Good for prototype speed and cross-platform consistency

### v2
- Migrate to Xcode String Catalogs (`.xcstrings`)
- Split strings by feature area:
  - Core
  - Score
  - Practice
  - Support
  - Experimental
- Add translator comments for ambiguous music terms

## Language-Specific Notes
### Chinese
- Traditional Chinese and Simplified Chinese should remain separate
- Cantonese should remain a separate profile because vocabulary and tone can diverge from standard Mandarin-oriented wording

### Arabic
- Needs RTL layout validation
- Must test spacing, truncation, and mirrored controls

### Research Screens
- UI labels should be localized first
- Research-paper titles can remain in original language when needed
- Long evidence paragraphs can be expanded gradually after the interface shell is stable

## Suggested Workflow For New Features
1. Build the feature in English
2. Replace all visible strings with `L10n.tr(...)`
3. Add at least:
   - English baseline
   - Traditional Chinese
   - Arabic smoke test
4. Verify layout on iPhone, iPad, and macOS
5. Expand the remaining languages

## Why This Architecture Is Practical
- Single SwiftUI codebase
- Single language setting
- Easy Git diffing
- Easy reuse across Apple platforms
- Low friction while Shenghai is still changing quickly
