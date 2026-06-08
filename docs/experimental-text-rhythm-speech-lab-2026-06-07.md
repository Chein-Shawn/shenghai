# Experimental Text Rhythm Speech Lab

## Goal
Let users import public-domain, licensed, or user-owned paragraphs and turn them into rhythm-guided speech or chanting practice.

The feature is designed for practice tracking, not medical claims. It can help users compare guided and unguided attempts, but it must not say that a user is cured.

## User flow
1. User imports or selects a legal text prompt.
2. User chooses a category and a paragraph that may be English, Chinese, or mixed Chinese/English.
3. Shenghai splits the text into phrases using punctuation and line breaks.
4. Shenghai generates rhythm cues phrase by phrase.
5. User practices with the rhythm guide on.
6. User turns the rhythm guide off and repeats the paragraph.
7. Shenghai compares the attempts across clarity, rate, rhythm alignment, phrase match, and completion.

## Metrics
- `clarityScore`: proxy based on expected cue text matching the spoken/sung result.
- `phrasesPerMinute`: speaking or singing rate for phrase-based sessions.
- `wordsPerMinute`: retained only for English-only sessions.
- `rateScore`: score against a comfortable target rate range.
- `rhythmAlignment`: timing closeness to the generated beat guide.
- `phraseMatchScore`: whether each expected phrase was reproduced correctly.
- `completionScore`: how much of the paragraph was attempted.
- `guideOffTransfer`: whether performance stays stable after turning off the guide.

## Language and segmentation
- English-only paragraphs can still use word-oriented cue timing inside each phrase.
- Chinese paragraphs use phrase-based scoring rather than whitespace splitting.
- Mixed bilingual paragraphs are supported in a single session.
- v1 phrase boundaries come from punctuation and line breaks, not AI linguistic parsing.

## Copyright and text rights
Do not import copyrighted articles, books, lyrics, news text, or poems unless the user owns the text or has permission.

Good first sources:
- Original Shenghai sample text.
- User-written paragraphs.
- Public-domain text.
- Explicitly licensed educational text.

## Clinical and product boundary
This feature is not a cure, diagnosis, medical device, or replacement for a speech-language pathologist, music therapist, physician, psychologist, occupational therapist, or other professional care.

The correct product language is:
- "practice support"
- "speech rhythm practice"
- "clarity/rate/rhythm/phrase tracking"
- "guided vs unguided comparison"

Avoid:
- "cured"
- "treats autism"
- "diagnoses speech disorder"
- "medical improvement score"
- "therapy replacement"

## Research basis
- Melodic Intonation Therapy research studies rhythm, intonation, and formulaic language in aphasia rehabilitation, but generalization should be interpreted cautiously.
- Entrainment research suggests external rhythm can coordinate timing in some disordered-speech tasks.
- Speech intelligibility research connects temporal speech-envelope tracking to perception, but this does not make app metrics diagnostic.

## Implementation
- Core model: `TextRhythmPrompt`
- Language/segmentation metadata: `TextLanguageMode`, `TextSegmentationMode`, `PhraseBoundaryStrategy`
- Phrase abstraction: `TextRhythmPhrase`
- Rhythm guide: `RhythmCue`
- Practice plan: `TextRhythmSpeechPlan`
- Spoken input abstraction: `SpokenToken`
- Evaluator: `TextRhythmSpeechEvaluator`
- Catalog entry: `ExperimentalFeatureCatalog.textRhythmSpeechLab`

## Next implementation steps
1. Add a text import/editor screen.
2. Add public-domain sample prompt library.
3. Add speech recognition with word timestamps where platform support allows.
4. Add rhythm audio clicks or soft chant guide.
5. Add guided/unguided comparison charts.
6. Add trend history by prompt category.
