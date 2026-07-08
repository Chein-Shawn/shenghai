# VocalDive

VocalDive is an Apple-platform music practice project focused on turning sheet music into a playable, editable practice timeline.

## Current Phase

Phase 1 focuses on OMR research and proof-of-concept playback:

1. PDF/image score input
2. OMR baseline using Audiveris
3. MusicXML as the primary interchange format
4. VocalDive ScoreDocument as the internal project wrapper
5. MIDI/audio playback prototype

## Format Decision

VocalDive should not invent a primary notation language from scratch. The first version uses:

- MusicXML / MXL as the main score interchange format
- VocalDive ScoreDocument JSON as the app-specific wrapper
- MIDI as the playback intermediate
- WAV/AAC for exported or demo audio
- SMuFL for notation glyph standards when score rendering is implemented

## Repository Layout

```text
vocaldive/
├── README.md
├── docs/
│   ├── architecture.md
│   ├── format-research.md
│   └── worklog.md
├── research/
│   └── omr/
├── samples/
│   ├── scores/
│   ├── musicxml/
│   └── audio/
└── ios-app/
```

## Xcode Development

Open the full app project in Xcode:

```bash
open ios-app/VocalDive.xcodeproj
```



- Overview dashboard for MVP status.
- Score workspace with demo MusicXML loading.
- MusicXML file import.
- ScoreDocument inspection by part, measure, and note.
- MIDI playback and share/export.
- Practice lab preview for pitch deviation states.
- Research/status view for algorithm decisions and blockers.
- Settings view with manual, changelog, contact info, and native feedback submission.
- Local usage tracking by day and by app feature.

The shared Apple-platform core can also be opened directly in Xcode:

```bash
open ios-app/VocalDiveCore/Package.swift
```

`VocalDiveCore` includes:

- `ScoreDocument` models for the internal VocalDive wrapper.
- `MusicXMLImporter` for MusicXML to ScoreDocument parsing.
- `MIDIWriter` for MIDI event timeline and `.mid` data generation.
- `PitchAnalysis` primitives for confidence-aware pitch feedback.
- `ScoreAudioAlignmentAnalyzer` for score/audio pitch and timing differences.
- `UsageAnalyticsLedger` for local usage-time summaries.
- Swift tests covering the Twinkle sample import and MIDI output path.

The package targets iOS 17+ and macOS 14+, so the same core code is shared by the iPhone, iPad, and macOS app surfaces.

Build the current macOS app target:

```bash
xcodebuild -project ios-app/VocalDive.xcodeproj -scheme VocalDive -destination generic/platform=macOS -derivedDataPath .build/XcodeDerivedData build CODE_SIGNING_ALLOWED=NO
```

If iPhone/iPad destinations do not appear in Xcode, install the matching iOS platform in Xcode Settings > Components, or run:

```bash
xcodebuild -downloadPlatform iOS
```

## Prototype

Run the current MusicXML to ScoreDocument/MIDI prototype:

```bash
python3 research/omr/musicxml_to_scoredocument.py samples/musicxml/twinkle.musicxml --out-json samples/musicxml/twinkle.scoredocument.json --out-midi samples/audio/twinkle.mid
```

This does not perform OMR yet. It proves the downstream pipeline after MusicXML:

```text
MusicXML -> ScoreDocument JSON -> MIDI
```

## Current OMR Status

Audiveris remains the preferred OMR baseline, but the local source build currently needs either a stable Audiveris release or JDK 25. Until that is installed, VocalDive supports this fallback MVP path:

```text
Manual MusicXML import from MuseScore / Audiveris / other OMR tool -> ScoreDocument -> MIDI playback
```

## Support Site

Static support-site files live in:

```text
docs/index.html
docs/manual.html
docs/changelog.html
```

They are intended for GitHub Pages, with no custom domain required:

```text
https://chein-shawn.github.io/vocaldive/
```

Current app links point to:

- `https://chein-shawn.github.io/vocaldive/manual.html`
- `https://chein-shawn.github.io/vocaldive/changelog.html`
- in-app feedback submission to a Google Apps Script / Google Sheet backend once configured

## Planning And Review Docs

- `docs/c4-architecture-2026-06-06.md`
- `docs/localization-strategy-2026-06-06.md`
- `docs/third-party-algorithm-and-license-audit-2026-06-06.md`
- `docs/youtube-score-audio-alignment-plan-2026-06-06.md`
- `docs/google-sheets-feedback-backend-2026-06-13.md`
