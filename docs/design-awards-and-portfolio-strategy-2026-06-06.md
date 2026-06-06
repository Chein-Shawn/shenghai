# Shenghai Design, Awards, and Portfolio Strategy

Date: 2026-06-06

## Product UI Direction

Shenghai should not copy MuseScore Studio or forScore. It should borrow the product logic that matters:

- From MuseScore Studio: score-centered playback, part-level mixer, MusicXML/MIDI interoperability, and a dense editing workspace.
- From forScore: iPad-first reading comfort, page-first layout, fast annotation/correction, performance-safe controls, and minimal visual interruption.
- Shenghai's own layer: vocal-part practice, live pitch feedback, OMR uncertainty review, and long-term practice history.

The implemented UI direction is a three-zone studio:

- Left: score parts, practice modes, and navigation.
- Center: the score/practice page as the main visual object.
- Right: mixer, OMR review, live pitch, target pitch, and build queue.

This keeps one shared SwiftUI codebase while allowing iPhone to collapse into stacked navigation and iPad/macOS to use a wider studio layout.

## Current Platform Architecture

The code is not split into three separate apps. Current structure is:

- One Xcode project: `ios-app/Shenghai.xcodeproj`
- One shared Swift package: `ios-app/ShenghaiCore`
- Shared core logic: MusicXML import, ScoreDocument, MIDI writer, OMR pipeline model, YIN pitch tracker.
- Shared SwiftUI app shell: the same view code builds for iPhone, iPad, and macOS.

Recommendation: keep this shared architecture until platform-specific needs are real. Add small `#if os(macOS)` or size-class branches only for interactions that genuinely differ.

## Apple Design Awards 2026 Lessons

Apple says the Apple Design Awards recognize apps and games for innovation, artistry, and technical achievement. In 2026, winners were selected from 36 finalists across six categories: Delight and Fun, Inclusivity, Innovation, Interaction, Social Impact, and Visuals and Graphics.

Useful lessons for Shenghai:

- Interaction: controls must feel native to the platform. For Shenghai, the key interaction is not a generic dashboard; it is touching a measure, hearing the target voice, singing, and seeing immediate pitch feedback.
- Inclusivity: Guitar Wiz won in Inclusivity for supporting musicians with spoken instruction and accessibility features. Shenghai can compete here if it supports Dynamic Type, high contrast, voice guidance, color-independent feedback, and beginner-friendly language.
- Innovation: Apple highlights novel use of Apple technologies. Shenghai should use on-device audio analysis, Core ML/Create ML where useful, Apple Pencil correction on iPad, SharePlay or spatial rehearsal later, and privacy-preserving practice analytics.
- Visuals and Graphics: Tide Guide won with clear, beautiful data presentation. Shenghai should make pitch history and progress charts visually precise, not decorative.
- Social Impact: Shenghai can frame itself around music education access, choir self-practice, and reducing dependence on paid accompaniment/coaching hours.

Most realistic Apple Design Awards target category:

1. Interaction
2. Inclusivity
3. Innovation

## International Awards to Consider

- Apple Design Awards: best after the app is polished, shipped, accessible, and deeply Apple-native.
- iF Design Award: has Service Design, UX, and UI concept categories; useful for app/service design credibility.
- Red Dot Design Award: strongest if Shenghai becomes a product system, for example app plus microphone/hardware/music stand accessory.
- Fast Company Innovation by Design: useful if Shenghai can show measurable impact in music education or accessibility.
- Indigo Design Award / i.design Award / UX Design Awards: practical for UI/UX case-study submissions.
- CES Innovation Awards: only worth considering after a real hardware or AI/audio product exists.

## Create ML Fit

Create ML is useful, but should not be forced into the MVP. It fits Shenghai in these places:

- Personalized vocal range and comfort-zone model: learn where the singer is stable, strained, or inconsistent.
- Pitch correction classifier: classify sung notes as stable, sliding, vibrato, overshooting, undershooting, or uncertain.
- OMR correction assist: learn from manual corrections to identify likely wrong notes or rhythms.
- Practice recommendation model: recommend short drills from past error clusters.
- On-device privacy story: training personalized models on the user's Mac/iPhone is aligned with sensitive voice data.

Avoid using Create ML for the first OMR engine. Full OMR model training is too large for the summer MVP. Use Audiveris/MusicXML first, then add Create ML to improve correction and practice personalization.

## COMPACT Microscopy Extension

The Nature Methods COMPACT paper describes a clear optically matched panoramic access channel for large-volume deep brain imaging. The paper's core claim is increased tissue access volume while keeping probe dimensions comparable to common GRIN lenses.

Possible bridge from Shenghai to COMPACT:

- Shared signal pipeline: both projects need synchronized time-series analysis, quality control, event detection, and visual review.
- Shenghai audio timeline -> calcium imaging event timeline: pitch deviation detection can become a general temporal-event detection framework.
- Score following -> scan/behavior alignment: align expected musical events to sung audio now; later align imaging frames to behavior/sleep/state events.
- OMR uncertainty UI -> microscopy QC UI: the same "flag uncertain regions for human correction" product pattern can apply to optical images.
- Hardware direction: build a low-cost vocal training device first, then use the same embedded sensing/product design skills for microscopy control hardware.

Do not merge the products too early. Keep Shenghai as the public app. Keep COMPACT-related work as a research toolkit module: time-series alignment, QC, and interactive review for biological imaging.

## MIT Portfolio Strategy

Based on the current CV, the strongest story is not "many unrelated awards." It is a coherent arc:

Physics + mechanical engineering + optics + computation + music perception + Apple product engineering.

Three-year project ladder:

1. Shenghai MVP
   - Outcome: TestFlight app, competition entry, user study with choir members.
   - Evidence: GitHub, demo video, Notion logs, test results, pitch-tracking validation.

2. Shenghai Research Paper / Poster
   - Topic: Real-time pitch feedback and practice adherence for amateur singers.
   - Evidence: small IRB-safe or informal user study, error reduction, practice retention.

3. OMR Correction Tool
   - Topic: human-in-the-loop MusicXML correction for choir scores.
   - Evidence: benchmark against simple public-domain scores, uncertainty UI.

4. Bio-Signal Timeline Toolkit
   - Translate Shenghai's audio timeline architecture to microscopy/calcium imaging event review.
   - Evidence: lab-use tool, advisor feedback, possible workshop poster.

5. Hardware Shenghai
   - Small device or stand accessory: microphone array, display, foot pedal, or haptic pitch feedback.
   - Awards fit: Red Dot, iF, James Dyson Award, maker competitions, CES student-facing opportunities.

6. Environmental/Acoustic Sensing Spin-Off
   - Use pitch/spectral algorithms for environmental sound monitoring, pollution-related acoustic proxies, or machine health monitoring.
   - Keep it as a sibling project, not part of the singing MVP.

MIT-facing principle: show deep technical maturity through one or two serious research outputs, plus several polished product demonstrations. Awards help, but advisor-quality research, evidence, and technical clarity matter more.

## Juilliard / Vocal Growth Strategy

Shenghai can also be your own deliberate-practice system:

- Track daily vocal range, pitch stability, breath phrases, and repertoire.
- Record short excerpts weekly; compare same phrase over months.
- Add diction/language notes for Italian, English, Japanese, and Mandarin repertoire.
- Build a "teacher mode" for comments, not just self-feedback.

For a ten-year Juilliard-style goal, the app should support musicality, not only pitch. Future modules should include phrasing, vowel consistency, diction, rhythm, and expressive intention.

## Immediate Next Builds

- Add Apple Pencil correction layer for iPad.
- Add score-aligned target pitch timeline.
- Add practice session recording and trend charts.
- Add accessibility pass: Dynamic Type, high contrast, non-color-only feedback, VoiceOver labels.
- Add screenshot/demo script for competition and awards pages.

## Goals Table Integration

Original Notion database: https://app.notion.com/p/377e40b960af802cb61af6d2c9a61cb4

This section folds the user's newly created Goals table into Shenghai's awards and portfolio strategy.

### 1. 大專校院資訊應用服務創新競賽

- Notion row: https://app.notion.com/p/377e40b960af80e6ae8cc08207054e2a
- Application Period: 8月3日開放報名10月5日
- Status: Not started
- Shenghai positioning: this is the direct summer MVP target. Present Shenghai as an AI / information service for music education and personal training, not just a technical demo.
- Evidence to prepare: working app, OMR/MusicXML import, part selection, MIDI/audio playback, live pitch tracking, practice logs, and 3-5 choir-member beta feedback notes.
- Suggested story: Shenghai lowers the barrier for choir self-practice by making intonation, memorization, and part practice measurable.

### 2. Apple's Swift Student Challenge

- Notion row: https://app.notion.com/p/377e40b960af811288fdfae24930d3fd
- Application Period: annually during a three-week window in February
- Status: Not started
- Type: Assumption
- Shenghai positioning: create a polished Shenghai Playground / Swift micro-demo around one complete interaction: load a short score, play the target pitch, sing, and see sharp/flat feedback.
- Evidence to prepare: Apple-native SwiftUI interaction, explainable pitch tracking, clear educational purpose, and no dependency on large backend systems or copyrighted score data.
- Suggested scope: do not submit the whole app. Cut one polished micro-experience that communicates the core breakthrough within minutes.

### 3. App Store Editor's Choice / Featuring

- Notion row: https://app.notion.com/p/377e40b960af80da8c6ffb39cf19f145
- Reference: https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/
- Status: Not started
- Shenghai positioning: this is not a normal competition. After launch, use App Store Connect nomination to pitch Shenghai for featuring.
- Evidence to prepare: App Store product page, demo video, high-quality screenshots, accessibility story, privacy story, and beta data from music learners.
- Suggested story: a practice studio for singers and choir members: import a score, choose your voice part, sing, and see where your intonation drifts.

### 4. Red Dot Award: Brands & Communication Design

- Notion row: https://app.notion.com/p/377e40b960af80afbe1bf2c3dc5682d0
- Application Period: earlybird: January-February; regular: February-April; latecomer: April-May
- Status: Not started
- Shenghai positioning: a pure app may fit brand/communication design, but Red Dot becomes stronger if Shenghai evolves into a complete app + hardware / practice kit product system.
- Evidence to prepare: brand identity, UI system, motion/demo, education scenario, hardware or service blueprint, user journey, and a coherent audio-visual feedback language.
- Suggested story: Shenghai turns abstract vocal training into a visible, reviewable, cumulative practice system.

### Roadmap Impact

- 2026 summer: prioritize 大專校院資訊應用服務創新競賽 with a beta-ready MVP.
- Before February 2027: prepare a Swift Student Challenge micro-demo, not the entire app.
- After App Store launch: prepare App Store featuring nomination with screenshots, story, beta data, accessibility, and privacy.
- Around spring 2027: for Red Dot / iF, add brand system and hardware/service concept before submitting.

## Sources

- Apple Newsroom, 2026 Apple Design Awards: https://www.apple.com/newsroom/2026/06/apple-reveals-winners-of-the-2026-apple-design-awards/
- Apple Developer, Apple Design Awards: https://developer.apple.com/design/awards/
- Apple Developer, Create ML: https://developer.apple.com/machine-learning/create-ml/
- MuseScore Handbook, Mixer: https://musescore.org/en/handbook/4/mixer
- MuseScore product description: https://new.musescore.org/en/handbook/musescore-product-description
- forScore Annotation guide: https://forscore.co/documentation/annotation/
- Nature Methods COMPACT paper: https://www.nature.com/articles/s41592-021-01230-3
- MIT Physics graduate admissions: https://physics.mit.edu/academic-programs/graduate-students/graduate-admissions/
- Juilliard College Voice requirements: https://www.juilliard.edu/arm/music/college/voice/bachelor-music
- Fast Company Innovation by Design: https://www.fastcompany.com/apply/innovation-by-design
- iF Design Award categories: https://ifdesign.com/en/if-design-award-and-jury
