# Shenghai Architecture

## MVP Pipeline

```mermaid
flowchart TD
    A["PDF / image score"] --> B["Image preprocessing"]
    B --> C["Audiveris OMR baseline"]
    C --> D["MusicXML / MXL"]
    D --> E["MusicXML parser"]
    E --> F["ScoreDocument"]
    F --> G["Repeat expansion"]
    G --> H["Manual pitch/measure correction"]
    H --> I["MIDI event timeline"]
    I --> J["Synth playback"]
    J --> K["WAV / AAC export or in-app playback"]
```

## Apple App Architecture

The app should be built primarily in Xcode with SwiftUI and shared Swift code for iPhone, iPad, and macOS.

```mermaid
flowchart TD
    A["Shenghai Xcode Workspace"] --> B["Shared Core"]
    A --> C["iPhone UI"]
    A --> D["iPad UI"]
    A --> E["macOS UI"]

    B --> B1["ScoreDocument model"]
    B --> B2["MusicXML import"]
    B --> B3["Repeat expansion"]
    B --> B4["Score correction"]
    B --> B5["Playback engine"]
    B --> B6["iCloud sync"]
```

## Core Data Objects

- `ScoreDocument`: Shenghai project wrapper.
- `Part`: one musical part or voice.
- `Measure`: measure-level score structure.
- `Note`: pitch, octave, duration, voice, staff, and timing metadata.
- `Correction`: user edits after OMR.
- `ExpandedMeasure`: playback-order measure reference after repeats/endings.
- `PlaybackEvent`: MIDI-like event timeline.

## MVP Boundary

First, prove the pipeline after MusicXML. Then add OMR automation.

1. Parse MusicXML.
2. Create ScoreDocument JSON.
3. Generate playable MIDI.
4. Add repeat expansion.
5. Integrate Audiveris OMR.
6. Build Xcode UI for review and correction.

