# Localization Strategy

Date: 2026-06-06

## Goal

Shenghai should support at least:

- Traditional Chinese
- English
- Japanese or Korean later if choir/singing communities become target users

## Recommended Apple Workflow

Use Xcode String Catalogs:

```text
Shenghai.xcstrings
  en
  zh-Hant
  ja
  ko
```

Why:

- Xcode extracts SwiftUI text literals.
- Translators can work from a single catalog.
- Plurals and variable substitutions are managed in one place.
- App Store metadata can follow the same language plan.

## Code Rules

1. Keep user-facing copy as SwiftUI localizable text where possible:

```swift
Text("Practice")
Label("Open Score", systemImage: "music.note.list")
```

2. For dynamic strings, use stable keys:

```swift
String(localized: "usage.total_time")
```

3. Do not concatenate translated sentence fragments.

Bad:

```swift
Text("Imported " + fileName)
```

Better:

```swift
Text("Imported \(fileName)")
```

4. Keep algorithm terms consistent:

```text
OMR = Optical Music Recognition
MusicXML = MusicXML
ScoreDocument = Shenghai ScoreDocument
Pitch deviation = 音高偏差
Timing offset = 節奏偏移 / 起音偏移
```

## Content Categories

App UI strings:

- short
- action-oriented
- translated in String Catalog

Documentation site:

- can be longer
- publish separate pages or language sections
- first priority: Traditional Chinese and English

Research notes:

- can remain mixed language
- keep paper quotes in original English
- add a short Chinese application note

## MVP Plan

1. Keep current UI English while prototyping.
2. Add `Shenghai.xcstrings` when UI stabilizes.
3. Extract app navigation, support, usage, score, and practice labels first.
4. Add Traditional Chinese after feature names settle.
5. Use the support site for longer translated explanations.

## Translation Management

Simple early workflow:

```text
Xcode String Catalog
  -> export for localization
  -> review translations
  -> import back into Xcode
```

Larger future workflow:

```text
String Catalog
  -> localization platform or spreadsheet
  -> reviewer pass
  -> import
  -> screenshot QA on iPhone, iPad, macOS
```

## QA Checklist

- Navigation titles fit on iPhone.
- Buttons do not truncate in Traditional Chinese.
- Technical terms are consistent.
- Voice/singing terms are reviewed by musicians.
- App Store listing, support site, and in-app terminology match.
