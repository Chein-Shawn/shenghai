import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ExperimentalFeaturesView: View {
    private let feature = ExperimentalFeatureCatalog.singingSupportLab
    private let sessionPlan = ExperimentalFeatureCatalog.makeSingingSupportSessionPlan()
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
                    subtitle: L10n.tr("Research-backed, unusual singing features"),
                    systemImage: "testtube.2"
                )

                safetyPanel
                featureSummary
                protocolPanel
                metricPanel
                alarmPanel
                textRhythmPanel
                evidencePanel
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var safetyPanel: some View {
        StudioPanel(title: L10n.tr("Safety Boundary"), systemImage: "exclamationmark.shield") {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr(feature.safetyNotice))
                    .font(.headline)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(feature.notIntendedUse, id: \.self) { item in
                        Label(L10n.tr(item), systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var featureSummary: some View {
        StudioPanel(title: L10n.tr(feature.title), systemImage: "person.wave.2") {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr(feature.subtitle))
                    .foregroundStyle(.secondary)

                HStack {
                    ValuePill(title: L10n.tr("Status"), value: L10n.tr(feature.status.rawValue), systemImage: "flask")
                    ValuePill(title: L10n.tr("Protocol"), value: L10n.tr(sessionPlan.protocolName), systemImage: "list.bullet.clipboard")
                    ValuePill(title: L10n.tr("Length"), value: L10n.tr("%d min", Int(sessionPlan.estimatedDurationSeconds / 60)), systemImage: "timer")
                }

                SectionTitle(L10n.tr("Intended use"))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(feature.intendedUse, id: \.self) { item in
                        Label(L10n.tr(item), systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var protocolPanel: some View {
        StudioPanel(title: L10n.tr("Gentle Call-and-Response"), systemImage: "waveform.and.person.filled") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(feature.protocolSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.tint, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.tr(step.title))
                                .font(.headline)
                            Text(L10n.tr(step.instruction))
                                .foregroundStyle(.secondary)
                            if let targetMetric = step.targetMetric {
                                Text(L10n.tr("Metric: %@", targetMetric))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var metricPanel: some View {
        StudioPanel(title: L10n.tr("Tracked Metrics"), systemImage: "chart.line.uptrend.xyaxis") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(feature.trackedMetrics, id: \.self) { metric in
                    Text(L10n.tr(metric))
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 10)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var alarmPanel: some View {
        StudioPanel(title: L10n.tr(alarmFeature.title), systemImage: "alarm") {
            VStack(alignment: .leading, spacing: 14) {
                Text(L10n.tr(alarmFeature.subtitle))
                    .foregroundStyle(.secondary)

                Text(L10n.tr(alarmFeature.safetyNotice))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

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

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(alarmFeature.notIntendedUse, id: \.self) { item in
                        Label(L10n.tr(item), systemImage: "xmark.shield")
                            .foregroundStyle(.secondary)
                    }
                }

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

                Text(L10n.tr(textRhythmFeature.safetyNotice))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

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

                SectionTitle(L10n.tr("Boundary"))
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(textRhythmFeature.notIntendedUse, id: \.self) { item in
                        Label(L10n.tr(item), systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var evidencePanel: some View {
        StudioPanel(title: L10n.tr("Evidence Notes"), systemImage: "books.vertical") {
            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.tr("The evidence is mixed and condition-specific. Shenghai uses this section for cautious prototypes, not medical claims."))
                    .foregroundStyle(.secondary)

                ForEach(ExperimentalFeatureCatalog.all.flatMap(\.evidenceReferences)) { reference in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reference.title)
                            .font(.headline)
                        Text(L10n.tr(reference.domain.displayName))
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(L10n.tr(reference.finding))
                            .foregroundStyle(.secondary)
                        Text(L10n.tr("App use: %@", L10n.tr(reference.appUse)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
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
