# Neolyre / SOAR Application Demo Strategy

## Demo Link

Use this link after GitHub Pages has refreshed:

`https://chein-shawn.github.io/vocaldive/demo.html`

If GitHub Pages has not refreshed yet, use the GitHub repository link and mention that the demo page is under `docs/demo.html`.

## One-Sentence Positioning

VocalDive is a singing-practice system that uses the same score, alignment, F0, and acoustic-feature primitives needed by singing voice synthesis, but applies them to help human singers diagnose and improve their own voice.

## How Neolyre Connects to VocalDive

- SVS data pipelines teach VocalDive how to structure singing data: notes, lyrics or phonemes, durations, F0 curves, energy, breathiness, voicing, and tension.
- SVS acoustic models can generate clean reference vocals from MusicXML, useful when a chorus singer has no part-specific recording.
- SVS vocoders and acoustic-feature extraction can help VocalDive compare a learner's voice with a target, not only by pitch and rhythm but also by vocal quality.
- Technique-controllable SVS suggests future feedback categories such as falsetto, breathy tone, intensity, and mixed voice.

## What Not To Claim Yet

- Do not claim VocalDive already performs full YouTube audio downloading or modification.
- Do not claim a trained SVS model is integrated into the app.
- Do not imply that YouTube audio can be freely extracted; use official embeds, user recordings, or licensed/local audio.

## Suggested Paragraph Replacement

Recently I started a project called VocalDive, meaning "sea of voice" in Chinese. It is a prototype singing-practice system for beginners and chorus singers: it parses or creates MusicXML scores, turns the score into a target pitch/timing timeline, plays reference MIDI, and compares a user's singing against the target so that wrong pitch or rhythm can be highlighted. The current prototype is early, but I prepared a zero-install web demo here: https://chein-shawn.github.io/vocaldive/demo.html.

I see a strong technical connection between VocalDive and Neolyre. Modern singing voice synthesis needs score representations, alignment, F0 extraction, acoustic features, and vocoders; VocalDive needs many of the same components, but uses them in the reverse direction to analyze human singing and help users improve. By joining Neolyre, I hope to learn how modern open-source SVS systems structure data pipelines and acoustic models, then apply those ideas to build better reference voices, more precise pitch/timing feedback, and eventually technique-aware vocal training features in VocalDive.

## Demo Script For A Mentor

1. Open `demo.html`.
2. Click `Play target melody`.
3. Click `Play learner attempt`.
4. Show that the score marks pitch and timing problems.
5. Scroll to `Mini MusicXML composer`.
6. Add notes and show that VocalDive treats MusicXML as the bridge between score, audio, and model features.
