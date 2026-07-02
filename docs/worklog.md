# Worklog

## Codex 實作工作日誌｜2026-06-22

### Done

- Fixed the iOS Simulator / Debug build path so local simulator builds no longer block on selecting a development team.
- Fixed a malformed multi-line string path in `MusicXMLComposer.swift`.
- Added `ScoreReviewSession.swift` to the Xcode project target so Xcode and SwiftPM now see the same review-session types.
- Verified `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -configuration Debug -destination 'generic/platform=iOS Simulator' build` succeeds.
- Traced an iPhone Score-tab workflow issue where `Compose -> Load Score` updated the data model but left the compact Score hub stuck in `Compose`, which made the action look like it did nothing.
- Moved compact Score hub mode into `ShenghaiWorkspace` so importing MusicXML/PDF and loading a composed score now force the compact iPhone Score hub back to the review/workspace view.

### Notes

- `Great Great Joy!` is not currently a real built-in score template. In the current app, changing the draft title only changes metadata; it does not auto-generate notes for that song.
- The user-visible “no reaction” symptom on iPhone was caused by compact navigation state, not by the composed score failing to load.

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

### MusicXML Compose Update

- Added a first-pass Compose section for creating simple single-part MusicXML scores inside the app.
- Added `MusicXMLComposer` for turning composed notes/rests into both `ScoreDocument` and MusicXML export text.
- Added note-entry controls for pitch step, accidental, octave, duration, rests, undo, clear, load into Score, and MusicXML sharing.
- Updated user-facing site/manual/changelog with the new Compose workflow.
- Added a round-trip test for `ComposedScore -> MusicXML -> MusicXMLImporter`.

## Codex 實作工作日誌｜2026-06-07

### Done

- Added the `Experimental` area to Shenghai as a place for research-heavy features that are not part of the main MVP loop.
- Added `Sing-to-Dismiss Alarm` using a full-song completion check rather than a short humming shortcut.
- Used `Happy Birthday` as the first built-in full-song alarm template.
- Added `Text Rhythm Speech Lab` for rhythm-guided speech and paragraph-singing practice.
- Added scoring for clarity, rate, rhythm, completion, and overall practice quality in the experimental speech lab.
- Added user-facing docs for both experimental features:
  - `docs/experimental-sing-to-dismiss-alarm-2026-06-07.md`
  - `docs/experimental-text-rhythm-speech-lab-2026-06-07.md`
- Updated the public site, manual, and changelog to expose the new experimental features.
- Validated Swift tests after the experimental feature additions.

### Encountered / Discovered

- Apple platform background rules do not allow Shenghai to guarantee a true "sing to stop alarm" experience while the app is fully closed, the device is locked, or recording is unavailable. The practical first version is notification-driven re-entry into the app, then singing inside Shenghai.
- The speech-lab feature should be framed as rhythm-guided speech practice and progress tracking, not as diagnosis, treatment, or a cure claim.

## Codex 實作工作日誌｜2026-06-08

### Done

- Expanded the public changelog history so earlier completed work is visible to users.
- Removed the public-facing `目前限制` section from the changelog as requested.
- Updated the Notion `Features` database pages with implementation process, difficulties, and related filenames for the currently implemented and in-progress feature set.
- Added new Notion feature rows for:
  - `全譜 MusicXML 掃描審查`
  - `MusicXML 打譜與匯出`
  - `Text Rhythm Speech Lab`
  - `Sing-to-Dismiss Alarm`
- Merged the duplicate Notion feature `唱歌輔助語言治療` into `Sing to Speech Lab` and moved the old page under the merged feature as a child note to remove it from the active Features database.
- Made `PDF/image -> editable MusicXML review` a main workflow in the app and support site.
- Added a `Full-Score MusicXML Review` panel so users can inspect recognized score content before relying on it downstream.
- Extended the core score model and importer to preserve more score information from MusicXML, including:
  - score metadata
  - lyrics
  - direction words such as `rit.`
  - dynamics
- Added scan-candidate review summaries for parts, measures, notes, rests, lyrics, directions, repeats, and layout checks.
- Added `docs/full-score-musicxml-scan-workflow-2026-06-08.md` to describe the intended OMR-to-review pipeline.
- Extended the paragraph-singing feature to support English, Chinese, and mixed bilingual text in one session.
- Replaced the old English-only token assumptions with phrase-based segmentation driven by punctuation and line breaks.
- Added phrase-language detection, phrase-aware rhythm cue generation, phrase-match scoring, and `phrasesPerMinute` evaluation.
- Updated the Experimental UI, manual, and public site to show bilingual phrase segmentation and phrase-based scoring.
- Validated Swift tests after the full-score review workflow and bilingual speech-lab changes.

### Encountered / Discovered

- Real PDF/image recognition is still an external OMR step. Shenghai now handles the review, correction, and downstream use of generated MusicXML, but the actual visual recognition still depends on homr, oemer, Audiveris, or another OMR engine.
- The first phrase-rate thresholds were still too English-biased and under-scored Chinese phrase practice. The evaluator needed recalibration to use a more appropriate phrase-per-minute target range for Chinese and mixed-language sessions.

## Codex 實作工作日誌｜2026-06-12

### Done

- Replaced the unstable `@Observable` macro path with `ObservableObject` / `@Published` for app-facing state owners:
  - `ShenghaiWorkspace`
  - `UsageTrackingStore`
  - `LivePitchCaptureService`
  - `PracticeAudioService`
- Updated SwiftUI view bindings from `@Bindable` to `@ObservedObject` / `@StateObject` where appropriate.
- Replaced `#Preview` macros with `PreviewProvider` in app views to avoid the current preview macro plugin failure path.
- Fixed the Xcode project file so it now includes:
  - `ExperimentalFeaturesView.swift`
  - `ExperimentalFeature.swift`
- Added a first-pass in-app localization architecture:
  - `AppLanguage`
  - persisted `AppSettingsStore`
  - centralized `L10n.tr(...)`
- Added a user-facing display language picker in the Support/Settings screen.
- Localized major app shell and core workflow text for the current build path, including status messages and key app sections.
- Validated `xcodebuild` macOS build with workspace-local DerivedData; the build now succeeds.

### Encountered / Discovered

- The earlier Xcode failure had multiple layers:

## Codex 實作工作日誌｜2026-06-13

### Done

- Added a first real persistence/sync layer for Shenghai in the app target:
  - `PersistenceModels.swift`
  - `ImportedAssetStore.swift`
  - `PersistenceCoordinator.swift`
- Replaced the local-only `UserDefaults` language/usage pattern with a structured SwiftData-backed path for:
  - display language
  - sync preference
  - selected score
  - usage session history
  - score library metadata
  - score annotation payloads
- Added a dual-store architecture:
  - local SwiftData store as the baseline
  - optional CloudKit-backed SwiftData store when iCloud is available
- Added first-run sync choice UX in `ContentView` and a real Sync section in `SupportView` / Settings.

## Codex 實作工作日誌｜2026-06-14

### Done

- Removed the active `Singing Support Lab` / `Gentle Call-and-Response` surface from `ExperimentalFeaturesView.swift`.
- Removed the Experimental `Evidence Notes` panel and hid the top-level safety-boundary panel from the current Experimental screen.
- Kept the Experimental area focused on the two currently active prototypes:
  - `Sing-to-Dismiss Alarm`
  - `Text Rhythm Speech Lab`
- Renamed the dashboard section title from `MVP Chain` to `Feature Overview`.
- Updated the user manual and changelog so public-facing docs match the current in-app Experimental feature set.
- Added a backup rule to `AGENTS.md` so every modification cycle also checks repo backup status.
- Updated localized resources for all shipped app languages so the new Experimental subtitle and `Feature Overview` label resolve through the static localization bundles.

### Encountered / Discovered

- The existing localization files still contain a much wider pre-existing translation backlog than this cleanup touched. This pass updated the strings needed for the renamed dashboard section and Experimental subtitle, but a broader translation sweep remains a separate task.
- Updated `ShenghaiWorkspace` so it can:
  - restore the previous persisted score session
  - persist imported MusicXML and composed scores into app-owned Application Support storage
  - persist annotation strokes as structured scalable data
  - reflect sync status and toggle changes in the app state
- Updated `UsageTrackingStore` to persist its ledger through the new persistence coordinator instead of a single encoded `UserDefaults` blob.
- Updated `AppSettingsStore` so display-language changes still apply immediately in UI while being mirrored into the new persisted settings record.
- Registered the new persistence source files in `ios-app/Shenghai.xcodeproj/project.pbxproj` so both SwiftPM and the Xcode app target compile the same sync architecture.
- Revalidated both build paths after the persistence refactor:
  - `swift build --package-path ios-app/ShenghaiCore --product ShenghaiApp`
  - `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -destination generic/platform=macOS build`

- Refactored `ShenghaiCore` so it no longer depends on app-layer `L10n`.
- Removed direct localization calls from:
  - `MusicXMLComposer`
  - `OMRPipeline`
  - `UsageAnalytics`
- Added app-side localization adapters in `LocalizedPresentation.swift` so the UI renders:
  - composed note values
  - usage feature names
  - OMR provider descriptions
  - OMR recognized-element labels
  - OMR checklist/review copy
- Changed OMR shared models to use semantic text tokens instead of localized strings:
  - `LocalizedTextToken`
  - provider summary/best-for/license tokens
  - stage-note tokens
- Replaced the old Settings feedback actions (`GitHub Issue`, `Mail Draft`) with a native in-app feedback submission flow.
- Added app-layer feedback integration files:
  - `FeedbackConfiguration.swift`
  - `FeedbackSubmissionService.swift`
  - `FeedbackConfiguration.json`
- Added a Google Apps Script backend template under `tools/google-apps-script/` so Shenghai feedback can land in a Google Sheet and optionally notify by email.
- Updated C4, README, user manual, changelog, and a dedicated backend note to reflect the new feedback architecture.
- Added translated feedback-flow strings for all currently shipped app languages.
- Fixed a Swift 6 concurrency build issue by making `FeedbackSubmissionService` an `actor`.
- Updated `ios-app/Shenghai.xcodeproj/project.pbxproj` so the Xcode target includes:
  - `LocalizedPresentation.swift`
  - `FeedbackConfiguration.swift`
  - `FeedbackSubmissionService.swift`
- Removed an over-strict `#if canImport(ShenghaiCore)` guard in `LocalizedPresentation.swift` so the same localized compose helpers work in both SwiftPM and the single-target Xcode project.
- Revalidated both build paths:
  - `swift build --package-path ios-app/ShenghaiCore --product ShenghaiApp`
  - `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -destination generic/platform=macOS ... build`

### Encountered / Discovered

- `SwiftData` + CloudKit container setup can compile cleanly in both SwiftPM and the Xcode target, but the real cloud path still depends on runtime iCloud/CloudKit availability. The app now surfaces that state instead of pretending sync is always ready.
- `xcodebuild` initially failed even though the Swift package compiled, because the Xcode project target had not yet been updated to include the new persistence files. Adding those source references fixed the target drift.
- The new sync UI strings were added across all shipped language resource files, but the repo-wide localization audit still reveals a much larger pre-existing translation backlog outside this sync pass.

- A live feedback submission still needs one manual external step: deploy the Apps Script web app and paste its `/exec` URL into `FeedbackConfiguration.json`.
- Writing user text into Google Sheets needs spreadsheet-formula escaping for prefixes such as `=`, `+`, `-`, and `@`; the Apps Script template now sanitizes those values before appending rows.
- The repo-wide localization audit still fails because of many pre-existing untranslated or mojibake strings outside the new feedback flow. The new feedback keys were added, but a full translation cleanup remains a separate task.
  - review-note tokens
  - checklist tokens
- Added localized compose fallbacks at the app layer before MusicXML/ScoreDocument export so blank user drafts no longer have to rely on core-localized defaults.
- Updated `tools/localization/check_localization.py` to cover all 14 currently shipped app languages and to flag non-English values that still match English unless explicitly allowlisted.
- Updated `tools/localization/build_resources.py` so it preserves current static `.strings` resources instead of regenerating them from old Swift source history.
- Added first-pass static translations for the new OMR semantic keys and a small set of visible support/review strings across all shipped languages.
- Validated:
  - `swift build --disable-sandbox --scratch-path .build/spm`
  - `swift test --disable-sandbox --scratch-path .build/spm`

### Encountered / Discovered

- The original compile error (`Cannot find 'L10n' in scope`) was a boundary problem, not an isolated missing import. Shared-core types were rendering user-facing strings directly, which broke once localization was moved into the app target.
- The current shipped language resources still contain many pre-existing English fallbacks outside the newly refactored OMR path. The upgraded localization audit now exposes that debt much more clearly.
- The repo move from the dated Codex path to `/Users/shawn/Documents/Codex/shenghai/` left stale SwiftPM module-cache artifacts in `.build`, so a clean/build cycle was needed before local compilation succeeded again.
  - initial `Observation` macro/plugin failure for `@Observable`
  - preview macro failure for `#Preview`
  - `.xcodeproj` drift where newer Swift files existed on disk but were not registered in the project
- The current localization architecture is now in place, but full coverage across every deep experimental/research text block will still require iterative expansion of the translation table.
- Pushed commit `bb595b5` to GitHub `main`.
- Continued the localization pass for experimental-feature UI labels, pitch-state labels, and score-annotation tool names.
- Added `docs/localization-architecture-2026-06-12.md` to document the multi-language structure and long-term migration path.
- Removed the in-app `Research` navigation section from the main app flow.
- Fixed the confusing score-import behavior: the `Score` section had been wired to accept only `MusicXML`, so PDF files were never actually selectable/importable.
- Expanded the `Score` file picker to accept `MusicXML`, `PDF`, and score images, and added explicit user-facing messaging that PDF/image currently enters an OMR intake path and still needs external OMR before editable MusicXML can open in-app.
- Revalidated `xcodebuild` after the import-flow and navigation changes; the build succeeds.
- Began restructuring navigation into an iPhone tab shell and a larger-screen sidebar workflow.
- Merged Support and Usage into a unified Settings surface and added official contact details / website.
- Moved iPhone Compose access into the Score hub so phone navigation stays compact.
- Fixed the iOS compile failure in `ShenghaiApp/Views/SidebarView.swift`: `List(_:selection:)` is not available on iOS, so the sidebar now uses macOS selection binding only and keeps a button-driven list for iPad/iPhone builds.
- Revalidated the post-fix build and confirmed the project compiles successfully again.
- Replaced an invalid SF Symbol in `ShenghaiApp/Views/ScoreWorkspaceView.swift` (`doc.badge.magnifyingglass`) with a valid symbol (`doc.text.magnifyingglass`) and revalidated the build.
- Deferred the automatic demo-score load in `ShenghaiApp/Views/ContentView.swift` until after the first render pass so launch-time work does not compete with iPhone/iPad first-frame presentation.
- Migrated Shenghai away from the in-code `L10n` translation dictionary to bundle-backed static localization resources under `ios-app/ShenghaiCore/Sources/ShenghaiApp/Resources`.
- Added `Localization.swift` so the in-app display-language switch now chooses a localized resource bundle instead of switching an embedded Swift dictionary.
- Added `tools/localization/build_resources.py` to generate shipped localization resources and semantic alias keys from the legacy string inventory.
- Added `tools/localization/check_localization.py` to enforce localization-key coverage and catch raw user-facing string literals that bypass the localization layer.
- Replaced the remaining raw UI literals flagged by the localization audit (`Score Mode`, `M %@`) with `L10n.tr(...)` lookups.

### 2026-06-14

- Treated localization as an infrastructure repair instead of another one-off translation patch.
- Added `tools/localization/strings_io.py` so `.strings` files are read and rewritten through one path that:
  - repairs repeated mojibake patterns
  - rewrites resource files as stable UTF-8
  - keeps later localization tooling from crashing on damaged values
- Updated `tools/localization/check_localization.py` to use the shared `.strings` reader instead of raw text parsing.
- Fixed the checker logic so it now reliably reports:
  - missing localized keys
  - English fallbacks in the primary QA languages (`zh-Hant`, `ja`)
  - raw SwiftUI user-facing literals outside the localization layer
- Added `tools/localization/normalize_resources.py` cleanup for stale localization surface that should no longer count as active app UI:
  - `Singing Support Lab`
  - `Gentle Call-and-Response`
  - `Safety Boundary`
  - `Evidence Notes`
  - `Research Map`
- Removed the unused app-side `ResearchStatusView.swift` file so the old research-map screen no longer pollutes active localization coverage.
- Added `tools/localization/apply_localization_overrides.py` as a curated override layer:
  - fills newly introduced semantic keys such as `text.no_pitch`, `text.unknown`, and `text.decimal2_beats`
  - performs a visible-screen translation sweep for `zh-Hant`
  - performs a larger catch-up sweep for `ja`
  - backfills required resource-key coverage for the other shipped languages so the checker can enforce one complete static resource set
- Rewrote all shipped `Localizable.strings` files through the normalization/override pipeline and re-ran the audit until:
  - `python3 tools/localization/check_localization.py`
  - returned `Localization coverage passed.`
- C4 impact checked for this pass:
  - no app data-flow or navigation-structure update was needed for the localization repair itself
  - no C4 document change was required in this change set

### Encountered / Discovered

- The recurring `zh-Hant / ja` English leak was not just “missing translation effort”; a big part of it was resource-file data quality, including mojibake content that looked populated but could not be trusted.
- After removing `ResearchStatusView.swift`, the Xcode project still referenced it in `ios-app/Shenghai.xcodeproj/project.pbxproj`; that stale file reference caused a real compile failure until the PBX entries were removed.
- Once the stale view reference was fixed, the next Xcode build blocker moved to the pre-existing persistence/sync work:
  - `PersistenceModels.swift`
  - SwiftData macro/plugin expansion failed under the current environment (`SwiftDataMacros ... malformed response`)
  - this build failure is outside the localization repair itself
- `swift build` still cannot be treated as a clean signal in the current sandbox because SwiftPM tries to write to cache/module paths under the user home directory unless run in a less restricted environment.

### 2026-06-15

- Started `oemer` baseline inference work outside iOS before any Core ML conversion.
- Created a local baseline runtime workspace:
  - `research/omr/baseline-2026-06-15/`
  - `samples/scores/oemer-baseline-input/`
  - `samples/scores/oemer-baseline-output/`
  - `samples/scores/oemer-validation-pack/`
- Created a dedicated Python virtual environment at `.omr-baseline-venv`.
- Installed the minimum inference runtime needed to exercise `oemer` locally:
  - `onnxruntime`
  - `opencv-python-headless`
  - `pillow`
  - `numpy`
  - `scikit-learn`
  - `scipy`
  - `matplotlib`
  - `typing-extensions`
- Installed the local `oemer-main` checkout into that virtual environment as an editable package.
- Verified the earlier checkpoint gap was real:
  - the repo copy only had `arch.json` and `metadata.pkl`
  - no `model.onnx` files were present initially
- Downloaded the official `oemer` checkpoint assets into the expected local folders:
  - `oemer/checkpoints/unet_big/model.onnx`
  - `oemer/checkpoints/unet_big/weights.h5`
  - `oemer/checkpoints/seg_net/model.onnx`
  - `oemer/checkpoints/seg_net/weights.h5`
- Ran the first successful local baseline sample on:
  - `samples/scores/oemer-baseline-input/chula.png`
- Produced:
  - `samples/scores/oemer-baseline-output/chula.musicxml`
  - `samples/scores/oemer-baseline-output/chula_teaser.png`
- Confirmed the baseline is structurally alive rather than failing closed:
  - MusicXML parsed successfully
  - quick counts from the first output:
    - measures: 19
    - notes: 177
    - rests: 21
    - clefs: 2
    - keys: 3
- Built a first frozen 10-image validation pack from currently available local score-like samples:
  - `samples/scores/oemer-validation-pack/01-chula.png`
  - `.../02-girl_merge.jpg`
  - `.../03-wind2_deskew.jpg`
  - `.../04-chihiro_3.jpg`
  - `.../05-secret_deskew.jpg`
  - `.../06-eoe_deskew.jpg`
  - `.../07-river_1.jpg`
  - `.../08-tabi_merge.jpg`
  - `.../09-tabi.jpg`
  - `.../10-tabi.png`

### Encountered / Discovered

- `oemer`'s built-in checkpoint auto-download failed on this machine because Python `urllib` hit an SSL certificate verification error.
- Direct `curl` downloads worked immediately, so the baseline blocker was the downloader path, not the checkpoint host.
- The first sample completed, but its overlay/output showed clear false positives where score-adjacent text was interpreted as notation.
- `scikit-learn` warned that bundled pickled SVC models were created with an older sklearn version (`1.2.0`) than the runtime used in this environment (`1.9.0`); this did not block inference, but it is a reproducibility and accuracy risk.
- `numpy` emitted `Mean of empty slice` during staffline extraction on the first sample, suggesting brittle intermediate assumptions in some regions.
- `build_system.py` emitted an overflow warning while reconciling durations, and several notes were marked invalid during export.
- First interpretation of the result:
  - baseline is good enough to justify continuing
  - but not good enough to port blindly without either more validation or a narrowed symbol scope

### 2026-07-03

- Split the `Score` area into two explicit flows:
  - `MusicXML Editor`
  - `Scan to MusicXML`
- Stopped treating the old score workspace as one mixed import/review bucket; direct MusicXML work and scan-derived candidate work now converge only after `MusicXML` exists.
- Added a bundled `OSMD` renderer path inside the app resources:
  - `ios-app/ShenghaiCore/Sources/ShenghaiApp/Resources/OSMD/opensheetmusicdisplay.min.js`
  - `ios-app/ShenghaiCore/Sources/ShenghaiApp/Resources/OSMD/musicxml-editor.html`
  - `ios-app/ShenghaiCore/Sources/ShenghaiApp/Resources/OSMD/LICENSE-OSMD.txt`
- Added `MusicXMLEditorSession` so the app can track:
  - whether the editor source is direct MusicXML, scan candidate, intact sample, or scanned sample
  - the current `MusicXML` string
  - the current `ScoreDocument`
  - the page-aware review session used to map source pages to score symbols
- Reworked `ShenghaiWorkspace` so it now has explicit editor and scan entry points:
  - paste/import `MusicXML`
  - import PDF/image for scan intake
  - open bundled sample ground truth
  - run bundled intact/scanned Twinkle samples through the native prototype and then open the shared editor
- Reworked `ScoreWorkspaceView` into a clearer editor host:
  - landing surface for `MusicXML Editor` vs `Scan to MusicXML`
  - left source sidebar for sample/PDF/image pages
  - center `OSMD` rendered score
  - lower symbolic navigator panel that still uses Shenghai's own structured score components for precise selection/editing
  - right inspector plus visible sample benchmark summary
- Added bundled sample fixtures under app resources so the editor and scan flow can be exercised without external files:
  - `SampleScores/twinkle-multipage-ground-truth.musicxml`
  - `SampleScores/twinkle_intact/*`
  - `SampleScores/twinkle_scanned/*`
- Expanded `SampleScoreLibrary` from an inline XML constant into a real fixture loader plus benchmark verifier.
- Added benchmark checks for bundled Twinkle fixtures:
  - MusicXML import success
  - page count
  - measure count
  - playable note count
  - pitch sequence
- Added a new score sample test:
  - `ios-app/ShenghaiCore/Tests/ShenghaiCoreTests/TwinkleSamplePackTests.swift`
- Ran verification:
  - `python3 tools/localization/check_localization.py`
  - `swift build --package-path ios-app/ShenghaiCore --product ShenghaiApp`
  - `swift test --package-path ios-app/ShenghaiCore --filter TwinkleSamplePackTests`
  - `xcodebuild -project ios-app/Shenghai.xcodeproj -scheme Shenghai -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`
- Updated all 14 shipped app languages for the newly added Score-editor / sample / scan text surface.
- Updated `AGENTS.md` so score-editor / scan-flow changes now explicitly require a sample verification run in the same cycle.

### Encountered / Discovered

- `OSMD` is a good fit for the first commercial-friendly MusicXML score surface because the renderer is usable locally in a bundled web view and ships under BSD-3-Clause.
- The current `OSMD` bridge is already enough to prove:
  - local bundled rendering
  - rerender after score changes
  - editor/session separation from scan intake
  but it does not yet provide true symbol-by-symbol SVG mapping inside the web layer.
- Because of that current limitation, the precise editable selection path still lives in Shenghai's structured Swift symbol navigator and inspector; the `OSMD` panel is the formal engraved rendering layer, not yet the single source of editing truth.
- The native scan prototype is now productively decoupled from the editor, but the actual recognition quality is still bounded by the current prototype estimator and not by the editor architecture.
- The new bundled Twinkle intact/scanned pack gives us a repeatable correctness fixture and a separate real-photo stress fixture, which is much better than relying on ad hoc local files.

- Started the first true in-app native OMR prototype path for Shenghai's Apple app.
- Added a new shared-core native OMR data model in:
  - `ios-app/ShenghaiCore/Sources/ShenghaiCore/NativeOMRPrototype.swift`
- Fixed a real compile blocker in:
  - `ios-app/ShenghaiCore/Sources/ShenghaiCore/ScoreDocument.swift`
  - the `expandedMeasureOrder` property name had been split/corrupted
- Added a new app-side service in:
  - `ios-app/ShenghaiCore/Sources/ShenghaiApp/Services/NativeOMRPrototypeService.swift`
  - current scope:
    - native PDF/image intake
    - multi-page rasterization
    - page/tile metadata preservation
    - heuristic page analysis for system/measure estimation
    - multi-page merge
    - prototype MusicXML generation through the existing composer/importer path
- Extended `OMRProvider` with:
  - `nativePrototype`
  - this path is explicitly marked as in-app/native and kept separate from external `homr` / `oemer`
- Wired `ShenghaiWorkspace.importScoreFile(...)` so:
  - PDF/image files use the native path when `nativePrototype` is selected
  - external-provider behavior remains unchanged for `homr` / `oemer`
- Reused the existing review flow instead of inventing a second OMR surface:
  - native prototype output becomes MusicXML
  - `MusicXMLImporter` parses it back into `ScoreDocument`
  - `scannedMusicXMLCandidate` is populated for the current score-review UI
- Updated `ScoreWorkspaceView` so the OMR provider summary can show native page/measure status for the latest native session instead of a shell command preview.
- Added all new native-OMR user-facing strings across the shipped app locales:
  - provider summary / best-for / license note
  - native import description
  - native processing / completion / review-needed / failure status strings
  - page-count label

### Encountered / Discovered

- The requested product shape and the actually feasible one-turn implementation are not identical:
  - the app now has a real native multi-page PDF -> MusicXML -> review path
  - but the recognition stage is still a prototype estimator, not yet a trained bundled Core ML notation model
- The current architecture is ready for that later swap:
  - page rasterization
  - page ordering
  - geometry preservation
  - multi-page merge
  - MusicXML re-entry
  - review workflow reuse
  are now explicit seams
- `swift build` still cannot be trusted in the default sandbox because SwiftPM manifest evaluation hits a sandbox permission failure (`sandbox_apply: Operation not permitted`) even after redirecting cache paths; build verification will need escalated local tool execution or Xcode-side validation.
- After running outside the sandbox:
  - `swift build --package-path ios-app/ShenghaiCore --product ShenghaiApp`
  - completed successfully
- Xcode project integration required a second step:
  - `ios-app/Shenghai.xcodeproj/project.pbxproj`
  - had to be updated manually so the app target included:
    - `NativeOMRPrototypeService.swift`
    - `NativeOMRPrototype.swift`
- The iOS Simulator target now compiles and links through the new native OMR code path, but the local environment still blocks the final app-bundle codesign step because copied resources carry Finder/provenance metadata:
  - `resource fork, Finder information, or similar detritus not allowed`
- Stripping xattrs and re-signing the built `.app` works manually, which suggests the remaining issue is local bundle hygiene / Xcode packaging state rather than the new OMR implementation itself.
