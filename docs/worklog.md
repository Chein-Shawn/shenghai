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

### OMR and Live Pitch Research Update

- Researched PlayScore 2, Newzik LiveScores, StaveWave, Singscope, Audiveris, OMR survey work, Linearized MusicXML, CREPE, pYIN, singing pitch comparison, and Smart-Median smoothing.
- Created Notion page `OMR 與 Live Pitch Tracking 研究筆記｜聲海計畫`.
- Added local research note `docs/omr-live-pitch-research-2026-06-06.md`.
- Added `OMRPipeline.swift` with explicit OMR stages and an Audiveris command planner.
- Added `YINPitchTracker.swift` as the first live monophonic pitch baseline.
- Added `LivePitchCaptureService.swift` using `AVAudioEngine` microphone taps and the YIN tracker.
- Updated Practice UI with a live microphone prototype panel.
- Added tests for synthetic A4 pitch detection and Audiveris command generation.
- Validated `swift test`, macOS Xcode build, and iOS simulator Xcode build.

### Score / Audio Alignment Update

- Clarified that Shenghai should not ship automatic YouTube-to-MP3 downloading or modification.
- Kept YouTube as a reference-link / official-player integration path.
- Implemented shared core models for local/licensed audio alignment:
  - `AudioSourceReference`
  - `AudioScoreSyncAnchor`
  - `PerformanceDifference`
  - `AudioEditProposal`
  - `ScoreAudioAlignmentAnalyzer`
- Added blue score/audio difference annotations at the data layer.
- Added non-destructive edit proposals for pitch shift and timing correction.
- Added docs in `docs/youtube-score-audio-alignment-plan-2026-06-06.md`.
- Validated with `env CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test --disable-sandbox --scratch-path .build/spm`.

### Product Operations Update

- Added a GitHub Pages-ready support site under `docs/`.
- Added app Support view with manual, changelog, GitHub Issue, and mail draft actions.
- Added app Usage view with local usage time by feature and day.
- Added `UsageAnalyticsLedger` in ShenghaiCore and `UsageTrackingStore` in the app.
- Added C4 architecture documentation in `docs/c4-architecture-2026-06-06.md`.
- Added localization strategy in `docs/localization-strategy-2026-06-06.md`.
- Added third-party algorithm and launch-license audit in `docs/third-party-algorithm-and-license-audit-2026-06-06.md`.
- Validated with `env CLANG_MODULE_CACHE_PATH=.build/ModuleCache-ops swift test --disable-sandbox --scratch-path .build/spm-ops`; 9 tests passed.
- Xcode build still fails inside the sandbox because the Observation macro/plugin server cannot access required services. A non-sandbox Xcode build attempt hung and was terminated. SwiftPM successfully compiled the app target and tests.

### OMR Provider Selection Update

- Added `OMRProvider` with `homr` and `oemer` choices.
- Added provider-specific command preview through `OMRProviderCommandPlan`.
- Added Score workspace OMR Review picker so users can choose homr or oemer.
- Updated Research view to treat homr/oemer as external MusicXML-producing OMR providers and Audiveris as a benchmark path.
- Updated user manual and changelog to explain that homr/oemer currently run outside the app, then MusicXML is imported into Shenghai.
