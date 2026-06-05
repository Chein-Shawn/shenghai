# Worklog

## Codex 實作工作日誌｜2026-06-05

### Done

- Created the local `shenghai` repository structure.
- Researched score file format direction.
- Chose MusicXML as the main interchange format.
- Chose Shenghai ScoreDocument JSON as the internal wrapper.
- Confirmed Java is installed locally.
- Confirmed Audiveris, MuseScore, and FluidSynth are not currently installed.
- Added a MusicXML to ScoreDocument/MIDI prototype.
- Created the private GitHub repository `Chein-Shawn/shenghai` in the browser.
- Created a local Git repository and committed the initial research workspace.
- Attempted to push to GitHub; push is blocked until GitHub private-repo authentication or connector installation is granted.
- Attempted to clone Audiveris source for OMR research; clone failed with `fatal: early EOF`, so OMR is still blocked on acquiring Audiveris.
- Installed OpenJDK 21 via Homebrew for Audiveris/Gradle experimentation.
- Successfully cloned Audiveris `development` branch with `--depth 1` into `/private/tmp/audiveris-dev`.
- Successfully ran `./gradlew tasks` with OpenJDK 21 and confirmed the Audiveris CLI options include `-batch`, `-transcribe`, `-export`, and `-output`.
- Attempted Audiveris batch OMR on `chula.png`; build failed because the development branch uses Java source release 25, while OpenJDK 21 is installed.
- Added `research/omr/run_audiveris_baseline.sh` to preserve the exact OMR command once a compatible Audiveris build/JDK is available.

### Current Prototype

The prototype proves this downstream path:

```text
MusicXML -> ScoreDocument JSON -> MIDI
```

It does not yet perform PDF/image OMR. OMR requires installing or otherwise accessing Audiveris.

### Next

- Grant GitHub connector access to `Chein-Shawn/shenghai` or configure local GitHub credentials, then push the local repo.
- Use a stable Audiveris release/master branch or install JDK 25, then run `research/omr/run_audiveris_baseline.sh`.
- Prepare 1-3 legal sample score PDFs/images.
- Run OMR baseline and export MusicXML.
- Compare OMR output against expected notes and measures.
- Connect the research output to an Xcode multiplatform app.
