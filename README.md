# Shenghai

Shenghai is an Apple-platform music practice project focused on turning sheet music into a playable, editable practice timeline.

## Current Phase

Phase 1 focuses on OMR research and proof-of-concept playback:

1. PDF/image score input
2. OMR baseline using Audiveris
3. MusicXML as the primary interchange format
4. Shenghai ScoreDocument as the internal project wrapper
5. MIDI/audio playback prototype

## Format Decision

Shenghai should not invent a primary notation language from scratch. The first version uses:

- MusicXML / MXL as the main score interchange format
- Shenghai ScoreDocument JSON as the app-specific wrapper
- MIDI as the playback intermediate
- WAV/AAC for exported or demo audio
- SMuFL for notation glyph standards when score rendering is implemented

## Repository Layout

```text
shenghai/
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

Open the shared Apple-platform core in Xcode:

```bash
open ios-app/ShenghaiCore/Package.swift
```

`ShenghaiCore` is the first app-facing implementation layer. It currently includes:

- `ScoreDocument` models for the internal Shenghai wrapper.
- `MusicXMLImporter` for MusicXML to ScoreDocument parsing.
- `MIDIWriter` for MIDI event timeline and `.mid` data generation.
- `PitchAnalysis` primitives for confidence-aware pitch feedback.
- Swift tests covering the Twinkle sample import and MIDI output path.

The package targets iOS 17+ and macOS 14+, so the same core code can later be embedded in iPhone, iPad, and macOS app targets.

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

Audiveris remains the preferred OMR baseline, but the local source build currently needs either a stable Audiveris release or JDK 25. Until that is installed, Shenghai supports this fallback MVP path:

```text
Manual MusicXML import from MuseScore / Audiveris / other OMR tool -> ScoreDocument -> MIDI playback
```
