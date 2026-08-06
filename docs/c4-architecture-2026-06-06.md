# C4 Architecture Plan

Established Date: 2026-06-06

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
  -> VocalDiveWorkspace + RemoteOMRService
  -> one-time upload disclosure + durable local staged source copy
  -> Cloudflare Tunnel HTTPS + email-link device authentication
  -> 714 FastAPI + SQLite accounts/devices/queue + single oemer GPU worker
  -> page images + page-aware geometry metadata + MusicXML candidate
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

### Scan To MusicXML Model Path

```text
PDF/image import
  -> NativeOMRPrototypeService
  -> native page rasterization
  -> VocalDiveOMRModelService
  -> bundled oemer Core ML model readiness check
  -> model inference when `oemer_1st_model.mlmodelc` and `oemer_2nd_model.mlmodelc` exist
  -> Swift score reconstruction / postprocess
  -> MusicXMLComposer candidate output
  -> MusicXMLImporter -> ScoreDocument
  -> ScoreReviewSession -> shared MusicXML editor / review flow
```

If the bundled Core ML models are missing, the pipeline stops at the model-readiness stage and reports a clear scan error. It should not fall back to fake heuristic MusicXML output in user-facing builds.

### Sample Verification

```text
Bundled Twinkle intact / scanned fixtures
  -> SampleScoreLibrary
  -> direct ground-truth editor load or scan-flow smoke test
  -> internal benchmark checks
    - parser/import success
    - page count
    - measure count
    - playable note count
    - pitch sequence
  -> developer verification notes, not a general user-facing benchmark panel
```

## Current Architecture Judgment

The app is correctly moving toward a shared-core architecture:

- Apple UI can differ by device later.
- Domain logic stays in `VocalDiveCore`.
- Localization stays in `VocalDiveApp`; core exposes semantic identifiers instead of localized strings.
- iOS, iPadOS, and macOS share the same parser, pitch timeline, alignment, and usage analytics.
- Durable user data now belongs in a structured persistence layer rather than scattered `UserDefaults` blobs.
- External OMR providers remain research references, not user-facing choices.
- The shipped app now exposes one user-facing scan path: `Scan to MusicXML`.
- The scan path has an explicit model gate for bundled oemer Core ML models. Until those models are converted and bundled, scan stops honestly instead of producing fake MusicXML.
- The `Score` area is now intentionally split: direct MusicXML editing iterates separately from scan-to-MusicXML, while both converge on the same editor surface and score model.
- The native OMR model service now has a prediction-map handoff boundary: Core ML `MLMultiArray` outputs are normalized into Swift prediction maps before any score reconstruction runs.
- The first implemented map consumer is staff/system detection. Notehead, rest, clef, accidental, key/time, and rhythm reconstruction remain the next Swift postprocess porting layer.
- The current formal engraving layer is bundled `OSMD` inside a local web view, while the native Swift symbolic panels remain the structured editing and benchmark surface.


### 2026-07-08 update - oemer migration framing

The OMR architecture should now be treated as a five-layer porting problem rather than a single monolithic provider swap:

1. native PDF/photo preprocessing
2. portable model inference runtime
3. shared Swift symbol reconstruction
4. score semantics and MusicXML export
5. editor/review handoff inside the existing `Scan to MusicXML` flow

This keeps the user-facing product surface simple while allowing `oemer` to remain a parity reference instead of a pretend in-app runtime.

### 2026-07-09 update - oemer conversion and prediction-map boundary

The deployable OMR path is now documented as two parallel tracks:

1. Conversion track: official oemer ONNX checkpoints stay in `/Users/shawn/Documents/Codex/vocaldive-ml/oemer/checkpoints`, are converted through reproducible scripts, and only compiled Core ML artifacts are intended for `Resources/OMRModels/`.
2. Runtime track: `VocalDiveOMRModelService` loads `oemer_1st_model.mlmodelc` and `oemer_2nd_model.mlmodelc`, runs Core ML, converts `MLMultiArray` outputs into prediction maps, then passes those maps into Swift reconstruction.

The current runtime has the resource gate and prediction-map parser in place. As of the latest conversion pass, `VocalDiveOMRModelService` can prepare either Core ML image input or `MLMultiArray` input and normalize NHWC/HWC or NCHW/CHW outputs into one Swift prediction-map boundary. The remaining architecture gaps are: successful Core ML artifact generation, hand-repaired oemer graph conversion or another Apple-friendly export path, and the full Swift equivalent of oemer's postprocessing: symbol grouping, duration inference, measure semantics, and richer MusicXML export.

### 2026-07-10 update - real-image choral OMR research pipeline

The app flow remains `Scan to MusicXML -> editor/review`. A separate external-SSD research container now prepares a future Apple-friendly model without placing datasets or checkpoints in the app bundle:

`paired real score image + corrected MusicXML -> page/staff metadata -> staff crop + LMX target -> research checkpoint -> Apple export candidate -> VocalDive model service`.

The research model operates staff-wise with page/system/measure metadata used by a score assembler. This supports a variable number of staves: SATB, reduced two-staff choir notation, SATB plus piano, and other multi-part layouts. Raw datasets, JSONL manifests, checkpoints, and evaluation reports remain outside git; the repository stores reproducible tools and this architecture contract. The current external SSD does not support SQLite journaling, so any future SQLite index must be an optional, rebuildable local cache.

The first target-domain fixture is a three-page SATB a cappella score with both
clean and annotated scanned inputs. Its visible two-staff systems are kept
separate from the MusicXML part/voice structure, because printed staff layout
and MusicXML parts are not guaranteed to be one-to-one. Page/system/measure
metadata therefore remains an explicit boundary between image preparation,
model inference, and MusicXML assembly.

### 2026-07-11 update - CPDL-v1 preparation boundary

The CPDL paired records are now versioned outside the app repository as
`prepared/cpdl-v1`. The release contains a score-level 70/15/15 split and
300-DPI page images. A staffline-based detector proposes system boxes, but
every proposed box is marked `manual_review_required` until its PDF page and
MusicXML measure range are confirmed. Only explicitly verified rows can create
MusicXML fragments and LMX training targets. This prevents a convenient but
incorrect automatic page-to-measure assumption from becoming model truth.

The alignment review is performed with a local click-through tool. It shows
one candidate system at a time with the source-page red box and a visual
OSMD-rendered MusicXML preview side by side. Reviewers compare the printed
system against the engraved score rather than reading raw XML, then use
Correct / Incorrect / Skip and write verified measure ranges back to the
external JSONL manifest. This keeps review state out of the app and makes the
training target creation reproducible. The bundled renderer is served locally
from the repository, so the review workflow does not depend on a CDN.

### 2026-07-11 update - CPDL research ingestion and baseline gate

CPDL ingestion is an external research-data stage, not an app resource stage:

```text
CPDL category/API discovery
  -> voice-count filter (S/A/T/B <= 2, total <= 8)
  -> PDF/MusicXML/MXL download and validation
  -> compact provenance manifest
  -> paired / pdf-only / musicxml-only / review-needed tiers
  -> system crops and LMX targets
  -> baseline checkpoint
  -> Core ML export candidate
```

The crawler preserves edition URLs and license text and marks all downloaded
CPDL material as research-only until it is reviewed. A first 12-system Jordan
SATB MPS baseline has completed, but it is only a pipeline verification
checkpoint. The app still has no bundled production OMR model until a larger
paired dataset, held-out evaluation, and Apple export have passed.

### 2026-07-11 update - CPDL vocal processing and baseline result

The first reviewed CPDL subset is now processed through a conservative,
voice-aware derived-data stage:

reviewed PDF/MusicXML system
  -> note rule extraction
  -> vocal/instrument part classification
  -> explicit pitch normalization
  -> MusicXML fragment
  -> LMX training manifest

The source review manifest is immutable. Verified systems with clear vocal
parts become training examples; ambiguous generic parts are quarantined rather
than guessed. The initial release produced 403 accepted systems, 32
quarantined systems, and 40 rejected systems. The remaining 2,618 systems are
still unreviewed and are excluded from supervised training.

The first 10-epoch MPS LMX baseline confirms the end-to-end data path but
overfits: training loss reached 2.55, while best held-out test token accuracy
was only 4.06% and exact sequence accuracy was 0%. The checkpoint is therefore
research-only. Core ML conversion and app bundling remain blocked until the
model architecture, dataset size, and held-out quality improve.

### 2026-07-28 update - private 714 GPU OMR beta

The deployable beta path now deliberately separates the product scanner from
the Apple-native OMR research path:

```text
VocalDive app
  -> RemoteOMRService
  -> private staged source copy + retry identity
  -> Cloudflare Tunnel HTTPS at omr.vocaldive.com
  -> 714 FastAPI boundary
  -> SQLite durable queue
  -> one RTX 3090 oemer worker
  -> per-page diagnostics and candidate MusicXML
  -> MusicXMLImporter + ScoreReviewSession
  -> original pages at left / OSMD editor at right
```

`RemoteOMRConfigurationStore` defaults to `https://omr.vocaldive.com`, saves the
editable HTTPS endpoint in user defaults, and stores an email-link device credential
in Keychain. It validates a 50 MiB total job, one
PDF of at most 30 pages, or a batch of at most 30 images before upload; the
714 API repeats these checks. The app copies selected sources into its private
application-support queue before network work begins. A finished result clears
that local copy; interrupted work is retried on the next app launch using the
same idempotency key. iPhone and iPad uploads use a background `URLSession`
with an App Delegate handoff for system-delivered completion events; macOS
uses the same staged retry contract while the app is active.

Before staging or uploading a scan, the app checks for the Keychain-held device
credential. A disconnected installation stays local, explains that connection is
required, and navigates to Settings instead of presenting this as a failed OMR job.

714 binds its FastAPI process only to loopback. A Cloudflare Tunnel provides
the HTTPS endpoint at `omr.vocaldive.com` without exposing a router port or
requiring beta users to install a VPN client. The service stores the original upload, rendered
pages, oemer logs, diagnostics, candidate MusicXML, and job metadata under a
date/job folder. It never automatically deletes those folders; the host owner
removes completed date folders manually. `Available`, `Quiet`, and `Paused`
are persisted worker modes. Quiet inspects NVIDIA utilization and VRAM before
starting the next queued job; one GPU recognition job runs at a time.

The worker sends verification links to Resend over an explicit `certifi` CA
bundle. This keeps the Python worker's outbound TLS verification independent of
the Windows/PowerShell certificate path used for host diagnostics.

Email-link authentication separates public beta access from host operation:

```text
VocalDive App email entry
  -> POST /v1/auth/request-link
  -> Keychain poll secret + app-storage non-secret pending-session metadata
  -> Resend from access@auth.vocaldive.com
  -> one-time verification link
  -> verification page instructs the user to return to the requesting device
  -> POST /v1/auth/poll resumes the pending installation session
  -> account hash + separate hashed device credential in 714 SQLite
  -> Keychain on the originating Apple device
  -> account-owned OMR jobs and results
```

`tokens.json` remains strictly operator-only for worker mode and storage dashboard
endpoints. It is not entered into VocalDive and cannot access ordinary user jobs.

The authentication API emits expiry values as RFC 3339 UTC `Z` timestamps without fractional
seconds. The App parser also accepts the prior fractional-second representation, allowing a
mobile release and worker release to be deployed independently. It stores the pending poll secret
in Keychain and only the login ID, normalized email, and expiry in app storage. Foregrounding the
App or reopening Settings resumes polling until the link is consumed, expired, disconnected, or
the server address changes. Development diagnostics record only the connection stage and HTTP
status; they never record emails, device credentials, poll secrets, or verification URLs.

Email links are one-use and default to a twenty-four-hour lifetime, configured by
`VOCALDIVE_OMR_AUTH_LINK_TTL_HOURS`. The longer beta lifetime supports a user or developer
returning later, while one-use consumption and hashed secrets preserve the device-connection
boundary. Links already issued retain the expiry stored when they were created.

Email-link delivery limits are configurable in the 714 `.env`. The public beta defaults to
ten accepted link requests per email and forty per source IP in a fifteen-minute window.
The service returns HTTP `429` with a retry duration before creating a login session; a Resend
failure removes the pending session and does not consume either allowance.

This is the only product-visible OMR route for the private beta. The Core ML,
DeepScores, CPDL, and Swift reconstruction work remains a separate future
on-device path and is not presented to a beta user as a working scanner.

### 2026-07-29 update - 714 CRM, consent, and correction stewardship

The beta server now separates durable OMR work from personal account data:

```text
Apple app installation UUID in Keychain
  -> email link and accepted data-notice version
  -> 714 crm.sqlite3 under D:\VocalDiveOMR\state
  -> account + installation-scoped hashed device credential
  -> account-owned OMR job in jobs.sqlite3
  -> dated source/result folder under D:\VocalDiveOMR\data
  -> optional completed-correction training record
```

`crm.sqlite3` contains account email, optional birthday, optional singing goals,
consent acceptance, device rows, email-link sessions, delivery-limit events, and
training-record metadata. Email, birthday, and goals remain normal SQLite fields;
disk-at-rest protection is BitLocker plus a `SYSTEM`/Administrators-only state
directory ACL. Device credentials and magic-link secrets are SHA-256 hashes only,
so the server cannot recover their raw values from the database.

There is exactly one current credential per `(account_id, installation_id)` pair:
reconnecting the same installation rotates and revokes its prior credential,
while a second device receives an independent credential. The magic link remains
single-use and defaults to a 24-hour lifetime; it authorizes the pending login created by the
originating app even when the email is opened on another device. Deleting an
account revokes every credential and removes profile data; completed correction
records remain without profile data so already-consented training material has
an audit trail.

The review editor has deliberately distinct actions. `暫存進度` writes an edited
MusicXML score to the local Apple persistence layer and sends nothing to 714.
`完成校正` creates one idempotent record linking the retained source job, candidate
MusicXML, corrected MusicXML, checksums, correction metadata, account, and consent
version. If manual date-folder cleanup removed the original source, the server
returns an explicit re-upload requirement rather than storing an incomplete record.

CRM backup is intentionally narrow: a daily SQLite snapshot, schema version, and
checksum manifest can be copied to Google Drive through rclone. Raw scores and
OMR job folders are excluded and remain manually managed by date. Cloudflare
Tunnel remains only the protected public route; a managed database such as
Cloudflare D1 is a future scaling migration target, not the current source of truth.

### 2026-07-30 update - remote engine readiness boundary

The 714 worker resolves the `oemer` console program from the same Python virtual environment
that starts FastAPI, rather than inheriting a fragile Windows `PATH` lookup. `/v1/health` reports
`engine_ready`; if the engine is unavailable, `POST /v1/jobs` fails before accepting an upload.
If the executable disappears during a job, the queue records the stable `engine_unavailable`
code while the host-only log retains the operating-system diagnosis. `RemoteOMRService` maps that
code to localized recovery copy before the Score workspace displays it.

Any later worker failure is also represented by a stable phase code:
`source_processing_failed`, `recognition_failed`, `result_assembly_failed`, or `worker_failed`.
The API retains the phase and host diagnostics in the date/job folder and worker log, while the
app presents the same localized retry guidance without exposing Windows paths, subprocess output,
or internal model details.

### 2026-07-30 update - responsive remote source preparation

The Score workspace remains on the main actor for SwiftUI state, but remote source preparation
does not: local PDF/image rasterization and multipart body-file creation run in a detached
user-initiated task before the background upload begins. This preserves the local review image
handoff while keeping a multi-page scan responsive during preparation and upload.

### 2026-08-06 update - monitored remote recognition runtime

The remote worker no longer waits silently for an entire page-level `oemer` process to exit.
It streams combined standard output and error into each page diagnostics folder, then normalizes
known output into a deliberately small runtime vocabulary:

```text
model_stafflines -> model_symbols -> dewarping -> stafflines
-> noteheads -> symbols -> rhythm -> building_musicxml
```

Every ten seconds, the worker persists current page, normalized stage, elapsed time, heartbeat,
process liveness, GPU/VRAM, recognition-process CPU/RAM, and currently observable output artifacts
to `jobs.sqlite3` and the date/job `job.json`. `events.jsonl` records normalized state transitions;
raw stdout/stderr remains only in the host diagnostics folder. A seven-minute unchanged-stage warning
is surfaced as clear nontechnical App copy and does not cancel the job. The page deadline remains
twenty minutes, after which the worker terminates the subprocess and records `recognition_timeout`.

The owner-scoped job API exposes only sanitized fields (`engine_stage`, `elapsed_seconds`,
`heartbeat_at`, `attention_needed`, and resource snapshots). Debug builds of VocalDive can display a
copyable redacted diagnostic report; production builds show only localized progress such as
preparing, analyzing notation, reading noteheads, and building an editable score. Stable recognition
failure codes distinguish process exit, timeout, missing output, invalid MusicXML, and incompatible
page merging. Daily rotating host logs live under `D:\VocalDiveOMR\state\logs`, allowing the
scheduled worker to remain diagnosable with no PowerShell window open.
