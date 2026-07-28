# VocalDive

VocalDive is an Apple-platform music practice project focused on turning sheet music into a playable, editable practice timeline.

## Current Phase

Phase 1 focuses on editable MusicXML, rehearsal playback, and a private OMR beta:

1. PDF/image score input
2. private 714 GPU OMR beta using oemer
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

The user-facing beta route is private and server-backed:

```text
VocalDive PDF or images
  -> Tailscale HTTPS
  -> 714 Windows RTX 3090 single-worker oemer service
  -> MusicXML candidate
  -> VocalDive review editor
```

Each beta scan is limited to 50 MiB total and either one PDF of up to 30 pages
or up to 30 images. The app retains a private local retry copy while the job is
pending; 714 stores each source and result by date until the host owner removes
that date folder manually. On iPhone and iPad, the upload uses an Apple
background URLSession; any unfinished result is also recoverable from the
staged source at the next launch. See [the 714 worker guide](tools/remote_omr_714/README.md).

The Apple-native Core ML research path remains separate and is not yet the
shipping scanner.

## Support Site

Static support-site files live in:

```text
docs/index.html
docs/manual.html
docs/changelog.html
```

They are published through GitHub Pages at:

```text
https://www.vocaldive.com/
```

Current app links point to:

- `https://www.vocaldive.com/manual.html`
- `https://www.vocaldive.com/changelog.html`
- in-app feedback submission to a Google Apps Script / Google Sheet backend once configured

## Planning And Review Docs

- `docs/c4-architecture-2026-06-06.md`
- `docs/localization-strategy-2026-06-06.md`
- `docs/third-party-algorithm-and-license-audit-2026-06-06.md`
- `docs/youtube-score-audio-alignment-plan-2026-06-06.md`
- `docs/google-sheets-feedback-backend-2026-06-13.md`
