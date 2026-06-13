import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ExperimentalFeaturesView: View {
    private let alarmFeature = ExperimentalFeatureCatalog.singToDismissAlarm
    private let alarmPlan = ExperimentalFeatureCatalog.makeSingToDismissAlarmPlan()
    private let textRhythmFeature = ExperimentalFeatureCatalog.textRhythmSpeechLab
    private let textRhythmPlan = ExperimentalFeatureCatalog.makeTextRhythmSpeechPlan()
    private let textRhythmEvaluation = TextRhythmSpeechEvaluator().evaluate(
        spokenTokens: ExperimentalFeatureCatalog.makeTextRhythmSpeechPlan().cues.map { cue in
            SpokenToken(
                token: cue.token,
                startTime: cue.startTime + 0.02,
                duration: cue.duration * 0.72,
                confidence: 0.9
            )
        },
        against: ExperimentalFeatureCatalog.makeTextRhythmSpeechPlan()
    )

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: L10n.tr("Experimental"),
                    subtitle: L10n.tr("Experimental features that are still being tested"),
                    systemImage: "testtube.2"
                )

                alarmPanel
                textRhythmPanel
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var alarmPanel: some View {
        StudioPanel(title: L10n.tr(alarmFeature.title), systemImage: "alarm") {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(alarmFeature.subtitle))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: L10n.tr("Demo song"), value: alarmPlan.songTitle, systemImage: "music.note")
                    ValuePill(title: L10n.tr("Wake time"), value: formattedWakeTime, systemImage: "clock")
                    ValuePill(title: L10n.tr("Coverage"), value: "\(Int(alarmPlan.challengeTargetCoverageRatio * 100))%", systemImage: "checklist")
                    ValuePill(title: L10n.tr("Pitch target"), value: "\(Int(alarmPlan.requiredInTuneRatio * 100))%", systemImage: "waveform.path.ecg")
                }

                SectionTitle(L10n.tr("How dismissal works"))
                Text(L10n.tr(alarmPlan.dismissalPolicy))
                    .foregroundStyle(.secondary)

                SectionTitle(L10n.tr("Platform boundary"))
                Text(L10n.tr(alarmPlan.platformLimitation))
                    .foregroundStyle(.secondary)

                SectionTitle(L10n.tr("Prototype flow"))
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(alarmFeature.protocolSteps) { step in
                        Label(L10n.tr(step.title), systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.tr(step.instruction))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 26)
                    }
                }
            }
        }
    }

    private var textRhythmPanel: some View {
        StudioPanel(title: L10n.tr(textRhythmFeature.title), systemImage: "text.quote") {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(textRhythmFeature.subtitle))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: L10n.tr("Category"), value: L10n.tr(textRhythmPlan.prompt.category.displayName), systemImage: "tray.full")
                    ValuePill(title: L10n.tr("Tempo"), value: "\(textRhythmPlan.tempoBPM) bpm", systemImage: "metronome")
                    ValuePill(title: L10n.tr("Language"), value: L10n.tr(textRhythmPlan.languageMode.displayName), systemImage: "globe")
                    ValuePill(title: L10n.tr("Phrases"), value: "\(textRhythmPlan.phrases.count)", systemImage: "textformat")
                    ValuePill(title: L10n.tr("Guide"), value: textRhythmPlan.rhythmEnabled ? L10n.tr("On") : L10n.tr("Off"), systemImage: "waveform")
                }

                SectionTitle(L10n.tr("Sample prompt"))
                Text(textRhythmPlan.prompt.text)
                    .font(.body.weight(.medium))
                Text(L10n.tr(textRhythmPlan.prompt.rightsNote))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SectionTitle(L10n.tr("Segmentation"))
                Text(L10n.tr("v1 uses %@ to split bilingual text into phrase units. English keeps word-level cue timing inside each phrase; Chinese and mixed phrases stay phrase-based.", L10n.tr(textRhythmPlan.phraseBoundaryStrategy.displayName).lowercased()))
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(textRhythmPlan.phrases) { phrase in
                        HStack(alignment: .top, spacing: 10) {
                            Text(L10n.tr(phrase.language.displayName))
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phrase.text)
                                    .font(.subheadline.weight(.semibold))
                                Text(L10n.tr("Cue span: %d-%d", phrase.startCueIndex + 1, phrase.startCueIndex + phrase.cueCount))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SectionTitle(L10n.tr("Practice metrics"))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: L10n.tr("Clarity"), value: "\(Int(textRhythmEvaluation.clarityScore * 100))%", systemImage: "waveform")
                    ValuePill(title: L10n.tr("Rate"), value: "\(Int(textRhythmEvaluation.rateScore * 100))%", systemImage: "speedometer")
                    ValuePill(title: L10n.tr("Rhythm"), value: "\(Int(textRhythmEvaluation.rhythmScore * 100))%", systemImage: "metronome")
                    ValuePill(title: L10n.tr("Completion"), value: "\(Int(textRhythmEvaluation.completionScore * 100))%", systemImage: "checkmark.circle")
                    ValuePill(title: L10n.tr("Phrase match"), value: "\(Int(textRhythmEvaluation.phraseMatchScore * 100))%", systemImage: "text.quote")
                    ValuePill(title: L10n.tr("Phrases/min"), value: String(format: "%.1f", textRhythmEvaluation.phrasesPerMinute), systemImage: "timer")
                }

                if let wordsPerMinute = textRhythmEvaluation.wordsPerMinute {
                    Text(L10n.tr("English-only sessions can also report words/min: %@.", String(format: "%.1f", wordsPerMinute)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var formattedWakeTime: String {
        String(format: "%02d:%02d", alarmPlan.scheduledHour, alarmPlan.scheduledMinute)
    }
}

struct ExperimentalFeaturesView_Previews: PreviewProvider {
    static var previews: some View {
        ExperimentalFeaturesView()
    }
}
