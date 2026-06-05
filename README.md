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

## Prototype

Run the current MusicXML to ScoreDocument/MIDI prototype:

```bash
python3 research/omr/musicxml_to_scoredocument.py samples/musicxml/twinkle.musicxml --out-json samples/musicxml/twinkle.scoredocument.json --out-midi samples/audio/twinkle.mid
```

This does not perform OMR yet. It proves the downstream pipeline after MusicXML:

```text
MusicXML -> ScoreDocument JSON -> MIDI
```

