import AVFoundation
import Combine
import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct PracticeView: View {
    @ObservedObject var workspace: ShenghaiWorkspace
    @StateObject private var livePitchCapture = LivePitchCaptureService()
    @StateObject private var practiceAudio = PracticeAudioService()
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
                        practiceAudio: practiceAudio,
                        targetPitch: $targetPitch
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    Divider()

                    PracticeInspector(
                        workspace: workspace,
                        livePitchCapture: livePitchCapture,
                        practiceAudio: practiceAudio,
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
                            practiceAudio: practiceAudio,
                            targetPitch: $targetPitch
                        )
                        PracticeInspector(
                            workspace: workspace,
                            livePitchCapture: livePitchCapture,
                            practiceAudio: practiceAudio,
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
            return L10n.tr("follow score")
        case .memorization:
            return L10n.tr("hide cues")
        case .pitchDrill:
            return L10n.tr("intonation")
        case .commuteReview:
            return L10n.tr("offline pass")
        }
    }
}

private struct PracticeModeRail: View {
    @Binding var selectedMode: PracticeMode

    var body: some View {
        StudioPanel(title: L10n.tr("Modes"), systemImage: "rectangle.grid.1x2") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: mode.systemImage)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(L10n.tr(mode.rawValue))
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
    @ObservedObject var workspace: ShenghaiWorkspace
    var selectedMode: PracticeMode
    @ObservedObject var livePitchCapture: LivePitchCaptureService
    @ObservedObject var practiceAudio: PracticeAudioService
    @Binding var targetPitch: Double

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.scoreSummary.title)
                            .font(.title2.bold())
                        Text(L10n.tr(selectedMode.rawValue))
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
                            Label(livePitchCapture.isRunning ? L10n.tr("Stop") : L10n.tr("Start"), systemImage: livePitchCapture.isRunning ? "stop.fill" : "mic.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                TargetPitchCanvas(livePitchCapture: livePitchCapture, targetPitch: targetPitch)

                PianoKeyboardPanel(practiceAudio: practiceAudio, targetPitch: $targetPitch)

                if selectedMode == .memorization {
                    MemoryCueStrip()
                } else if selectedMode == .pitchDrill {
                    PitchDrillStrip(practiceAudio: practiceAudio, targetPitch: $targetPitch)
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
    @ObservedObject var workspace: ShenghaiWorkspace
    @ObservedObject var livePitchCapture: LivePitchCaptureService
    @ObservedObject var practiceAudio: PracticeAudioService
    @Binding var targetPitch: Double
    var mockDeviations: [PitchDeviation]

    var body: some View {
        VStack(spacing: 14) {
            LivePitchPanel(livePitchCapture: livePitchCapture)

            StudioPanel(title: L10n.tr("Target"), systemImage: "target") {
                VStack(alignment: .leading, spacing: 10) {
                    ValuePill(title: L10n.tr("Reference"), value: String(format: "%.1f Hz", targetPitch), systemImage: "waveform")
                    Slider(value: $targetPitch, in: 196...523.25, step: 0.1)
                    HStack {
                        Button {
                            practiceAudio.playReferenceTone(frequency: targetPitch)
                        } label: {
                            Label(L10n.tr("Play"), systemImage: "speaker.wave.2.fill")
                        }

                        Button {
                            if practiceAudio.isTuningForkRunning {
                                practiceAudio.stopTuningFork()
                            } else {
                                practiceAudio.startTuningFork(frequency: targetPitch)
                            }
                        } label: {
                            Label(practiceAudio.isTuningForkRunning ? L10n.tr("Stop Fork") : L10n.tr("Fork"), systemImage: "tuningfork")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            }

            MetronomePanel(practiceAudio: practiceAudio)

            TuningForkPanel(practiceAudio: practiceAudio, targetPitch: $targetPitch)

            StudioPanel(title: L10n.tr("Pitch States"), systemImage: "chart.xyaxis.line") {
                ForEach(Array(mockDeviations.enumerated()), id: \.offset) { _, deviation in
                    PitchDeviationRow(deviation: deviation)
                }
            }

            StudioPanel(title: L10n.tr("Build Queue"), systemImage: "hammer") {
                PipelineRow(title: L10n.tr("Microphone capture"), state: .ready)
                PipelineRow(title: L10n.tr("YIN tracker adapter"), state: .ready)
                PipelineRow(title: L10n.tr("Score-aligned target timeline"), state: .planned)
                PipelineRow(title: L10n.tr("Red mark overlay"), state: .planned)
            }
        }
    }
}

private struct LivePitchPanel: View {
    @ObservedObject var livePitchCapture: LivePitchCaptureService

    var body: some View {
        StudioPanel(title: L10n.tr("Live Pitch"), systemImage: "waveform.and.mic") {
            HStack {
                if let latestSample = livePitchCapture.latestSample {
                    MetricTile(
                        title: L10n.tr("Frequency"),
                        value: latestSample.frequencyHz.map { String(format: "%.1f Hz", $0) } ?? L10n.tr("text.no_pitch"),
                        systemImage: "waveform"
                    )
                    MetricTile(
                        title: L10n.tr("Confidence"),
                        value: String(format: "%.2f", latestSample.confidence),
                        systemImage: "checkmark.seal"
                    )
                } else {
                    Text(livePitchCapture.isRunning ? L10n.tr("Listening...") : L10n.tr("Mic idle"))
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
    @ObservedObject var livePitchCapture: LivePitchCaptureService
    var targetPitch: Double

    private var latestFrequency: Double? {
        livePitchCapture.latestSample?.frequencyHz
    }

    var body: some View {
        StudioPanel(title: L10n.tr("Intonation Trace"), systemImage: "waveform.path.ecg") {
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
                            Text(L10n.tr("flat"))
                            Spacer()
                            Text(L10n.tr("target"))
                            Spacer()
                            Text(L10n.tr("sharp"))
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
        StudioPanel(title: L10n.tr("Memory Cues"), systemImage: "eye.slash") {
            HStack {
                ValuePill(title: L10n.tr("Visible"), value: L10n.tr("Rhythm"), systemImage: "metronome")
                ValuePill(title: L10n.tr("Hidden"), value: L10n.tr("Pitch names"), systemImage: "eye.slash")
            }
        }
    }
}

private struct PitchDrillStrip: View {
    @ObservedObject var practiceAudio: PracticeAudioService
    @Binding var targetPitch: Double

    var body: some View {
        StudioPanel(title: L10n.tr("Pitch Drill"), systemImage: "scope") {
            HStack {
                ForEach(PianoKey.pitchDrillKeys) { key in
                    Button(key.name) {
                        targetPitch = key.frequency
                        practiceAudio.playPianoKey(key)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct PianoKeyboardPanel: View {
    @ObservedObject var practiceAudio: PracticeAudioService
    @Binding var targetPitch: Double

    private let keys = PianoKey.practiceKeys

    var body: some View {
        StudioPanel(title: L10n.tr("Piano"), systemImage: "pianokeys") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                ForEach(keys) { key in
                    Button {
                        targetPitch = key.frequency
                        practiceAudio.playPianoKey(key)
                    } label: {
                        VStack(spacing: 3) {
                            Text(key.name)
                                .font(.subheadline.weight(.semibold))
                            Text(String(format: "%.0f", key.frequency))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: key.isAccidental ? 46 : 58)
                    }
                    .buttonStyle(.bordered)
                    .tint(key.isAccidental ? .secondary : .accentColor)
                    .accessibilityLabel(L10n.tr("Play %@.", key.name))
                }
            }
        }
    }
}

private struct MetronomePanel: View {
    @ObservedObject var practiceAudio: PracticeAudioService

    var body: some View {
        StudioPanel(title: L10n.tr("Metronome"), systemImage: "metronome") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ValuePill(title: L10n.tr("Tempo"), value: "\(practiceAudio.metronomeBPM) bpm", systemImage: "speedometer")
                    ValuePill(title: L10n.tr("Beat"), value: "\(practiceAudio.currentBeat)/\(practiceAudio.beatsPerMeasure)", systemImage: "number")
                }

                Stepper("BPM \(practiceAudio.metronomeBPM)", value: $practiceAudio.metronomeBPM, in: 40...220, step: 2)

                Picker(L10n.tr("Meter"), selection: $practiceAudio.beatsPerMeasure) {
                    Text("2/4").tag(2)
                    Text("3/4").tag(3)
                    Text("4/4").tag(4)
                    Text("6/8").tag(6)
                }
                .pickerStyle(.segmented)

                Button {
                    practiceAudio.toggleMetronome()
                } label: {
                    Label(
                        practiceAudio.isMetronomeRunning ? L10n.tr("Stop Metronome") : L10n.tr("Start Metronome"),
                        systemImage: practiceAudio.isMetronomeRunning ? "stop.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct TuningForkPanel: View {
    @ObservedObject var practiceAudio: PracticeAudioService
    @Binding var targetPitch: Double

    var body: some View {
        StudioPanel(title: L10n.tr("Tuning Fork"), systemImage: "tuningfork") {
            VStack(alignment: .leading, spacing: 12) {
                ValuePill(title: L10n.tr("Fork"), value: String(format: "%.1f Hz", practiceAudio.tuningForkFrequency), systemImage: "waveform")

                HStack {
                    ForEach(PianoKey.forkKeys) { key in
                        Button(key.name) {
                            targetPitch = key.frequency
                            practiceAudio.tuningForkFrequency = key.frequency
                            practiceAudio.startTuningFork(frequency: key.frequency)
                        }
                    }
                }
                .buttonStyle(.bordered)

                HStack {
                    Button {
                        practiceAudio.startTuningFork(frequency: practiceAudio.tuningForkFrequency)
                    } label: {
                        Label(L10n.tr("Start"), systemImage: "waveform")
                    }

                    Button {
                        practiceAudio.stopTuningFork()
                    } label: {
                        Label(L10n.tr("Stop"), systemImage: "stop.fill")
                    }
                    .disabled(!practiceAudio.isTuningForkRunning)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

private struct PracticeMeasureList: View {
    var part: ScorePart

    var body: some View {
        StudioPanel(title: L10n.tr("Current Passage"), systemImage: "music.note.list") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                ForEach(part.measures.prefix(8)) { measure in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("Measure %@", "\(measure.number)"))
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

private struct PianoKey: Identifiable, Equatable {
    var midi: Int
    var name: String
    var isAccidental: Bool

    var id: Int { midi }

    var frequency: Double {
        440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    static let practiceKeys: [PianoKey] = [
        PianoKey(midi: 60, name: "C4", isAccidental: false),
        PianoKey(midi: 61, name: "C#4", isAccidental: true),
        PianoKey(midi: 62, name: "D4", isAccidental: false),
        PianoKey(midi: 63, name: "Eb4", isAccidental: true),
        PianoKey(midi: 64, name: "E4", isAccidental: false),
        PianoKey(midi: 65, name: "F4", isAccidental: false),
        PianoKey(midi: 66, name: "F#4", isAccidental: true),
        PianoKey(midi: 67, name: "G4", isAccidental: false),
        PianoKey(midi: 68, name: "Ab4", isAccidental: true),
        PianoKey(midi: 69, name: "A4", isAccidental: false),
        PianoKey(midi: 70, name: "Bb4", isAccidental: true),
        PianoKey(midi: 71, name: "B4", isAccidental: false),
        PianoKey(midi: 72, name: "C5", isAccidental: false)
    ]

    static let pitchDrillKeys: [PianoKey] = [
        PianoKey(midi: 60, name: "C4", isAccidental: false),
        PianoKey(midi: 64, name: "E4", isAccidental: false),
        PianoKey(midi: 67, name: "G4", isAccidental: false),
        PianoKey(midi: 69, name: "A4", isAccidental: false)
    ]

    static let forkKeys: [PianoKey] = [
        PianoKey(midi: 60, name: "C4", isAccidental: false),
        PianoKey(midi: 67, name: "G4", isAccidental: false),
        PianoKey(midi: 69, name: "A4", isAccidental: false),
        PianoKey(midi: 72, name: "C5", isAccidental: false)
    ]
}

@MainActor
private final class PracticeAudioService: ObservableObject {
    @Published var metronomeBPM = 72 {
        didSet {
            if isMetronomeRunning {
                restartMetronome()
            }
        }
    }
    @Published var beatsPerMeasure = 4 {
        didSet {
            currentBeat = min(currentBeat, beatsPerMeasure)
        }
    }
    @Published var currentBeat = 1
    @Published var isMetronomeRunning = false
    @Published var tuningForkFrequency = 440.0
    @Published var isTuningForkRunning = false

    private let engine = AVAudioEngine()
    private let transientPlayer = AVAudioPlayerNode()
    private let dronePlayer = AVAudioPlayerNode()
    private var isEnginePrepared = false
    private var metronomeTimer: Timer?

    func toggleMetronome() {
        if isMetronomeRunning {
            stopMetronome()
        } else {
            startMetronome()
        }
    }

    func startMetronome() {
        stopMetronome()
        isMetronomeRunning = true
        currentBeat = 1
        playMetronomeBeat()
        scheduleMetronomeTimer()
    }

    func stopMetronome() {
        metronomeTimer?.invalidate()
        metronomeTimer = nil
        isMetronomeRunning = false
        currentBeat = 1
    }

    func playPianoKey(_ key: PianoKey) {
        playTone(frequency: key.frequency, duration: 0.85, gain: 0.24)
    }

    func playReferenceTone(frequency: Double) {
        playTone(frequency: frequency, duration: 1.15, gain: 0.22)
    }

    func startTuningFork(frequency: Double) {
        tuningForkFrequency = frequency
        prepareEngineIfNeeded()
        dronePlayer.stop()
        let buffer = makeToneBuffer(frequency: frequency, duration: 1.4, gain: 0.12, attack: 0.03, release: 0.08)
        dronePlayer.scheduleBuffer(buffer, at: nil, options: [.loops])
        startEngineIfNeeded()
        dronePlayer.play()
        isTuningForkRunning = true
    }

    func stopTuningFork() {
        dronePlayer.stop()
        isTuningForkRunning = false
    }

    private func restartMetronome() {
        metronomeTimer?.invalidate()
        scheduleMetronomeTimer()
    }

    private func scheduleMetronomeTimer() {
        let interval = 60.0 / Double(max(metronomeBPM, 1))
        metronomeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMetronome()
            }
        }
    }

    private func advanceMetronome() {
        currentBeat = currentBeat >= beatsPerMeasure ? 1 : currentBeat + 1
        playMetronomeBeat()
    }

    private func playMetronomeBeat() {
        let accent = currentBeat == 1
        playTone(
            frequency: accent ? 1_320 : 880,
            duration: accent ? 0.09 : 0.065,
            gain: accent ? 0.34 : 0.22
        )
    }

    private func playTone(frequency: Double, duration: Double, gain: Double) {
        prepareEngineIfNeeded()
        let buffer = makeToneBuffer(frequency: frequency, duration: duration, gain: gain, attack: 0.012, release: 0.18)
        transientPlayer.scheduleBuffer(buffer)
        startEngineIfNeeded()
        if !transientPlayer.isPlaying {
            transientPlayer.play()
        }
    }

    private func prepareEngineIfNeeded() {
        guard !isEnginePrepared else {
            return
        }

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // The audio tools still try to play through AVAudioEngine if the session setup fails.
        }
        #endif

        engine.attach(transientPlayer)
        engine.attach(dronePlayer)
        let mixer = engine.mainMixerNode
        engine.connect(transientPlayer, to: mixer, format: nil)
        engine.connect(dronePlayer, to: mixer, format: nil)
        engine.prepare()
        isEnginePrepared = true
    }

    private func startEngineIfNeeded() {
        guard !engine.isRunning else {
            return
        }

        do {
            try engine.start()
        } catch {
            isMetronomeRunning = false
            isTuningForkRunning = false
        }
    }

    private func makeToneBuffer(
        frequency: Double,
        duration: Double,
        gain: Double,
        attack: Double,
        release: Double
    ) -> AVAudioPCMBuffer {
        let sampleRate = 44_100.0
        let frameCount = AVAudioFrameCount(max(duration * sampleRate, 1))
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else {
            return buffer
        }

        let attackFrames = max(Int(attack * sampleRate), 1)
        let releaseFrames = max(Int(release * sampleRate), 1)
        let totalFrames = Int(frameCount)
        let angularStep = 2.0 * Double.pi * frequency / sampleRate

        for frame in 0..<totalFrames {
            let attackEnvelope = min(Double(frame) / Double(attackFrames), 1)
            let releaseEnvelope = min(Double(max(totalFrames - frame, 0)) / Double(releaseFrames), 1)
            let envelope = min(attackEnvelope, releaseEnvelope)
            let sample = sin(Double(frame) * angularStep) * gain * envelope
            channel[frame] = Float(sample)
        }

        return buffer
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
            return L10n.tr("In tune")
        case .sharp:
            return L10n.tr("Sharp")
        case .flat:
            return L10n.tr("Flat")
        case .lowConfidence:
            return L10n.tr("Low confidence")
        case .missingTarget:
            return L10n.tr("Missing target")
        }
    }

    private var detail: String {
        if let cents = deviation.cents {
            return L10n.tr("%.1f cents, confidence %.2f", cents, deviation.confidence)
        }
        return L10n.tr("confidence %.2f", deviation.confidence)
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
