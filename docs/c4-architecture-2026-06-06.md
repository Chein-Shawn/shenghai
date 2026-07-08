# C4 Architecture Plan

Date: 2026-06-06

## Level 1: System Context

```text
Singer / Choir Member
  -> uses VocalDive App
  -> imports MusicXML or OMR-derived score
  -> practices with playback, pitch feedback, annotation, and usage tracking

Developer / Researcher
  -> maintains GitHub repo, docs site, Notion planning, algorithm notes

External Systems
  -> GitHub Pages: user manual and changelog
  -> Google Apps Script web app: feedback intake endpoint
  -> Google Sheet: public-user feedback inbox and triage table
  -> MailApp email notification: optional new-feedback alert
  -> iCloud / CloudKit: optional same-Apple-ID sync transport for structured app data
  -> App Store Connect / TestFlight: internal testing and distribution
  -> YouTube: reference link or official player only
  -> Audiveris / OMR tools: development or server-side score recognition baseline
  -> OSMD web renderer: bundled local MusicXML engraving surface inside the app
```

## Level 2: Containers

```text
VocalDive Apple App
  - iPhone, iPad, macOS
  - SwiftUI app shell
  - local-first data and practice UI
  - Settings sync control and first-run sync choice
  - Score area split into direct MusicXML editing and scan-to-MusicXML intake

VocalDiveCore
  - MusicXML parser
  - ScoreDocument model
  - MIDI event generation
  - target pitch timeline
  - YIN pitch tracking baseline
  - score/audio alignment
  - usage analytics ledger

Persistence Layer
  - SwiftData-backed structured records
  - local store + optional CloudKit-backed store
  - Application Support asset storage for imported/generated score files

Support Site
  - static HTML under docs
  - published through GitHub Pages
  - manual, changelog, support links

Feedback Backend
  - Google Apps Script web app
  - appends to Google Sheet
  - optional email notification to maintainer

GitHub Repo
  - source code
  - docs
  - release and backup point

Notion Workspace
  - product planning
  - research notes
  - roadmap and portfolio strategy
```

## Level 3: Component Map

```text
SwiftUI App
  ContentView
    SidebarView
    CompactScoreHubView
    DashboardView
    ScoreWorkspaceView
    MusicXMLScoreWebView
    PracticeView
    ExperimentalFeaturesView
    ResearchStatusView
    SupportView
    UsageStatsView

App Services
  VocalDiveWorkspace
    - app state
    - selected score and part
    - compact iPhone Score hub mode coordination
    - score landing mode coordination (`MusicXML Editor` vs `Scan to MusicXML`)
    - playback state
    - restored score session bootstrap
    - sync status / first-run sync choice state
    - persisted annotation state
    - localized compose fallback normalization before core import/export
    - sample score orchestration and benchmark status
  MIDIPlaybackService
    - plays generated MIDI
  LivePitchCaptureService
    - microphone capture
    - YINPitchTracker bridge
  UsageTrackingStore
    - persists usage ledger through SwiftData-backed records
  FeedbackSubmissionService
    - builds native feedback payload
    - posts to Google Apps Script
    - handles cooldown and submission state
  NativeOMRPrototypeService
    - rasterizes PDF/image pages natively
    - preserves per-page geometry and tile metadata
    - estimates narrow notation structure page by page
    - merges multi-page results into one score-level candidate
    - emits prototype MusicXML for the editor/review flow
  MusicXML editor bridge
    - local `WKWebView` host
    - bundled `OSMD` renderer
    - Swift <-> JavaScript bridge for render / rerender / selection sync
  PersistenceCoordinator
    - bootstraps local / cloud-backed stores
    - migrates legacy settings and usage data
    - persists score library metadata
    - copies score assets into Application Support
    - switches active data universe when sync is enabled or disabled
  Localization layer
    - `L10n`, `AppLanguage`, `AppSettingsStore`, `AppResourceLocator`
    - app-side rendering of semantic text tokens from core
    - shared bundle resource resolution for localized strings, app JSON config, OSMD assets, and bundled sample scores across both SwiftPM and Xcode app-target builds
  ExperimentalFeaturesView
    - sing-to-dismiss alarm prototype
    - bilingual text rhythm speech prototype
    - current trimmed Experimental surface without the removed research-notes panel

Core Domain
  MusicXMLImporter
  MusicXMLComposer
  ScoreDocument
  MIDIWriter
  ScoreTimelineBuilder
  PitchDeviationAnalyzer
  ScoreAudioAlignmentAnalyzer
  UsageAnalyticsLedger
  OMRPipelinePlan
  LocalizedTextToken
```

## Level 4: Important Code Paths

### MusicXML To Playback

```text
MusicXML file
  -> MusicXMLImporter
  -> ScoreDocument
  -> MIDIWriter
  -> MIDIPlaybackService
  -> AVAudio / platform playback
```

### Direct MusicXML Editing

```text
Pasted or imported MusicXML
  -> VocalDiveWorkspace import path
  -> MusicXMLImporter
  -> ScoreDocument
  -> MusicXMLEditorSession
  -> WKWebView + OSMD
  -> Inspector edits
  -> MusicXMLComposer
  -> refreshed MusicXML + ScoreDocument
```

### Scan To MusicXML

```text
PDF/image import
  -> NativeOMRPrototypeService
  -> page images + page-aware geometry metadata
  -> prototype MusicXML candidate
  -> MusicXMLImporter
  -> ScoreDocument
  -> MusicXMLEditorSession
  -> left source sidebar + right OSMD editor
```

### Live Practice Feedback

```text
Microphone input
  -> LivePitchCaptureService
  -> YINPitchTracker
  -> PitchSample contour
  -> PitchDeviationAnalyzer
  -> UI feedback
```

### Score / Audio Alignment

```text
ScoreDocument
  -> ScoreTimelineBuilder
  -> TargetPitchPoint timeline

Local or licensed audio
  -> pitch tracking / onset detection
  -> PitchSample contour

TargetPitchPoint + PitchSample
  -> ScoreAudioAlignmentAnalyzer
  -> blue PerformanceDifference
  -> non-destructive AudioEditProposal
```

### Support And Feedback

```text
SupportView
  -> GitHub Pages manual/changelog
  -> FeedbackSubmissionService
  -> Google Apps Script web app
  -> Google Sheet
  -> optional email notification
```

### Usage Analytics

```text
ContentView / selectedSection changes
  -> UsageTrackingStore
  -> UsageAnalyticsLedger
  -> PersistenceCoordinator
  -> SwiftData usage records
  -> UsageStatsView
```

### Persistent Scores And Sync

```text
Imported MusicXML / composed score
  -> ImportedAssetStore
  -> Application Support score file
  -> PersistenceCoordinator
  -> ScoreLibraryItemRecord + selected score setting
  -> VocalDiveWorkspace restore path on next launch

Display language / sync preference / usage records
  -> UserProfileSettingsRecord + UsageAnalyticsRecord
  -> local SwiftData store
  -> optional CloudKit-backed SwiftData store
  -> same-Apple-ID device sync when cloud path is available
```

### Native OMR Prototype

```text
PDF/image import
  -> NativeOMRPrototypeService
  -> native page rasterization
  -> page-level notation estimates + geometry metadata
  -> multi-page merge
  -> MusicXMLComposer prototype output
  -> MusicXMLImporter
  -> ScoreDocument
  -> ScoreReviewSession
  -> shared MusicXML editor / review flow
```

### Sample Verification

```text
Bundled Twinkle intact / scanned fixtures
  -> SampleScoreLibrary
  -> direct ground-truth editor load or prototype OMR run
  -> benchmark checks
    - parser/import success
    - page count
    - measure count
    - playable note count
    - pitch sequence
  -> visible benchmark summary in Score workspace
```

## Current Architecture Judgment

The app is correctly moving toward a shared-core architecture:

- Apple UI can differ by device later.
- Domain logic stays in `VocalDiveCore`.
- Localization stays in `VocalDiveApp`; core exposes semantic identifiers instead of localized strings.
- iOS, iPadOS, and macOS share the same parser, pitch timeline, alignment, and usage analytics.
- Durable user data now belongs in a structured persistence layer rather than scattered `UserDefaults` blobs.
- External OMR providers remain the higher-accuracy research baselines.
- The shipped app now has a narrow native OMR prototype path for simulator/debug validation of PDF rasterization, page stitching, and MusicXML re-entry.
- A real bundled recognition model can replace the current prototype estimator later without changing the surrounding review workflow.
- The `Score` area is now intentionally split: direct MusicXML editing iterates separately from scan-to-MusicXML, while both converge on the same editor surface and score model.
- The current formal engraving layer is bundled `OSMD` inside a local web view, while the native Swift symbolic panels remain the structured editing and benchmark surface.


### 2026-07-08 update - oemer migration framing

The OMR architecture should now be treated as a five-layer porting problem rather than a single monolithic provider swap:

1. native PDF/photo preprocessing
2. portable model inference runtime
3. shared Swift symbol reconstruction
4. score semantics and MusicXML export
5. editor/review handoff inside the existing `Scan to MusicXML` flow

This keeps the user-facing product surface simple while allowing `oemer` to remain a parity reference instead of a pretend in-app runtime.
