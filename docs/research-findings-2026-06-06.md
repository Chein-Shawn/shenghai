# Research Findings 2026-06-06

This file keeps the research backing for Shenghai's singing-practice MVP. A Google-Docs-ready version is stored in `docs/google-doc-research-tab-2026-06-06.md`.

## Product Thesis

Shenghai should not behave like a generic tuner. It should be a score-aware practice system:

```text
Score target -> user singing -> pitch contour -> smoothed deviation -> phrase-level practice record
```

## Research-Backed Decisions

1. Visual feedback is pedagogically plausible because the voice is hard to inspect directly.
2. Practice logs matter as much as instant correction; longitudinal progress is part of the value.
3. Melody/phrase feedback matters more than single-note feedback for realistic singing practice.
4. Singing F0 tracking needs confidence and smoothing because no real-time detector is perfect.
5. The app should keep pitch-tracking algorithms swappable.
6. Datasets such as VocalSet can be used for regression testing across voice types, vowels, and techniques.

## Implementation Impact

- Add core abstractions:
  - `PitchTracker`
  - `PitchContourSmoother`
  - `PitchDeviationAnalyzer`
  - `PracticeScorer`
- Extend `ScoreDocument` later with:
  - `practiceSessions`
  - `pitchSamples`
  - `confidence`
  - `targetPartID`
  - `phraseRange`
- Build evaluation scripts before committing to one pitch algorithm.

## References

- Lã and Fiuza, 2022, Real-Time Visual Feedback in Singing Pedagogy: https://www.mdpi.com/2076-3417/12/21/10781
- Paney and Tharp, 2021, The effect of concurrent visual feedback on adult singing accuracy: https://journals.sagepub.com/doi/abs/10.1177/0305735619854534
- Berglin, Pfordresher, and Demorest, 2022, The effect of visual and auditory feedback on adult poor-pitch remediation: https://journals.sagepub.com/doi/abs/10.1177/03057356211026730
- Kim et al., 2018, CREPE: https://arxiv.org/abs/1802.06182
- Babacan et al., 2019, Comparative pitch extraction study: https://arxiv.org/abs/1912.12609
- Faghih and Timoney, 2022, Real-time monophonic singing pitch detection: https://www.researchgate.net/publication/361909956_Real-time_monophonic_singing_pitch_detection
- Basic Pitch, Spotify Engineering, 2022: https://engineering.atspotify.com/2022/06/meet-basic-pitch
- Onsets and Frames, Google Research, 2018: https://research.google/pubs/onsets-and-frames-dual-objective-piano-transcription/
- VocalSet, Wilkins et al., 2018: https://zenodo.org/record/1492452
- Piao and Xia, 2022, Sensing the Breath: https://arxiv.org/abs/2202.01439
