# Score File Format Research

## Recommendation

Use existing market standards. Do not build a primary score notation format from scratch.

Primary stack:

- `MusicXML / .mxl`: main interchange format after OMR.
- `VocalDive ScoreDocument`: internal JSON wrapper for app-specific state.
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

VocalDive should only define a wrapper format for product-specific data.

## VocalDive ScoreDocument

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

## OMR Toolchain Findings

Current local status as of 2026-06-05:

- Java 11 was originally installed.
- OpenJDK 21 was installed for Gradle/Audiveris experimentation.
- Tesseract 5.5.1 is installed locally.
- Audiveris is not available via Homebrew search.
- Audiveris `development` branch can be cloned and its Gradle task list can run.
- Audiveris `development` branch currently requires Java source release 25 for compilation, so OpenJDK 21 cannot compile it.

Practical next step:

Use a stable Audiveris macOS `.dmg` when available, because this avoids local source-build Java drift. The current Audiveris source build documentation lists JDK 25 as the needed JDK for the master branch, so source builds should use JDK 25 rather than OpenJDK 21 or the current shell default Java 11.

The baseline script now prefers `/Applications/Audiveris.app/Contents/MacOS/Audiveris` and falls back to a JDK 25 source checkout only if the app is missing:

```bash
audiveris -batch -transcribe -export -output samples/musicxml/audiveris-baseline samples/scores/audiveris-baseline/chula.png
```

When using the source checkout through Gradle:

```bash
research/omr/run_audiveris_baseline.sh
```

## Sources

- W3C Music Notation Community Group: https://www.w3.org/groups/cg/music-notation/
- MusicXML repeats/endings: https://www.w3.org/2021/06/musicxml40/tutorial/midi-compatible-part/
- Audiveris Handbook: https://audiveris.github.io/audiveris/_pages/handbook/
- MuseScore file export: https://handbook.musescore.org/en_gb/file-management/file-export
- FluidSynth documentation: https://www.fluidsynth.org/documentation/
