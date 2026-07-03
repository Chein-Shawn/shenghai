# Third-Party Algorithm And License Audit

Date: 2026-06-06

## Summary

Current Shenghai code is mostly original Swift implementation plus standard Apple frameworks. The main legal risk is not the code currently in the repo; it is future integration with external score recognition, YouTube audio, pretrained models, SoundFonts, and commercial score/audio content.

## Current Code / Algorithm Status

| Area | Current status | Risk |
| --- | --- | --- |
| MusicXML parser | Original prototype parser using standard XML APIs | Low |
| ScoreDocument | Original internal data model | Low |
| MIDI writer | Original implementation based on MIDI file format concepts | Low |
| YIN pitch tracker | Original implementation of a known published algorithm idea | Medium-low |
| Pitch deviation | Original math using cents difference | Low |
| Score/audio alignment | Original baseline implementation | Low |
| Usage analytics ledger | Original local data model | Low |
| SwiftUI app | Original UI code using Apple frameworks | Low |
| AVFoundation / SwiftUI / Observation | Apple SDKs | Low if used under Apple Developer terms |
| OSMD score renderer | Bundled third-party renderer under BSD-3-Clause | Low with attribution and vendored-license tracking |

## YIN Pitch Tracking

YIN is an academic algorithm. Implementing the idea from the paper is generally different from copying code. Current Shenghai has its own Swift implementation, not a pasted third-party library.

Action before launch:

- Cite the YIN paper in research documentation.
- Keep implementation original.
- Do not copy GPL or incompatible source code.

## Audiveris / OMR

Audiveris is useful for research and preprocessing. It should not be silently embedded into the iOS/macOS app without a license review.

Action before launch:

- Confirm Audiveris license and dependency licenses.
- Keep Audiveris as a development/server preprocessing option unless the license and platform fit are clear.
- Let the app import MusicXML as the main safe path.

## YouTube

Do not implement automatic YouTube MP3 downloading, stream separation, or modification. Use YouTube links only as reference metadata or official-player usage where permitted.

Action before launch:

- Avoid shipping any YouTube downloader.
- Do not market YouTube audio modification.
- Use local audio, user recordings, or licensed tracks for alignment and correction.

## MusicXML / SMuFL / MIDI

MusicXML, SMuFL, and MIDI are standard formats. Using the formats is not the same as copying a proprietary implementation.

Action before launch:

- Mention MusicXML compatibility.
- Avoid implying endorsement by W3C, MuseScore, or other projects.
- Keep exported files compliant with format expectations.

## OSMD

OpenSheetMusicDisplay is now the first bundled MusicXML rendering surface for Shenghai's editor path. It is used through a local `WKWebView` bundle, not a remote CDN.

Current integration intent:

- render imported or scanned MusicXML into a score view that is closer to formal engraving than the temporary native Swift summary staff
- keep editing logic, selection state, and score persistence in Shenghai's own Swift code
- vendor the minified renderer and carry its license text in the repo

Action before launch:

- keep the vendored `OSMD` files versioned and traceable
- preserve the BSD-3-Clause license text in the shipped source tree
- document upgrades when replacing the bundled renderer version
- avoid presenting OSMD output as if Shenghai authored that engraving engine

## MuseScore / forScore / Goodnotes / Notability UI References

It is fine to study product patterns, but do not copy visual designs, icons, layouts, or proprietary assets exactly.

Action before launch:

- Use original Shenghai visual identity.
- Use Apple SF Symbols and system UI patterns.
- Cite products as competitive inspiration in internal docs, not as copied design sources.

## SoundFonts And Audio Samples

MIDI playback often needs an instrument sound source. SoundFonts can have licenses.

Action before launch:

- Use Apple-provided instruments or clearly licensed SoundFonts.
- Track license text for any included audio assets.
- Do not bundle commercial rehearsal tracks without permission.

## Machine Learning Models

CREPE, Basic Pitch, Onsets and Frames, or other pretrained models may have specific model and code licenses.

Action before launch:

- Review license before adding any pretrained model.
- Record model provenance, training data caveats, and allowed commercial use.
- Prefer optional research experiments until legal fit is clear.

## Launch Checklist

- Add `NOTICE.md` if third-party code or assets are included.
- Add license list to support site if needed.
- Keep GitHub repo private until competition/IP strategy is decided.
- Do not include copyrighted scores or audio in sample data.
- Use public-domain or original sample scores for demos.
