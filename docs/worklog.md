# VocalDive Worklog

This is the concise, chronological record of versioned VocalDive work. It is
the active source of truth for what changed, why it changed, and where the
important decisions live. The former free-form log is preserved unchanged in
[the pre-restructure archive](archive/worklog-legacy-before-2026-07-29.md).

## Logging Contract

- Add or update the entry for the day whenever a versioned change is made.
- Use one `## YYYY-MM-DD — title` heading per day. Group related commits under
  that heading rather than adding disconnected mini-logs.
- Record outcomes, decisions, blockers, and verification. Do not paste raw
  command transcripts, secrets, user data, or generated binaries.
- A calendar day with no committed repository work does not need an entry.
- Before committing, run `python3 tools/check_worklog_coverage.py`. The local
  Git hook and GitHub Actions run the same check so missing workdays fail
  visibly rather than becoming historical gaps.

## Chronological Ledger

## 2026-06-05 — Foundation, MusicXML direction, and OMR baseline research

- Established the repository, selected MusicXML as the interchange format, and
  created the initial `ScoreDocument` / MIDI prototype.
- Investigated Audiveris and preserved a reproducible baseline command after
  the development branch exposed a Java-version mismatch.
- Added the first shared Swift score, MusicXML import, MIDI-writing, and pitch
  analysis primitives.

## 2026-06-06 — Multiplatform shell and early product architecture

- Added the SwiftUI macOS/iOS app shell, score import, practice preview, and
  composition path; validated SwiftPM and Xcode build routes.
- Defined replaceable OMR and pitch-tracking boundaries, score/audio alignment,
  support-site, analytics, C4, localization, and license-audit foundations.
- Introduced the first external OMR-provider research interface and a simple
  MusicXML composition workflow.

## 2026-06-07 — Experimental singing and speech prototypes

- Added experimental sing-to-dismiss and phrase/rhythm speech-practice flows.
- Documented their platform and product boundaries: notification-driven alarm
  re-entry and non-medical rhythm-practice framing.
- Updated the public support experience and bilingual demo surface.

## 2026-06-08 — Full-score review and bilingual phrase practice

- Made PDF/image-to-MusicXML review a first-class product flow while keeping
  actual image recognition external.
- Expanded score preservation for metadata, lyrics, directions, dynamics,
  repeats, and review summaries.
- Reworked speech practice around punctuation and phrase segmentation for
  English, Chinese, and mixed-language input.

## 2026-06-12 — App localization and build-path repair

- Repaired app-state and Xcode project integration issues, then added the
  first centralized display-language architecture and language picker.
- Expanded the localization and C4 documentation so product copy and app state
  had explicit ownership boundaries.

## 2026-06-13 — Persistent score library and optional sync

- Added SwiftData-backed persistence for settings, scores, annotations, and
  usage history, with optional CloudKit synchronization.
- Preserved local-first behavior and added first-run sync choices in Settings.

## 2026-06-14 — Product-surface cleanup and localization infrastructure

- Focused the Experimental area on active prototypes and aligned dashboard,
  manual, changelog, and shipped strings with that decision.
- Removed app-layer localization calls from `VocalDiveCore` and replaced them
  with semantic presentation tokens rendered by the app layer.

## 2026-06-15 — Native multi-page OMR prototype

- Added the first native multi-page OMR import/review pipeline and preserved
  original-page references alongside editable score candidates.
- Kept the prototype status explicit: visual recognition itself was not yet a
  deployable on-device model.

## 2026-06-22 — Score review workflow stabilization

- Repaired the compact iPhone Score navigation state so imported or composed
  scores reliably open in the review workspace.
- Fixed Xcode target membership and MusicXML composition build issues; verified
  an iOS Simulator build.

## 2026-06-23 — Custom-domain publication

- Added the GitHub Pages custom-domain configuration for the public site.

## 2026-07-03 — Score editor and scanner separation

- Split the Score editor from the Scan to MusicXML path so editing and import
  review have distinct, understandable product flows.

## 2026-07-08 — VocalDive brand migration

- Migrated app paths, repo tooling, documentation, and public website language
  from Shenghai to VocalDive / 聲潛.
- Defined the Apple-native OMR migration direction while retiring research-only
  provider language from normal user surfaces.

## 2026-07-09 — oemer audit, conversion tools, and honest model boundary

- Audited official oemer checkpoints, added reproducible conversion tooling,
  and prepared the app to consume prediction maps when real artifacts exist.
- Recorded the ONNX-to-Core ML layout/shape blockers rather than presenting the
  heuristic prototype as working OMR.

## 2026-07-10 — Choral dataset preparation and SATB fixture

- Added the Jordan SATB fixture, OpenScore evaluation extraction, and a
  versioned choral OMR dataset/training scaffold on the external SSD.
- Advanced oemer graph-repair experiments and deployed the refreshed public
  website, manual, and changelog.

## 2026-07-11 — CPDL review tooling and the symbol-OMR pivot

- Built the resumable CPDL crawler, pairing pipeline, visual MusicXML reviewer,
  navigation preservation, and voice-aware derived-data processing.
- Ran the first direct MusicXML-sequence baseline and documented its failure:
  it overfit and is not eligible for Core ML or product use.
- Chose the staged route: staff/system geometry, symbol detection, structured
  music events, and MusicXML assembly. Added reviewer-editable symbol types and
  the first 14-class OMR v1 schema.

## 2026-07-12 — Public VocalDive experience refresh

- Rebuilt the public site, manual, changelog, and singing demo around a dark
  choir-rehearsal console with interactive motion and user-triggered tones.
- Improved reference-note ranges and replaced short beeps with longer,
  tuning-fork-like rehearsal tones.

## 2026-07-13 — DeepScores pretraining and assisted annotation

- Added class mapping, metrics, staged training, prediction previews, and a
  score-level split for the 14-class detector research path.
- Produced a small DeepScores pretraining signal and a 150-system CPDL review
  queue without treating model suggestions as ground truth.

## 2026-07-20 — Cinematic public landing page

- Rebuilt the homepage as a two-scene VocalDive introduction with full-screen
  choir imagery, liquid-glass controls, blur/reveal motion, and no autoplayed
  sound.

## 2026-07-28 — Private 714 GPU OMR beta

- Added the private scan route: VocalDive app → Cloudflare HTTPS → 714 Windows
  worker → RTX 3090 oemer → MusicXML review editor.
- Implemented durable upload staging/retry, a single GPU worker queue,
  50 MiB / 30-page-or-image limits, date/job retention, diagnostics, and
  operator mode controls.

## 2026-07-29 — Email-link access and Resend transport reliability

- Replaced user-visible beta tokens with email-link device connection. The app
  defaults to `https://omr.vocaldive.com`, stores device credentials in
  Keychain, and exposes server configuration only in advanced settings.
- Added account-scoped jobs, one-time links, device credentials, request rate
  limits, first-scan upload disclosure, and Resend delivery through
  `access@auth.vocaldive.com` with replies to `support@vocaldive.com`.
- Hardened the 714 worker's Resend HTTPS transport with an explicit `certifi`
  CA bundle and safe status-only failure logging after Windows PowerShell proved
  the Resend account and sender path were healthy.
- Replaced the unapproved restrictive email-link limit with a configurable public-beta policy:
  ten accepted requests per email and forty per IP in fifteen minutes. Rate-limit responses now
  report a retry duration, while failed Resend deliveries do not consume a request.
- C4 and localization impact checked: app settings now localize the retry duration in every
  shipped language.

### 714 CRM protection and correction records

- Split personal beta data into `crm.sqlite3` under the 714 state root while
  retaining the durable worker queue and date-based score folders as separate
  concerns. Device credentials and email-link secrets are now hash-only;
  email, optional birthday, and goals remain normal SQLite fields protected by
  BitLocker and state-directory ACL guidance rather than app-level encryption.
- Added stable app-installation identities, same-installation credential rotation,
  account profile/update/delete APIs, and account deletion that revokes every
  device credential while retaining anonymized, consented correction records.
- Added local-only `暫存進度` and explicit `完成校正` flows. Completed corrections
  are idempotent records linking the retained job, candidate, corrected MusicXML,
  checksums, metadata, and accepted consent version; missing manually deleted
  sources require an intentional re-upload.
- Added CRM-only Google Drive snapshot/restore tooling, BitLocker/ACL verification
  scripts, 714 setup documentation, C4 coverage, and all shipped app localizations.
