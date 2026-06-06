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
- Added `ios-app/ShenghaiCore`, an Xcode-openable Swift package for iOS 17+ and macOS 14+.
- Implemented Swift `ScoreDocument`, `MusicXMLImporter`, and `MIDIWriter` as the first shared Apple-platform core.
- Added Swift tests for simple MusicXML import and MIDI generation.
- Re-ran the Python prototype and confirmed it still writes `samples/musicxml/twinkle.scoredocument.json` and `samples/audio/twinkle.mid`.
- Researched singing pedagogy, real-time visual feedback, singing pitch tracking, pitch contour smoothing, Basic Pitch, Onsets and Frames, VocalSet, and breath-guided singing interfaces.
- Added Google-Docs-ready research tab content in `docs/google-doc-research-tab-2026-06-06.md`.
- Added `docs/research-findings-2026-06-06.md` as the repo-side research log.
- Added Swift `PitchAnalysis` primitives for confidence-aware pitch feedback and future replaceable pitch trackers.

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

### Current Blockers

- Audiveris OMR automation needs a stable Audiveris release or JDK 25. The development branch fails on OpenJDK 21 with `invalid source release: 25`.
- SwiftPM tests could not run inside the current Codex sandbox because SwiftPM attempted to use blocked user-level caches and nested sandboxing. An escalated local `swift test` request was rejected by the current usage limit, so Swift validation is pending.
- GitHub remote backup is one commit behind local until network/push permission is available again.
- Google Doc appendix has been prepared locally, but appending it to the end of the existing Google Doc still needs a confirmed editor cursor location or a working Google Docs editing connector.

## Codex 實作工作日誌｜2026-06-06

### Done

- Confirmed local `main` is two commits ahead of GitHub remote.
- Confirmed GitHub CLI token is currently invalid and needs `gh auth login`.
- Added research notes that can become a separate Google Doc tab named `研究與演算法筆記`.
- Converted research into app architecture decisions:
  - pitch tracking must be swappable
  - feedback must include confidence
  - pitch contours should be smoothed before user-facing red marks
  - phrase/melody practice matters more than single-note tuner behavior

### Pending

- Re-authenticate GitHub CLI and push local commits.
- Append or import the research tab into Google Doc after Google Docs editing access is available.
- Run SwiftPM tests outside the current sandbox.
- Resolve Audiveris with stable release or JDK 25.

### App Shell Build Update

- Added `ios-app/Shenghai.xcodeproj` with a `Shenghai` SwiftUI app scheme.
- Added `Sources/ShenghaiApp` with dashboard, score workspace, practice preview, and research/status views.
- Added MusicXML import UI, built-in demo loading, MIDI playback, and MIDI share/export actions.
- Validated `swift build --product ShenghaiApp`.
- Validated macOS app build with `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -destination generic/platform=macOS -derivedDataPath .build/XcodeDerivedData build CODE_SIGNING_ALLOWED=NO`.
- Installed the missing iOS 26.5 simulator platform with `xcodebuild -downloadPlatform iOS`.
- Validated iPhone/iPad simulator build with `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -destination generic/platform='iOS Simulator' -derivedDataPath .build/XcodeDerivedData build CODE_SIGNING_ALLOWED=NO`.
