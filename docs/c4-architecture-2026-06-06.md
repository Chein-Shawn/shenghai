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

ShenghaiCore
  - MusicXML parser
  - ScoreDocument model
  - MIDI event generation
  - target pitch timeline
  - YIN pitch tracking baseline
  - score/audio alignment
  - usage analytics ledger

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
    DashboardView
    ScoreWorkspaceView
    PracticeView
    ResearchStatusView
    SupportView
    UsageStatsView

App Services
  ShenghaiWorkspace
    - app state
    - selected score and part
    - playback state
    - localized compose fallback normalization before core import/export
  MIDIPlaybackService
    - plays generated MIDI
  LivePitchCaptureService
    - microphone capture
    - YINPitchTracker bridge
  UsageTrackingStore
    - stores usage ledger in UserDefaults
  FeedbackSubmissionService
    - builds native feedback payload
    - posts to Google Apps Script
    - handles cooldown and submission state
  Localization layer
    - `L10n`, `AppLanguage`, `AppSettingsStore`
    - app-side rendering of semantic text tokens from core

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
  -> UserDefaults
  -> UsageStatsView
```

## Current Architecture Judgment

The app is correctly moving toward a shared-core architecture:

- Apple UI can differ by device later.
- Domain logic stays in `ShenghaiCore`.
- Localization stays in `ShenghaiApp`; core exposes semantic identifiers instead of localized strings.
- iOS, iPadOS, and macOS share the same parser, pitch timeline, alignment, and usage analytics.
- OMR remains outside the shipped app until a legal, reliable, and App-Store-safe path is selected.
