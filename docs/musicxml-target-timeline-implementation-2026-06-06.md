# MusicXML Target Timeline Implementation

Date: 2026-06-06

## Summary

Implemented the next core MVP step:

`MusicXML -> ScoreDocument -> target pitch timeline`

This lets Shenghai know which note the singer is expected to sing at each time position, so live pitch tracking can move toward score-aligned feedback and red-marking wrong notes.

## Parser Improvements

`MusicXMLImporter` now reads:

- `sound tempo` as score BPM.
- `time/beats` and `time/beat-type` as measure meter.
- `repeat direction="forward"` and `repeat direction="backward"` as basic repeat markers.

`ScoreMeasure` now stores:

- `beats`
- `beatType`
- `repeatStart`
- `repeatEnd`

## Target Timeline

`TargetPitchPoint` now contains more score context:

- start time
- duration
- target MIDI pitch
- part ID
- measure number
- note ID
- start tick
- duration tick

`ScoreTimelineBuilder` can build a timeline for a selected part. It supports simple first-ending-free repeat expansion:

`measure 1 -> measure 2 with backward repeat` becomes:

`measure 1 -> measure 2 -> measure 1 -> measure 2`

## Why This Matters

Before this change, Shenghai could detect sung pitch but could not reliably connect a sung sample to the expected score note. Now the app can ask:

- At `time = 1.5s`, what measure/note is expected?
- Is the sung pitch sharp, flat, or in tune relative to that note?
- Which measure should be marked red after practice?

## Current Limitations

- Repeat support is basic: forward/backward repeat only.
- No first/second ending handling yet.
- No tempo changes mid-score beyond taking parsed score tempo as global BPM.
- No score-following alignment yet; the timeline assumes playback/practice starts at time zero.
- UI still needs to display live deviations against this timeline.

## Validation

Added a core test:

- imports tempo, meter, and repeat markers from MusicXML.
- builds target timeline with repeated measure order.
- verifies timeline MIDI pitches, measure numbers, note IDs, and timing.

Validation passed:

- SwiftPM tests: 6 tests passed.
- macOS Xcode build passed.
- iOS Simulator Xcode build passed.

## Next Coding Step

Connect live microphone pitch samples to `ScoreTimelineBuilder` output in `PracticeView`:

1. Build timeline for selected part.
2. Analyze live pitch samples against the timeline.
3. Display the current target note.
4. Accumulate per-note / per-measure deviations.
5. Mark repeated wrong notes on the score view.
