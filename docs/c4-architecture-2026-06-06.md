# C4 Architecture Plan

Date: 2026-06-06

## Level 1: System Context

```text
Singer / Choir Member
  -> uses Shenghai App
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
```

## Level 2: Containers

```text
Shenghai Apple App
  - iPhone, iPad, macOS
  - SwiftUI app shell
  - local-first data and practice UI
  - Settings sync control and first-run sync choice

ShenghaiCore
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
    PracticeView
    ExperimentalFeaturesView
    ResearchStatusView
    SupportView
    UsageStatsView

App Services
  ShenghaiWorkspace
    - app state
    - selected score and part
    - compact iPhone Score hub mode coordination
    - playback state
    - restored score session bootstrap
    - sync status / first-run sync choice state
    - persisted annotation state
    - localized compose fallback normalization before core import/export
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
    - emits prototype MusicXML for the existing importer/review flow
  PersistenceCoordinator
    - bootstraps local / cloud-backed stores
    - migrates legacy settings and usage data
    - persists score library metadata
    - copies score assets into Application Support
    - switches active data universe when sync is enabled or disabled
  Localization layer
    - `L10n`, `AppLanguage`, `AppSettingsStore`
    - app-side rendering of semantic text tokens from core
  ExperimentalFeaturesView
    - sing-to-dismiss alarm prototype
    - bilingual text rhythm speech prototype
    - current trimmed Experimental surface without the removed research-notes panel

Core Domain
  MusicXMLImporter
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
  -> ShenghaiWorkspace restore path on next launch

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
  -> existing Score workspace review flow
```

## Current Architecture Judgment

The app is correctly moving toward a shared-core architecture:

- Apple UI can differ by device later.
- Domain logic stays in `ShenghaiCore`.
- Localization stays in `ShenghaiApp`; core exposes semantic identifiers instead of localized strings.
- iOS, iPadOS, and macOS share the same parser, pitch timeline, alignment, and usage analytics.
- Durable user data now belongs in a structured persistence layer rather than scattered `UserDefaults` blobs.
- External OMR providers remain the higher-accuracy research baselines.
- The shipped app now has a narrow native OMR prototype path for simulator/debug validation of PDF rasterization, page stitching, and MusicXML re-entry.
- A real bundled recognition model can replace the current prototype estimator later without changing the surrounding review workflow.
