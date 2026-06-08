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
                    title: "Experimental",
                    subtitle: "Research-backed, unusual singing features",
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
        StudioPanel(title: "Safety Boundary", systemImage: "exclamationmark.shield") {
            VStack(alignment: .leading, spacing: 10) {
                Text(feature.safetyNotice)
                    .font(.headline)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(feature.notIntendedUse, id: \.self) { item in
                        Label(item, systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var featureSummary: some View {
        StudioPanel(title: feature.title, systemImage: "person.wave.2") {
            VStack(alignment: .leading, spacing: 12) {
                Text(feature.subtitle)
                    .foregroundStyle(.secondary)

                HStack {
                    ValuePill(title: "Status", value: feature.status.rawValue, systemImage: "flask")
                    ValuePill(title: "Protocol", value: sessionPlan.protocolName, systemImage: "list.bullet.clipboard")
                    ValuePill(title: "Length", value: "\(Int(sessionPlan.estimatedDurationSeconds / 60)) min", systemImage: "timer")
                }

                SectionTitle("Intended use")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(feature.intendedUse, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var protocolPanel: some View {
        StudioPanel(title: "Gentle Call-and-Response", systemImage: "waveform.and.person.filled") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(feature.protocolSteps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.tint, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.headline)
                            Text(step.instruction)
                                .foregroundStyle(.secondary)
                            if let targetMetric = step.targetMetric {
                                Text("Metric: \(targetMetric)")
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
        StudioPanel(title: "Tracked Metrics", systemImage: "chart.line.uptrend.xyaxis") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10)], spacing: 10) {
                ForEach(feature.trackedMetrics, id: \.self) { metric in
                    Text(metric)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .padding(.horizontal, 10)
                        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var alarmPanel: some View {
        StudioPanel(title: alarmFeature.title, systemImage: "alarm") {
            VStack(alignment: .leading, spacing: 14) {
                Text(alarmFeature.subtitle)
                    .foregroundStyle(.secondary)

                Text(alarmFeature.safetyNotice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: "Demo song", value: alarmPlan.songTitle, systemImage: "music.note")
                    ValuePill(title: "Wake time", value: formattedWakeTime, systemImage: "clock")
                    ValuePill(title: "Coverage", value: "\(Int(alarmPlan.challengeTargetCoverageRatio * 100))%", systemImage: "checklist")
                    ValuePill(title: "Pitch target", value: "\(Int(alarmPlan.requiredInTuneRatio * 100))%", systemImage: "waveform.path.ecg")
                }

                SectionTitle("How dismissal works")
                Text(alarmPlan.dismissalPolicy)
                    .foregroundStyle(.secondary)

                SectionTitle("Platform boundary")
                Text(alarmPlan.platformLimitation)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(alarmFeature.notIntendedUse, id: \.self) { item in
                        Label(item, systemImage: "xmark.shield")
                            .foregroundStyle(.secondary)
                    }
                }

                SectionTitle("Prototype flow")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(alarmFeature.protocolSteps) { step in
                        Label(step.title, systemImage: "checkmark.circle")
                            .font(.subheadline.weight(.semibold))
                        Text(step.instruction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 26)
                    }
                }
            }
        }
    }

    private var textRhythmPanel: some View {
        StudioPanel(title: textRhythmFeature.title, systemImage: "text.quote") {
            VStack(alignment: .leading, spacing: 14) {
                Text(textRhythmFeature.subtitle)
                    .foregroundStyle(.secondary)

                Text(textRhythmFeature.safetyNotice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: "Category", value: textRhythmPlan.prompt.category.displayName, systemImage: "tray.full")
                    ValuePill(title: "Tempo", value: "\(textRhythmPlan.tempoBPM) bpm", systemImage: "metronome")
                    ValuePill(title: "Language", value: textRhythmPlan.languageMode.displayName, systemImage: "globe")
                    ValuePill(title: "Phrases", value: "\(textRhythmPlan.phrases.count)", systemImage: "textformat")
                    ValuePill(title: "Guide", value: textRhythmPlan.rhythmEnabled ? "On" : "Off", systemImage: "waveform")
                }

                SectionTitle("Sample prompt")
                Text(textRhythmPlan.prompt.text)
                    .font(.body.weight(.medium))
                Text(textRhythmPlan.prompt.rightsNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SectionTitle("Segmentation")
                Text("v1 uses \(textRhythmPlan.phraseBoundaryStrategy.displayName.lowercased()) to split bilingual text into phrase units. English keeps word-level cue timing inside each phrase; Chinese and mixed phrases stay phrase-based.")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(textRhythmPlan.phrases) { phrase in
                        HStack(alignment: .top, spacing: 10) {
                            Text(phrase.language.displayName)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phrase.text)
                                    .font(.subheadline.weight(.semibold))
                                Text("Cue span: \(phrase.startCueIndex + 1)-\(phrase.startCueIndex + phrase.cueCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                SectionTitle("Practice metrics")
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ValuePill(title: "Clarity", value: "\(Int(textRhythmEvaluation.clarityScore * 100))%", systemImage: "waveform")
                    ValuePill(title: "Rate", value: "\(Int(textRhythmEvaluation.rateScore * 100))%", systemImage: "speedometer")
                    ValuePill(title: "Rhythm", value: "\(Int(textRhythmEvaluation.rhythmScore * 100))%", systemImage: "metronome")
                    ValuePill(title: "Completion", value: "\(Int(textRhythmEvaluation.completionScore * 100))%", systemImage: "checkmark.circle")
                    ValuePill(title: "Phrase match", value: "\(Int(textRhythmEvaluation.phraseMatchScore * 100))%", systemImage: "text.quote")
                    ValuePill(title: "Phrases/min", value: String(format: "%.1f", textRhythmEvaluation.phrasesPerMinute), systemImage: "timer")
                }

                if let wordsPerMinute = textRhythmEvaluation.wordsPerMinute {
                    Text("English-only sessions can also report words/min: \(String(format: "%.1f", wordsPerMinute)).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                SectionTitle("Boundary")
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(textRhythmFeature.notIntendedUse, id: \.self) { item in
                        Label(item, systemImage: "xmark.circle")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var evidencePanel: some View {
        StudioPanel(title: "Evidence Notes", systemImage: "books.vertical") {
            VStack(alignment: .leading, spacing: 10) {
                Text("The evidence is mixed and condition-specific. Shenghai uses this section for cautious prototypes, not medical claims.")
                    .foregroundStyle(.secondary)

                ForEach(ExperimentalFeatureCatalog.all.flatMap(\.evidenceReferences)) { reference in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reference.title)
                            .font(.headline)
                        Text(reference.domain.displayName)
                            .font(.caption)
                            .foregroundStyle(.tint)
                        Text(reference.finding)
                            .foregroundStyle(.secondary)
                        Text("App use: \(reference.appUse)")
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

#Preview {
    ExperimentalFeaturesView()
}
