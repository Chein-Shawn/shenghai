# Third-Party Algorithm And License Audit

Date: 2026-06-06

## Summary

Current VocalDive code is mostly original Swift implementation plus standard Apple frameworks. The main legal risk is not the code currently in the repo; it is future integration with external score recognition, YouTube audio, pretrained models, SoundFonts, and commercial score/audio content.

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

YIN is an academic algorithm. Implementing the idea from the paper is generally different from copying code. Current VocalDive has its own Swift implementation, not a pasted third-party library.

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

## oemer / On-Device OMR Models

oemer is the current reference implementation for VocalDive's intended on-device OMR direction. The upstream repository is published with an MIT license, and the official checkpoint release provides ONNX assets for the first-stage and second-stage segmentation models.

Current audit result:

- code license: MIT in the upstream repository
- checked assets: `1st_model.onnx` and `2nd_model.onnx` from the upstream `checkpoints` release
- app status: no converted Core ML model is committed yet
- current risk: model-weight redistribution and App Store bundling should receive a final review before TestFlight/App Store distribution

Action before launch:

- Keep the upstream license text and asset provenance in release documentation.
- Do not commit or ship converted model files until the redistribution decision is explicit.
- If bundling the checkpoints is approved, record the exact SHA-256 of every shipped model artifact.
- If redistribution is not approved, replace oemer with a model whose code, weights, and training-data terms are all compatible with commercial distribution.

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

OpenSheetMusicDisplay is now the first bundled MusicXML rendering surface for VocalDive's editor path. It is used through a local `WKWebView` bundle, not a remote CDN.

Current integration intent:

- render imported or scanned MusicXML into a score view that is closer to formal engraving than the temporary native Swift summary staff
- keep editing logic, selection state, and score persistence in VocalDive's own Swift code
- vendor the minified renderer and carry its license text in the repo

Action before launch:

- keep the vendored `OSMD` files versioned and traceable
- preserve the BSD-3-Clause license text in the shipped source tree
- document upgrades when replacing the bundled renderer version
- avoid presenting OSMD output as if VocalDive authored that engraving engine

## MuseScore / forScore / Goodnotes / Notability UI References

It is fine to study product patterns, but do not copy visual designs, icons, layouts, or proprietary assets exactly.

Action before launch:

- Use original VocalDive visual identity.
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
