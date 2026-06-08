import SwiftUI
import UniformTypeIdentifiers
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ScoreWorkspaceView: View {
    @Bindable var workspace: ShenghaiWorkspace
    @State private var pageScale = 1.0
    @State private var showPitchOverlay = true
    @State private var showMeasureNumbers = true
    @State private var isAnnotating = false
    @State private var annotationTool: ScoreAnnotationTool = .pen
    @State private var annotationLineWidth = 3.0
    @State private var annotationStrokes: [ScoreAnnotationStroke] = []
    @State private var annotationDraft: [CGPoint] = []
    @State private var partVolumes: [String: Double] = [:]
    @State private var mutedPartIDs: Set<String> = []
    @State private var soloPartID: String?

    private var musicXMLTypes: [UTType] {
        [.xml, UTType(filenameExtension: "musicxml")].compactMap { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreToolbar(workspace: workspace)
            Divider()

            if let score = workspace.score {
                GeometryReader { proxy in
                    if proxy.size.width >= 980 {
                        HStack(alignment: .top, spacing: 0) {
                            ScoreNavigatorPanel(workspace: workspace, score: score)
                                .frame(width: 230)
                                .padding()

                            Divider()

                            ScoreReaderPanel(
                                workspace: workspace,
                                score: score,
                                pageScale: pageScale,
                                showPitchOverlay: showPitchOverlay,
                                showMeasureNumbers: showMeasureNumbers,
                                isAnnotating: isAnnotating,
                                annotationTool: annotationTool,
                                annotationLineWidth: annotationLineWidth,
                                annotationStrokes: $annotationStrokes,
                                annotationDraft: $annotationDraft
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                            Divider()

                            ScoreInspectorPanel(
                                workspace: workspace,
                                score: score,
                                pageScale: $pageScale,
                                showPitchOverlay: $showPitchOverlay,
                                showMeasureNumbers: $showMeasureNumbers,
                                isAnnotating: $isAnnotating,
                                annotationTool: $annotationTool,
                                annotationLineWidth: $annotationLineWidth,
                                annotationStrokes: $annotationStrokes,
                                annotationDraft: $annotationDraft,
                                partVolumes: $partVolumes,
                                mutedPartIDs: $mutedPartIDs,
                                soloPartID: $soloPartID
                            )
                            .frame(width: 310)
                            .padding()
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                ScoreNavigatorPanel(workspace: workspace, score: score)
                                ScoreReaderPanel(
                                    workspace: workspace,
                                    score: score,
                                    pageScale: pageScale,
                                    showPitchOverlay: showPitchOverlay,
                                    showMeasureNumbers: showMeasureNumbers,
                                    isAnnotating: isAnnotating,
                                    annotationTool: annotationTool,
                                    annotationLineWidth: annotationLineWidth,
                                    annotationStrokes: $annotationStrokes,
                                    annotationDraft: $annotationDraft
                                )
                                ScoreInspectorPanel(
                                    workspace: workspace,
                                    score: score,
                                    pageScale: $pageScale,
                                    showPitchOverlay: $showPitchOverlay,
                                    showMeasureNumbers: $showMeasureNumbers,
                                    isAnnotating: $isAnnotating,
                                    annotationTool: $annotationTool,
                                    annotationLineWidth: $annotationLineWidth,
                                    annotationStrokes: $annotationStrokes,
                                    annotationDraft: $annotationDraft,
                                    partVolumes: $partVolumes,
                                    mutedPartIDs: $mutedPartIDs,
                                    soloPartID: $soloPartID
                                )
                            }
                            .padding()
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Score Loaded",
                    systemImage: "music.note.list",
                    description: Text("Import MusicXML, or convert a PDF/image score into an editable MusicXML candidate and review it here.")
                )
            }
        }
        .fileImporter(
            isPresented: $workspace.isImportingScore,
            allowedContentTypes: musicXMLTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }
            workspace.importMusicXML(url: url)
        }
    }
}

private enum ScoreAnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case highlighter
    case eraser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pen:
            return "Pen"
        case .highlighter:
            return "Highlighter"
        case .eraser:
            return "Eraser"
        }
    }

    var systemImage: String {
        switch self {
        case .pen:
            return "pencil.tip"
        case .highlighter:
            return "highlighter"
        case .eraser:
            return "eraser"
        }
    }
}

private struct ScoreAnnotationStroke: Identifiable {
    var id = UUID()
    var points: [CGPoint]
    var color: Color
    var opacity: Double
    var lineWidth: Double
}

private struct ScoreToolbar: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        HStack(spacing: 8) {
            Text("Shenghai Studio")
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            ToolIconButton(title: "Import MusicXML", systemImage: "square.and.arrow.down") {
                workspace.isImportingScore = true
            }

            ToolIconButton(title: "Load Demo", systemImage: "sparkles") {
                workspace.loadDemoScore()
            }

            ToolIconButton(
                title: workspace.isPlaying ? "Stop Playback" : "Play Selected Part",
                systemImage: workspace.isPlaying ? "stop.fill" : "play.fill",
                isProminent: true
            ) {
                workspace.playOrStop()
            }
            .disabled(workspace.score == nil)

            ToolIconButton(title: "Export MIDI", systemImage: "square.and.arrow.up") {
                workspace.exportMIDI()
            }
            .disabled(workspace.score == nil)

            if let exportedMIDIURL = workspace.exportedMIDIURL {
                ShareLink(item: exportedMIDIURL) {
                    Label("Share MIDI", systemImage: "arrowshape.turn.up.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .help("Share MIDI")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ScoreNavigatorPanel: View {
    @Bindable var workspace: ShenghaiWorkspace
    var score: ScoreDocument

    var body: some View {
        StudioPanel(title: "Parts", systemImage: "rectangle.split.3x1") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(score.parts) { part in
                    Button {
                        workspace.selectedPartID = part.id
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: workspace.selectedPartID == part.id ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(workspace.selectedPartID == part.id ? Color.accentColor : Color.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(part.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(part.measures.count) measures")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ValuePill(title: "Measures", value: "\(workspace.scoreSummary.measureCount)", systemImage: "number")
                ValuePill(title: "Playable Notes", value: "\(workspace.scoreSummary.playableNoteCount)", systemImage: "music.note")
                ValuePill(title: "Tempo", value: "\(score.tempoBPM) bpm", systemImage: "metronome")
            }
        }
    }
}

private struct ScoreReaderPanel: View {
    @Bindable var workspace: ShenghaiWorkspace
    var score: ScoreDocument
    var pageScale: Double
    var showPitchOverlay: Bool
    var showMeasureNumbers: Bool
    var isAnnotating: Bool
    var annotationTool: ScoreAnnotationTool
    var annotationLineWidth: Double
    @Binding var annotationStrokes: [ScoreAnnotationStroke]
    @Binding var annotationDraft: [CGPoint]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workspace.scoreSummary.title)
                            .font(.title2.bold())
                        Text("MusicXML preview")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(isAnnotating ? "Annotation mode" : "Voice practice", systemImage: isAnnotating ? "pencil.tip" : "waveform.and.mic")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 22) {
                    if let part = workspace.selectedPart {
                        ForEach(part.measures) { measure in
                            StaffMeasureView(
                                measure: measure,
                                ticksPerQuarter: score.ticksPerQuarter,
                                showPitchOverlay: showPitchOverlay,
                                showMeasureNumber: showMeasureNumbers
                            )
                        }
                    } else {
                        ContentUnavailableView("No Part Selected", systemImage: "music.note")
                    }
                }
            }
            .frame(width: 760 * pageScale, alignment: .topLeading)
            .padding(28)
            .background(.white, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(.black)
            .overlay {
                VectorAnnotationLayer(
                    strokes: $annotationStrokes,
                    draft: $annotationDraft,
                    tool: annotationTool,
                    lineWidth: annotationLineWidth
                )
                .allowsHitTesting(isAnnotating)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
            .padding(32)
        }
        .background(.quaternary.opacity(0.18))
    }
}

private struct ScoreInspectorPanel: View {
    @Bindable var workspace: ShenghaiWorkspace
    var score: ScoreDocument
    @Binding var pageScale: Double
    @Binding var showPitchOverlay: Bool
    @Binding var showMeasureNumbers: Bool
    @Binding var isAnnotating: Bool
    @Binding var annotationTool: ScoreAnnotationTool
    @Binding var annotationLineWidth: Double
    @Binding var annotationStrokes: [ScoreAnnotationStroke]
    @Binding var annotationDraft: [CGPoint]
    @Binding var partVolumes: [String: Double]
    @Binding var mutedPartIDs: Set<String>
    @Binding var soloPartID: String?

    var body: some View {
        VStack(spacing: 14) {
            StudioPanel(title: "Practice Display", systemImage: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Pitch overlay", isOn: $showPitchOverlay)
                    Toggle("Measure numbers", isOn: $showMeasureNumbers)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Zoom")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $pageScale, in: 0.75...1.45, step: 0.05)
                    }
                }
            }

            StudioPanel(title: "Annotations", systemImage: "pencil.and.outline") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Annotation mode", isOn: $isAnnotating)

                    HStack(spacing: 8) {
                        ForEach(ScoreAnnotationTool.allCases) { tool in
                            Button {
                                annotationTool = tool
                            } label: {
                                Image(systemName: tool.systemImage)
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(annotationTool == tool ? Color.accentColor : Color.secondary)
                            }
                            .buttonStyle(.bordered)
                            .help(tool.title)
                            .accessibilityLabel(tool.title)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Line width")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $annotationLineWidth, in: 1.5...8, step: 0.5)
                    }

                    HStack {
                        Button {
                            undoLastAnnotation()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(annotationStrokes.isEmpty)

                        Button(role: .destructive) {
                            clearAnnotations()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .disabled(annotationStrokes.isEmpty)
                    }
                    .buttonStyle(.bordered)

                    Text("\(annotationStrokes.count) vector strokes. Strokes are stored as scalable paths, not a page bitmap.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            StudioPanel(title: "Mixer", systemImage: "slider.vertical.3") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(score.parts) { part in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(part.name)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Button {
                                    toggleMute(part.id)
                                } label: {
                                    Image(systemName: mutedPartIDs.contains(part.id) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                }
                                .buttonStyle(.borderless)
                                .help(mutedPartIDs.contains(part.id) ? "Unmute" : "Mute")

                                Button {
                                    soloPartID = soloPartID == part.id ? nil : part.id
                                } label: {
                                    Text("S")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(soloPartID == part.id ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help("Solo")
                            }
                            Slider(value: bindingForVolume(part.id), in: 0...1)
                        }
                    }
                }
            }

            StudioPanel(title: "Full-Score MusicXML Review", systemImage: "doc.badge.magnifyingglass") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Main scan workflow: PDF/image score -> MusicXML candidate -> user correction -> annotations, playback, pitch tracking, and practice history.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        workspace.createScanReviewCandidate()
                    } label: {
                        Label("Create Review Candidate", systemImage: "checklist")
                    }
                    .buttonStyle(.borderedProminent)

                    let candidate = workspace.scannedMusicXMLCandidate ?? OMRMusicXMLCandidateBuilder.makeCandidate(
                        sourceName: "Current score",
                        inputKind: .musicXML,
                        provider: workspace.selectedOMRProvider,
                        score: score
                    )

                    HStack {
                        ValuePill(title: "Source", value: candidate.inputKind.rawValue, systemImage: "doc")
                        ValuePill(title: "Provider", value: candidate.provider.displayName, systemImage: "wand.and.stars")
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(candidate.recognizedElements) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("\(item.count)")
                                        .font(.headline)
                                    Spacer()
                                    Image(systemName: item.needsUserReview ? "exclamationmark.circle" : "checkmark.circle")
                                        .foregroundStyle(item.needsUserReview ? .orange : .green)
                                }
                                Text(item.kind.displayName)
                                    .font(.caption.weight(.semibold))
                                Text(item.note)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            .padding(8)
                            .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }

                    SectionTitle("Review checklist")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(candidate.reviewChecklist, id: \.self) { item in
                            Label(item, systemImage: "square.and.pencil")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    PipelineRow(
                        title: "Ready for practice after review",
                        state: candidate.canEnterPracticeWorkflow ? .ready : .blocked,
                        detail: candidate.canEnterPracticeWorkflow ? "Candidate has score data; review/correct before practice." : "Candidate has no usable notes."
                    )
                }
            }

            StudioPanel(title: "OMR Review", systemImage: "doc.viewfinder") {
                Picker("Provider", selection: $workspace.selectedOMRProvider) {
                    ForEach(OMRProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName)
                            .tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                OMRProviderSummary(provider: workspace.selectedOMRProvider)

                PipelineRow(title: "MusicXML parsed", state: .ready, detail: "\(workspace.scoreSummary.noteCount) notes")
                PipelineRow(title: "\(workspace.selectedOMRProvider.displayName) full-score OMR", state: .planned, detail: "Run provider, import generated MusicXML, then validate every recognized element.")
                PipelineRow(title: "Editable MusicXML correction gate", state: .ready, detail: "Correct candidate first; then use it for notes, annotations, playback, and practice.")
                PipelineRow(title: "Repeat expansion audit", state: .planned)
            }
        }
    }

    private func bindingForVolume(_ id: String) -> Binding<Double> {
        Binding(
            get: { partVolumes[id] ?? 0.82 },
            set: { partVolumes[id] = $0 }
        )
    }

    private func undoLastAnnotation() {
        annotationDraft.removeAll()
        _ = annotationStrokes.popLast()
    }

    private func clearAnnotations() {
        annotationDraft.removeAll()
        annotationStrokes.removeAll()
    }

    private func toggleMute(_ id: String) {
        if mutedPartIDs.contains(id) {
            mutedPartIDs.remove(id)
        } else {
            mutedPartIDs.insert(id)
        }
    }
}

private struct OMRProviderSummary: View {
    var provider: OMRProvider

    private var commandPlan: OMRProviderCommandPlan {
        OMRProviderCommandPlan(
            provider: provider,
            inputPath: "~/Scores/input-score.png",
            outputPath: "~/Scores/output.musicxml"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.tint)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(provider.summary)
                        .font(.subheadline.weight(.semibold))
                    Text(provider.bestFor)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Label(provider.licenseNote, systemImage: "shield.lefthalf.filled")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(commandPlan.shellPreview)
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(10)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct VectorAnnotationLayer: View {
    @Binding var strokes: [ScoreAnnotationStroke]
    @Binding var draft: [CGPoint]
    var tool: ScoreAnnotationTool
    var lineWidth: Double

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for stroke in strokes {
                    draw(stroke.points, in: size, context: &context, stroke: stroke)
                }

                if !draft.isEmpty, tool != .eraser {
                    draw(
                        draft,
                        in: size,
                        context: &context,
                        stroke: makeStroke(points: draft)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = normalizedPoint(from: value.location, size: proxy.size)
                        switch tool {
                        case .eraser:
                            erase(near: point)
                        case .pen, .highlighter:
                            if draft.last.map({ distance($0, point) > 0.002 }) ?? true {
                                draft.append(point)
                            }
                        }
                    }
                    .onEnded { _ in
                        guard tool != .eraser, draft.count > 1 else {
                            draft.removeAll()
                            return
                        }
                        strokes.append(makeStroke(points: draft))
                        draft.removeAll()
                    }
            )
        }
    }

    private func draw(
        _ points: [CGPoint],
        in size: CGSize,
        context: inout GraphicsContext,
        stroke: ScoreAnnotationStroke
    ) {
        guard points.count > 1 else {
            return
        }

        var path = Path()
        path.move(to: denormalize(points[0], size: size))
        for point in points.dropFirst() {
            path.addLine(to: denormalize(point, size: size))
        }

        context.stroke(
            path,
            with: .color(stroke.color.opacity(stroke.opacity)),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func makeStroke(points: [CGPoint]) -> ScoreAnnotationStroke {
        switch tool {
        case .pen:
            return ScoreAnnotationStroke(
                points: points,
                color: .red,
                opacity: 0.88,
                lineWidth: lineWidth
            )
        case .highlighter:
            return ScoreAnnotationStroke(
                points: points,
                color: .yellow,
                opacity: 0.34,
                lineWidth: max(lineWidth * 3.2, 12)
            )
        case .eraser:
            return ScoreAnnotationStroke(points: points, color: .clear, opacity: 0, lineWidth: lineWidth)
        }
    }

    private func erase(near point: CGPoint) {
        let threshold: CGFloat = 0.018
        strokes.removeAll { stroke in
            stroke.points.contains { distance($0, point) < threshold }
        }
    }

    private func normalizedPoint(from location: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(
            x: min(max(location.x / max(size.width, 1), 0), 1),
            y: min(max(location.y / max(size.height, 1), 0), 1)
        )
    }

    private func denormalize(_ point: CGPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

private struct StaffMeasureView: View {
    var measure: ScoreMeasure
    var ticksPerQuarter: Int
    var showPitchOverlay: Bool
    var showMeasureNumber: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if showMeasureNumber {
                Text("Measure \(measure.number)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if !measure.directions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(measure.directions) { direction in
                        Text(direction.value)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.yellow.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    VStack(spacing: 10) {
                        ForEach(0..<5, id: \.self) { _ in
                            Rectangle()
                                .fill(.black.opacity(0.28))
                                .frame(height: 1)
                        }
                    }
                    .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(.black.opacity(0.5))
                        .frame(width: 1)
                        .frame(maxHeight: .infinity, alignment: .trailing)
                        .frame(maxWidth: .infinity, alignment: .trailing)

                    ForEach(Array(measure.notes.enumerated()), id: \.element.id) { index, note in
                        NoteGlyph(
                            note: note,
                            ticksPerQuarter: ticksPerQuarter,
                            showPitchOverlay: showPitchOverlay
                        )
                        .position(x: xPosition(index: index, width: proxy.size.width), y: yPosition(note: note, height: proxy.size.height))
                    }
                }
            }
            .frame(height: 86)
        }
        .padding(.horizontal, 8)
    }

    private func xPosition(index: Int, width: CGFloat) -> CGFloat {
        guard !measure.notes.isEmpty else {
            return 28
        }
        let available = max(width - 56, 1)
        let step = available / CGFloat(max(measure.notes.count - 1, 1))
        return 28 + CGFloat(index) * step
    }

    private func yPosition(note: ScoreNote, height: CGFloat) -> CGFloat {
        guard let midi = note.midi else {
            return height * 0.58
        }
        let clamped = min(max(midi, 55), 79)
        let normalized = CGFloat(clamped - 55) / 24
        return height * (0.82 - normalized * 0.58)
    }
}

private struct NoteGlyph: View {
    var note: ScoreNote
    var ticksPerQuarter: Int
    var showPitchOverlay: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Capsule()
                    .fill(note.isRest ? Color.secondary.opacity(0.25) : Color.black)
                    .frame(width: noteWidth, height: 14)
                    .rotationEffect(.degrees(-12))

                if showPitchOverlay, !note.isRest {
                    Circle()
                        .stroke(.red.opacity(0.68), lineWidth: 2)
                        .frame(width: 22, height: 22)
                }
            }
            Text(ScoreFormatting.noteName(note))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let lyricText = note.lyrics.first?.text {
                Text(lyricText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .help(ScoreFormatting.durationLabel(ticks: note.durationTick, ticksPerQuarter: ticksPerQuarter))
    }

    private var noteWidth: CGFloat {
        let quarterTicks = max(ticksPerQuarter, 1)
        let ratio = Double(note.durationTick) / Double(quarterTicks)
        return CGFloat(min(max(18 + ratio * 10, 18), 38))
    }
}
