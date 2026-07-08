# Practice Tools Implementation

Date: 2026-06-06

## Summary

Added three core rehearsal utilities to the VocalDive practice view:

- Metronome
- Piano reference keys
- Tuning fork / sustained reference tone

These tools live beside live pitch tracking so singers can hear a reference, sing back, and immediately compare their pitch.

## Implemented UI

In `PracticeView.swift`:

- The center practice stage now includes a Piano panel.
- The right inspector now includes:
  - Target reference playback
  - Metronome panel
  - Tuning fork panel

## Implemented Audio

The MVP uses `AVAudioEngine` and two `AVAudioPlayerNode` instances:

- `transientPlayer`: short sounds such as piano notes, reference tones, and metronome clicks.
- `dronePlayer`: looping sustained tone for the tuning fork.

Generated tones are sine-wave `AVAudioPCMBuffer` objects with short attack/release envelopes to avoid clicks.

## Current Behavior

### Metronome

- BPM stepper, default 72 bpm.
- Meter picker: 2/4, 3/4, 4/4, 6/8.
- Accent click on beat 1.
- Beat display.

### Piano

- One-octave practice keyboard from C4 to C5, including accidentals.
- Tapping a key:
  - plays the pitch,
  - sets the current target pitch for live pitch practice.

### Tuning Fork

- Reference tones: C4, G4, A4, C5.
- Sustained looping tone.
- Also supports playing the current target pitch as a short reference.

## Limitations

- The piano is sine-wave only, not sampled piano.
- The metronome does not yet sync to MIDI playback or score position.
- The tuning fork is a plain sustained tone, not yet a richer synthesized timbre.
- No user settings persistence yet.

## Next Steps

- Persist BPM, meter, and preferred tuning pitch.
- Add haptic metronome on iPhone/Apple Watch later.
- Sync metronome to score tempo and playback position.
- Replace sine piano with a lightweight sampler or SF2 sound bank if needed.
- Add pitch-relative controls such as "play selected measure target line".
