import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct PracticeView: View {
    @Bindable var workspace: ShenghaiWorkspace
    @State private var livePitchCapture = LivePitchCaptureService()
    @State private var selectedMode: PracticeMode = .scoreReading
    @State private var targetPitch: Double = 261.63

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
        GeometryReader { proxy in
            if proxy.size.width >= 980 {
                HStack(alignment: .top, spacing: 0) {
                    PracticeModeRail(selectedMode: $selectedMode)
                        .frame(width: 230)
                        .padding()

                    Divider()

                    PracticeStage(
                        workspace: workspace,
                        selectedMode: selectedMode,
                        livePitchCapture: livePitchCapture,
                        targetPitch: $targetPitch
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    PracticeInspector(
                        workspace: workspace,
                        livePitchCapture: livePitchCapture,
                        targetPitch: $targetPitch,
                        mockDeviations: mockDeviations
                    )
                    .frame(width: 320)
                    .padding()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PracticeModeRail(selectedMode: $selectedMode)
                        PracticeStage(
                            workspace: workspace,
                            selectedMode: selectedMode,
                            livePitchCapture: livePitchCapture,
                            targetPitch: $targetPitch
                        )
                        PracticeInspector(
                            workspace: workspace,
                            livePitchCapture: livePitchCapture,
                            targetPitch: $targetPitch,
                            mockDeviations: mockDeviations
                        )
                    }
                    .padding()
                }
            }
        }
    }
}

private enum PracticeMode: String, CaseIterable, Identifiable {
    case scoreReading = "Score"
    case memorization = "Memory"
    case pitchDrill = "Pitch"
    case commuteReview = "Review"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .scoreReading:
            return "book.pages"
        case .memorization:
            return "eye.slash"
        case .pitchDrill:
            return "scope"
        case .commuteReview:
            return "tram"
        }
    }

    var caption: String {
        switch self {
        case .scoreReading:
            return "follow score"
        case .memorization:
            return "hide cues"
        case .pitchDrill:
            return "intonation"
        case .commuteReview:
            return "offline pass"
        }
    }
}

private struct PracticeModeRail: View {
    @Binding var selectedMode: PracticeMode

    var body: some View {
        StudioPanel(title: "Modes", systemImage: "rectangle.grid.1x2") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.systemImage)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(mode.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text(mode.caption)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(selectedMode == mode ? Color.accentColor.opacity(0.14) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct PracticeStage: View {
    @Bindable var workspace: ShenghaiWorkspace
    var selectedMode: PracticeMode
    @Bindable var livePitchCapture: LivePitchCaptureService
    @Binding var targetPitch: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.scoreSummary.title)
                            .font(.title2.bold())
                        Text(selectedMode.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if livePitchCapture.isRunning {
                            livePitchCapture.stop()
                        } else {
                            livePitchCapture.start()
                        }
                    } label: {
                        Label(livePitchCapture.isRunning ? "Stop" : "Start", systemImage: livePitchCapture.isRunning ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                TargetPitchCanvas(livePitchCapture: livePitchCapture, targetPitch: targetPitch)

                if selectedMode == .memorization {
                    MemoryCueStrip()
                } else if selectedMode == .pitchDrill {
                    PitchDrillStrip(targetPitch: $targetPitch)
                }

                if let part = workspace.selectedPart {
                    PracticeMeasureList(part: part)
                }
            }
            .padding(24)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .background(.quaternary.opacity(0.16))
    }
}

private struct PracticeInspector: View {
    @Bindable var workspace: ShenghaiWorkspace
    @Bindable var livePitchCapture: LivePitchCaptureService
    @Binding var targetPitch: Double
    var mockDeviations: [PitchDeviation]

    var body: some View {
        VStack(spacing: 14) {
            LivePitchPanel(livePitchCapture: livePitchCapture)

            StudioPanel(title: "Target", systemImage: "target") {
                VStack(alignment: .leading, spacing: 10) {
                    ValuePill(title: "Reference", value: String(format: "%.1f Hz", targetPitch), systemImage: "waveform")
                    Slider(value: $targetPitch, in: 196...523.25, step: 0.1)
                }
            }

            StudioPanel(title: "Pitch States", systemImage: "chart.xyaxis.line") {
                ForEach(Array(mockDeviations.enumerated()), id: \.offset) { _, deviation in
                    PitchDeviationRow(deviation: deviation)
                }
            }

            StudioPanel(title: "Build Queue", systemImage: "hammer") {
                PipelineRow(title: "Microphone capture", state: .ready)
                PipelineRow(title: "YIN tracker adapter", state: .ready)
                PipelineRow(title: "Score-aligned target timeline", state: .planned)
                PipelineRow(title: "Red mark overlay", state: .planned)
            }
        }
    }
}

private struct LivePitchPanel: View {
    @Bindable var livePitchCapture: LivePitchCaptureService

    var body: some View {
        StudioPanel(title: "Live Pitch", systemImage: "waveform.and.mic") {
            HStack {
                if let latestSample = livePitchCapture.latestSample {
                    MetricTile(
                        title: "Frequency",
                        value: latestSample.frequencyHz.map { String(format: "%.1f Hz", $0) } ?? "No pitch",
                        systemImage: "waveform"
                    )
                    MetricTile(
                        title: "Confidence",
                        value: String(format: "%.2f", latestSample.confidence),
                        systemImage: "checkmark.seal"
                    )
                } else {
                    Text(livePitchCapture.isRunning ? "Listening..." : "Mic idle")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if let errorMessage = livePitchCapture.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

private struct TargetPitchCanvas: View {
    @Bindable var livePitchCapture: LivePitchCaptureService
    var targetPitch: Double

    private var latestFrequency: Double? {
        livePitchCapture.latestSample?.frequencyHz
    }

    var body: some View {
        StudioPanel(title: "Intonation Trace", systemImage: "waveform.path.ecg") {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(.quaternary.opacity(0.22))
                    Path { path in
                        let midY = proxy.size.height * 0.5
                        path.move(to: CGPoint(x: 0, y: midY))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: midY))
                    }
                    .stroke(.green, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))

                    if let latestFrequency {
                        Circle()
                            .fill(abs(latestFrequency - targetPitch) < 3 ? .green : .red)
                            .frame(width: 24, height: 24)
                            .position(
                                x: proxy.size.width * 0.74,
                                y: yPosition(frequency: latestFrequency, height: proxy.size.height)
                            )
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Text("flat")
                            Spacer()
                            Text("target")
                            Spacer()
                            Text("sharp")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(8)
                    }
                }
            }
            .frame(height: 210)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func yPosition(frequency: Double, height: CGFloat) -> CGFloat {
        let ratio = log2(max(frequency, 1) / max(targetPitch, 1))
        let clamped = min(max(ratio, -0.15), 0.15)
        return height * (0.5 - clamped / 0.3)
    }
}

private struct MemoryCueStrip: View {
    var body: some View {
        StudioPanel(title: "Memory Cues", systemImage: "eye.slash") {
            HStack {
                ValuePill(title: "Visible", value: "Rhythm", systemImage: "metronome")
                ValuePill(title: "Hidden", value: "Pitch names", systemImage: "eye.slash")
            }
        }
    }
}

private struct PitchDrillStrip: View {
    @Binding var targetPitch: Double

    var body: some View {
        StudioPanel(title: "Pitch Drill", systemImage: "scope") {
            HStack {
                Button("C4") { targetPitch = 261.63 }
                Button("E4") { targetPitch = 329.63 }
                Button("G4") { targetPitch = 392.00 }
                Button("A4") { targetPitch = 440.00 }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct PracticeMeasureList: View {
    var part: ScorePart

    var body: some View {
        StudioPanel(title: "Current Passage", systemImage: "music.note.list") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(part.measures.prefix(8)) { measure in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("M \(measure.number)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(measure.notes.prefix(5).map(ScoreFormatting.noteName).joined(separator: " "))
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                }
            }
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
