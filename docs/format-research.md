# Score File Format Research

## Recommendation

Use existing market standards. Do not build a primary score notation format from scratch.

Primary stack:

- `MusicXML / .mxl`: main interchange format after OMR.
- `Shenghai ScoreDocument`: internal JSON wrapper for app-specific state.
- `MIDI`: playback intermediate.
- `WAV / AAC`: exported or demo audio.
- `SMuFL`: notation glyph standard for future rendering.
- `MEI`: not part of MVP; keep for future academic or historical notation work.

## Why MusicXML First

MusicXML is maintained by the W3C Music Notation Community Group and is widely supported by notation software. It can represent Western staff notation, including measures, parts, notes, durations, barlines, repeats, and endings.

Audiveris can export MusicXML, making it the practical first target for OMR output.

## Why Not Self-Develop the Main Format

Self-developing the main notation format would create avoidable risks:

- Harder to import/export with MuseScore, Dorico, Finale, Sibelius, and other tools.
- More work to support repeats, endings, articulations, dynamics, lyrics, voices, and layout.
- Less credible for competition judges than building on a known standard.

Shenghai should only define a wrapper format for product-specific data.

## Shenghai ScoreDocument

ScoreDocument should store:

- source file metadata
- MusicXML import metadata
- parts
- measures
- notes
- repeats and endings
- expanded measure order
- OMR confidence and error markers
- user corrections
- YouTube or local audio sync anchors
- practice sessions

## Playback Route

The research prototype should use:

```text
MusicXML -> ScoreDocument -> MIDI -> audio synthesis
```

For Apple app playback, move gradually toward native playback:

```text
ScoreDocument -> MIDI-like timeline -> AVAudioEngine / AVAudioUnitSampler
```

For command-line demos, MuseScore or FluidSynth can export audio once installed.

## Sources

- W3C Music Notation Community Group: https://www.w3.org/groups/cg/music-notation/
- MusicXML repeats/endings: https://www.w3.org/2021/06/musicxml40/tutorial/midi-compatible-part/
- Audiveris Handbook: https://audiveris.github.io/audiveris/_pages/handbook/
- MuseScore file export: https://handbook.musescore.org/en_gb/file-management/file-export
- FluidSynth documentation: https://www.fluidsynth.org/documentation/

