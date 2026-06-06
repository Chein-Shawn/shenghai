import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct PracticeView: View {
    @Bindable var workspace: ShenghaiWorkspace

    private let analyzer = PitchDeviationAnalyzer()

    private var mockDeviations: [PitchDeviation] {
        let target = TargetPitchPoint(time: 0, midi: 60)
        let samples = [
            PitchSample(time: 0.0, frequencyHz: 261.63, confidence: 0.92),
            PitchSample(time: 0.5, frequencyHz: 255.0, confidence: 0.86),
            PitchSample(time: 1.0, frequencyHz: 270.0, confidence: 0.89),
            PitchSample(time: 1.5, frequencyHz: nil, confidence: 0.18)
        ]
        return analyzer.analyze(sung: samples, against: [target])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Practice Lab",
                    subtitle: "Pitch feedback model preview",
                    systemImage: "waveform.and.mic"
                )

                StatusStrip(workspace: workspace)

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Pitch Feedback States")
                    ForEach(Array(mockDeviations.enumerated()), id: \.offset) { _, deviation in
                        PitchDeviationRow(deviation: deviation)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Next Build Items")
                    PipelineRow(title: "Microphone permission and live capture", state: .planned)
                    PipelineRow(title: "Replaceable pitch tracker adapter", state: .planned)
                    PipelineRow(title: "Score-aligned target pitch timeline", state: .planned)
                    PipelineRow(title: "Red mark overlay on score view", state: .planned)
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct PitchDeviationRow: View {
    var deviation: PitchDeviation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        switch deviation.quality {
        case .inTune:
            return "In tune"
        case .sharp:
            return "Sharp"
        case .flat:
            return "Flat"
        case .lowConfidence:
            return "Low confidence"
        case .missingTarget:
            return "Missing target"
        }
    }

    private var detail: String {
        if let cents = deviation.cents {
            return String(format: "%.1f cents, confidence %.2f", cents, deviation.confidence)
        }
        return String(format: "confidence %.2f", deviation.confidence)
    }

    private var iconName: String {
        switch deviation.quality {
        case .inTune:
            return "checkmark.circle.fill"
        case .sharp:
            return "arrow.up.circle.fill"
        case .flat:
            return "arrow.down.circle.fill"
        case .lowConfidence:
            return "exclamationmark.triangle.fill"
        case .missingTarget:
            return "questionmark.circle.fill"
        }
    }

    private var color: Color {
        switch deviation.quality {
        case .inTune:
            return .green
        case .sharp, .flat:
            return .red
        case .lowConfidence, .missingTarget:
            return .orange
        }
    }
}
