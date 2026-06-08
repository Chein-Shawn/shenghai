# Full-Score MusicXML Scan Workflow

## Product Decision
The main score ingestion path should be:

```text
PDF / image score
-> OMR provider
-> editable MusicXML candidate
-> user review and correction
-> Shenghai ScoreDocument
-> annotations, playback, pitch tracking, practice history
```

The important design decision is that OMR output is never treated as final. It becomes a MusicXML candidate that the user checks against the original PDF/image first.

## What The Candidate Must Preserve
- Metadata: title, composer, lyricist, arranger, copyright.
- Parts and staves: voice/instrument names and staff mapping.
- Measures: measure count, barlines, meter changes.
- Notes and rests: pitch, octave, duration, voice assignment.
- Lyrics: syllables, hyphenation, verse numbers, melisma candidates.
- Directions: tempo text, rehearsal text, dynamics, expressive markings.
- Repeats: repeat starts/ends, endings, D.C./D.S./coda candidates.
- Layout review: page/system layout still needs visual checking against the source image.

## Current Implementation
- `ScoreDocument` now stores metadata, note lyrics, and measure directions.
- `MusicXMLImporter` imports title/creator metadata, lyrics, direction words, and dynamics from MusicXML.
- `OMRMusicXMLCandidateBuilder` creates a review candidate with recognized element counts and a checklist.
- `ScoreWorkspaceView` exposes `Full-Score MusicXML Review` as a visible app workflow.

## Current Boundary
Shenghai can import and review MusicXML candidates now.

The actual PDF/image to MusicXML recognition engine is still external for this prototype. homr, oemer, or Audiveris can generate the MusicXML candidate; Shenghai then reviews, corrects, and uses that candidate for practice features.

