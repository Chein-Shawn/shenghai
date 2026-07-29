import SwiftUI
import UniformTypeIdentifiers
#if canImport(WebKit)
import WebKit
#endif
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

struct ScoreWorkspaceView: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    @State private var musicXMLDraft = ""
    @State private var pageScale = 1.0
    @State private var showPitchOverlay = true
    @State private var showMeasureNumbers = true
    @State private var showSourceOverlay = true
    @State private var isAnnotating = false
    @State private var annotationTool: ScoreAnnotationTool = .pen
    @State private var annotationLineWidth = 3.0
    @State private var annotationDraft: [CGPoint] = []
    @State private var partVolumes: [String: Double] = [:]
    @State private var mutedPartIDs: Set<String> = []
    @State private var soloPartID: String?

    private var importableScoreTypes: [UTType] {
        switch workspace.pendingScoreImportFlow {
        case .musicXML:
            return [
                .xml,
                UTType(filenameExtension: "musicxml")
            ].compactMap { $0 }
        case .scan:
            return [
                .pdf,
                .image
            ].compactMap { $0 }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreToolbar(workspace: workspace)
            Divider()

            if workspace.statusMessage.isEmpty == false || workspace.errorMessage != nil {
                ScoreStatusStack(
                    statusMessage: workspace.statusMessage,
                    errorMessage: workspace.errorMessage,
                    scanProgress: workspace.scanProgress,
                    showRemoteOMRSettingsAction: workspace.remoteOMRConnectionRequired,
                    openRemoteOMRSettings: workspace.openRemoteOMRSettings
                )
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
            }

            if let score = workspace.score {
                GeometryReader { proxy in
                    if proxy.size.width >= 1220 {
                        HStack(spacing: 0) {
                            ScoreSourcePreviewPanel(
                                workspace: workspace,
                                reviewSession: workspace.scoreReviewSession,
                                showSourceOverlay: $showSourceOverlay
                            )
                            .frame(width: 320)
                            .padding()

                            Divider()

                            SymbolicScoreReviewPanel(
                                workspace: workspace,
                                score: score,
                                reviewSession: workspace.scoreReviewSession,
                                pageScale: pageScale,
                                showPitchOverlay: showPitchOverlay,
                                showMeasureNumbers: showMeasureNumbers,
                                isAnnotating: isAnnotating,
                                annotationTool: annotationTool,
                                annotationLineWidth: annotationLineWidth,
                                annotationStrokes: $workspace.annotationStrokes,
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
                                showSourceOverlay: $showSourceOverlay,
                                isAnnotating: $isAnnotating,
                                annotationTool: $annotationTool,
                                annotationLineWidth: $annotationLineWidth,
                                annotationStrokes: $workspace.annotationStrokes,
                                annotationDraft: $annotationDraft,
                                partVolumes: $partVolumes,
                                mutedPartIDs: $mutedPartIDs,
                                soloPartID: $soloPartID
                            )
                            .frame(width: 350)
                            .padding()
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                ScoreSourcePreviewPanel(
                                    workspace: workspace,
                                    reviewSession: workspace.scoreReviewSession,
                                    showSourceOverlay: $showSourceOverlay
                                )
                                SymbolicScoreReviewPanel(
                                    workspace: workspace,
                                    score: score,
                                    reviewSession: workspace.scoreReviewSession,
                                    pageScale: pageScale,
                                    showPitchOverlay: showPitchOverlay,
                                    showMeasureNumbers: showMeasureNumbers,
                                    isAnnotating: isAnnotating,
                                    annotationTool: annotationTool,
                                    annotationLineWidth: annotationLineWidth,
                                    annotationStrokes: $workspace.annotationStrokes,
                                    annotationDraft: $annotationDraft
                                )
                                ScoreInspectorPanel(
                                    workspace: workspace,
                                    score: score,
                                    pageScale: $pageScale,
                                    showPitchOverlay: $showPitchOverlay,
                                    showMeasureNumbers: $showMeasureNumbers,
                                    showSourceOverlay: $showSourceOverlay,
                                    isAnnotating: $isAnnotating,
                                    annotationTool: $annotationTool,
                                    annotationLineWidth: $annotationLineWidth,
                                    annotationStrokes: $workspace.annotationStrokes,
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
                ScoreLandingView(
                    workspace: workspace,
                    musicXMLDraft: $musicXMLDraft
                )
            }
        }
        .fileImporter(
            isPresented: $workspace.isImportingScore,
            allowedContentTypes: importableScoreTypes,
            allowsMultipleSelection: workspace.pendingScoreImportFlow == .scan
        ) { result in
            guard case let .success(urls) = result, urls.isEmpty == false else {
                return
            }
            workspace.importScoreFiles(urls: urls)
        }
        .alert(
            L10n.tr("score.scan.upload_disclosure.title"),
            isPresented: Binding(
                get: { workspace.remoteOMRUploadDisclosure != nil },
                set: { presented in
                    if presented == false {
                        workspace.cancelRemoteOMRUpload()
                    }
                }
            )
        ) {
            Button(L10n.tr("score.scan.upload_disclosure.cancel"), role: .cancel) {
                workspace.cancelRemoteOMRUpload()
            }
            Button(L10n.tr("score.scan.upload_disclosure.confirm")) {
                workspace.confirmRemoteOMRUpload()
            }
        } message: {
            Text(L10n.tr("score.scan.upload_disclosure.message"))
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
            return L10n.tr("Pen")
        case .highlighter:
            return L10n.tr("Highlighter")
        case .eraser:
            return L10n.tr("Eraser")
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

private struct ScoreToolbar: View {
    @ObservedObject var workspace: VocalDiveWorkspace

    var body: some View {
        HStack(spacing: 8) {
            Text(L10n.tr("VocalDive Studio"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer()

            Picker(L10n.tr("Score Mode"), selection: Binding(
                get: { workspace.scoreLandingMode },
                set: { workspace.scoreLandingMode = $0 }
            )) {
                Text(L10n.tr("score.mode.musicxml_editor")).tag(ScoreLandingMode.editor)
                Text(L10n.tr("score.mode.scan_to_musicxml")).tag(ScoreLandingMode.scan)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)

            ToolIconButton(title: L10n.tr("score.editor.import_musicxml_file"), systemImage: "doc.badge.plus") {
                workspace.startMusicXMLImport()
            }

            ToolIconButton(title: L10n.tr("score.scan.import_pdf_or_image"), systemImage: "photo.badge.plus") {
                workspace.startScanImport()
            }

            ToolIconButton(title: L10n.tr("score.editor.export_current_musicxml"), systemImage: "square.and.arrow.up.on.square") {
                workspace.exportCurrentMusicXML()
            }
            .disabled(workspace.score == nil)

            ToolIconButton(
                title: workspace.isPlaying ? L10n.tr("Stop Playback") : L10n.tr("Play Selected Part"),
                systemImage: workspace.isPlaying ? "stop.fill" : "play.fill",
                isProminent: true
            ) {
                workspace.playOrStop()
            }
            .disabled(workspace.score == nil)

            ToolIconButton(title: L10n.tr("Export MIDI"), systemImage: "square.and.arrow.up") {
                workspace.exportMIDI()
            }
            .disabled(workspace.score == nil)

            if let exportedMusicXMLURL = workspace.exportedMusicXMLURL {
                ShareLink(item: exportedMusicXMLURL) {
                    Label(L10n.tr("score.editor.share_musicxml"), systemImage: "arrowshape.turn.up.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("score.editor.share_musicxml"))
            }

            if let exportedMIDIURL = workspace.exportedMIDIURL {
                ShareLink(item: exportedMIDIURL) {
                    Label(L10n.tr("Share MIDI"), systemImage: "arrowshape.turn.up.right")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .help(L10n.tr("Share MIDI"))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct ScoreStatusStack: View {
    var statusMessage: String
    var errorMessage: String?
    var scanProgress: NativeOMRScanProgress?
    var showRemoteOMRSettingsAction: Bool
    var openRemoteOMRSettings: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let scanProgress {
                ScanProgressBanner(progress: scanProgress, text: statusMessage)
            } else if statusMessage.isEmpty == false {
                StatusBanner(text: statusMessage, tint: .blue, systemImage: "info.circle.fill")
            }
            if let errorMessage {
                StatusBanner(text: errorMessage, tint: .orange, systemImage: "exclamationmark.triangle.fill")
            }
            if showRemoteOMRSettingsAction {
                Button(L10n.tr("score.scan.remote_connection_action"), action: openRemoteOMRSettings)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private struct ScanProgressBanner: View {
    var progress: NativeOMRScanProgress
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .foregroundStyle(Color.blue)
                Text(text)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
        }
        .padding(10)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct StatusBanner: View {
    var text: String
    var tint: Color
    var systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }
}

private struct ScoreLandingView: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    @Binding var musicXMLDraft: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(L10n.tr("Score Mode"), selection: $workspace.scoreLandingMode) {
                    Text(L10n.tr("score.mode.musicxml_editor")).tag(ScoreLandingMode.editor)
                    Text(L10n.tr("score.mode.scan_to_musicxml")).tag(ScoreLandingMode.scan)
                }
                .pickerStyle(.segmented)

                if workspace.scoreLandingMode == .editor {
                    StudioPanel(title: L10n.tr("score.mode.musicxml_editor"), systemImage: "music.note.list") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.tr("score.landing.editor_description"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            TextEditor(text: $musicXMLDraft)
                                .font(.system(.caption, design: .monospaced))
                                .frame(minHeight: 220)
                                .padding(8)
                                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                            HStack {
                                Button {
                                    workspace.importMusicXMLText(musicXMLDraft)
                                } label: {
                                    Label(L10n.tr("score.editor.open_pasted_musicxml"), systemImage: "arrow.down.doc")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    workspace.startMusicXMLImport()
                                } label: {
                                    Label(L10n.tr("score.editor.import_musicxml_file"), systemImage: "doc.badge.plus")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    workspace.loadSampleGroundTruth()
                                } label: {
                                    Label(L10n.tr("score.sample.open_ground_truth"), systemImage: "sparkles")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                } else {
                    StudioPanel(title: L10n.tr("score.mode.scan_to_musicxml"), systemImage: "photo.badge.plus") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L10n.tr("score.landing.scan_description"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(L10n.tr("score.scan.model_description_vocaldive"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8))

                            HStack {
                                Button {
                                    workspace.startScanImport()
                                } label: {
                                    Label(L10n.tr("score.scan.import_pdf_or_image"), systemImage: "photo.badge.plus")
                                }
                                .buttonStyle(.borderedProminent)

                                Button {
                                    workspace.runSampleIntactOMR()
                                } label: {
                                    Label(L10n.tr("score.sample.run_intact_omr"), systemImage: "doc.viewfinder")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    workspace.runSampleScannedOMR()
                                } label: {
                                    Label(L10n.tr("score.sample.run_scanned_omr"), systemImage: "camera.viewfinder")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                StudioPanel(title: L10n.tr("Compose"), systemImage: "square.and.pencil") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.tr("text.create_a_simple_musicxml_score_then_load_it_into_practice"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Button {
                            workspace.compactScoreMode = .compose
                            workspace.selectedSection = .scoreComposer
                        } label: {
                            Label(L10n.tr("nav.compose"), systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
    }
}

private struct ScoreSourcePreviewPanel: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    var reviewSession: ScoreReviewSession?
    @Binding var showSourceOverlay: Bool

    private var currentPage: ScoreReviewPage? {
        reviewSession?.pages.first(where: { $0.pageIndex == workspace.selectedReviewPageIndex })
            ?? reviewSession?.pages.first
    }

    private var currentPageSymbols: [ScoreReviewSymbol] {
        guard let reviewSession else {
            return []
        }
        return reviewSession.symbols.filter { $0.pageIndex == currentPage?.pageIndex }
    }

    var body: some View {
        VStack(spacing: 14) {
            StudioPanel(title: L10n.tr("score.review.original_pages"), systemImage: "doc.richtext") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.tr("score.review.show_source_overlay"), isOn: $showSourceOverlay)
                }
            }

            if let reviewSession, reviewSession.pages.isEmpty == false {
                StudioPanel(title: L10n.tr("score.review.page_thumbnails"), systemImage: "rectangle.grid.1x2") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(reviewSession.pages) { page in
                                Button {
                                    workspace.selectReviewPage(page.pageIndex)
                                } label: {
                                    VStack(spacing: 6) {
                                        ReviewPageImage(page: page)
                                            .frame(width: 88, height: 120)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(workspace.selectedReviewPageIndex == page.pageIndex ? Color.accentColor : Color.clear, lineWidth: 2)
                                            )
                                        Text(L10n.tr("score.review.page_number", page.pageIndex + 1))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                if let currentPage {
                    StudioPanel(title: L10n.tr("score.review.source_page"), systemImage: "photo") {
                        ReviewPageCanvas(
                            page: currentPage,
                            symbols: currentPageSymbols,
                            selectedSymbolID: workspace.selectedReviewSymbolID,
                            showOverlay: showSourceOverlay
                        ) { symbolID in
                            workspace.selectReviewSymbol(symbolID)
                        }
                    }
                }
            } else {
                StudioPanel(title: L10n.tr("score.review.source_page"), systemImage: "photo") {
                    ContentUnavailableView(
                        L10n.tr("score.review.no_source_page"),
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(L10n.tr("score.review.no_source_page_description"))
                    )
                }
            }
        }
    }
}

private struct SymbolicScoreReviewPanel: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    var score: ScoreDocument
    var reviewSession: ScoreReviewSession?
    var pageScale: Double
    var showPitchOverlay: Bool
    var showMeasureNumbers: Bool
    var isAnnotating: Bool
    var annotationTool: ScoreAnnotationTool
    var annotationLineWidth: Double
    @Binding var annotationStrokes: [ScoreAnnotationStrokePayload]
    @Binding var annotationDraft: [CGPoint]

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workspace.scoreSummary.title)
                            .font(.title2.bold())
                        Text(L10n.tr("score.review.symbolic_score"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(
                        isAnnotating ? L10n.tr("Annotation mode") : L10n.tr("score.review.review_mode"),
                        systemImage: isAnnotating ? "pencil.tip" : "music.note.house"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                }

                StudioPanel(title: L10n.tr("score.editor.rendered_score"), systemImage: "music.quarternote.3") {
                    VStack(alignment: .leading, spacing: 10) {
                        if let session = workspace.musicXMLEditorSession {
                            MusicXMLScoreWebView(
                                musicXMLString: session.musicXMLString,
                                selectedSymbolID: session.selectedSymbolID,
                                sourceName: session.sourceName
                            )
                            .frame(minHeight: 520)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            ContentUnavailableView(
                                L10n.tr("score.editor.no_musicxml_loaded"),
                                systemImage: "music.note.list",
                                description: Text(L10n.tr("score.editor.no_musicxml_loaded_description"))
                            )
                        }

                        Text(L10n.tr("score.editor.navigator_hint"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let part = workspace.selectedPart {
                    StudioPanel(title: L10n.tr("score.editor.symbol_navigator"), systemImage: "slider.horizontal.below.rectangle") {
                        VStack(alignment: .leading, spacing: 22) {
                            ForEach(part.measures) { measure in
                                StaffMeasureView(
                                    measure: measure,
                                    measureSymbols: symbols(for: part.id, measureNumber: measure.number),
                                    selectedSymbolID: workspace.selectedReviewSymbolID,
                                    ticksPerQuarter: score.ticksPerQuarter,
                                    showPitchOverlay: showPitchOverlay,
                                    showMeasureNumber: showMeasureNumbers
                                ) { symbolID in
                                    workspace.selectReviewSymbol(symbolID)
                                }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView(L10n.tr("No Part Selected"), systemImage: "music.note")
                }
            }
            .frame(width: 780 * pageScale, alignment: .topLeading)
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

    private func symbols(for partID: String, measureNumber: String) -> [ScoreReviewSymbol] {
        reviewSession?.symbols.filter {
            $0.partID == partID && $0.measureNumber == measureNumber
        } ?? []
    }
}

private struct ScoreInspectorPanel: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    var score: ScoreDocument
    @Binding var pageScale: Double
    @Binding var showPitchOverlay: Bool
    @Binding var showMeasureNumbers: Bool
    @Binding var showSourceOverlay: Bool
    @Binding var isAnnotating: Bool
    @Binding var annotationTool: ScoreAnnotationTool
    @Binding var annotationLineWidth: Double
    @Binding var annotationStrokes: [ScoreAnnotationStrokePayload]
    @Binding var annotationDraft: [CGPoint]
    @Binding var partVolumes: [String: Double]
    @Binding var mutedPartIDs: Set<String>
    @Binding var soloPartID: String?

    var body: some View {
        VStack(spacing: 14) {
            StudioPanel(title: L10n.tr("Parts"), systemImage: "rectangle.split.3x1") {
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
                                    Text(L10n.tr("%d measures", part.measures.count))
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
            }

            SelectedReviewSymbolPanel(workspace: workspace)

            if let benchmark = workspace.currentSampleBenchmarkResult {
                StudioPanel(title: L10n.tr("score.sample.benchmark_title"), systemImage: benchmark.passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill") {
                    VStack(alignment: .leading, spacing: 8) {
                        ValuePill(
                            title: L10n.tr("Status"),
                            value: benchmark.passed ? L10n.tr("score.sample.benchmark_passed") : L10n.tr("score.sample.benchmark_review_needed"),
                            systemImage: benchmark.passed ? "checkmark.circle" : "exclamationmark.circle"
                        )
                        ValuePill(title: L10n.tr("Measures"), value: "\(benchmark.actualMeasureCount)/\(benchmark.spec.expectedMeasureCount)", systemImage: "number")
                        ValuePill(title: L10n.tr("Playable Notes"), value: "\(benchmark.actualPlayableNoteCount)/\(benchmark.spec.expectedPlayableNoteCount)", systemImage: "music.note")
                        ValuePill(title: L10n.tr("text.pages"), value: "\(benchmark.actualPageCount)/\(benchmark.spec.expectedPageCount)", systemImage: "doc.richtext")
                    }
                }
            }

            StudioPanel(title: L10n.tr("score.review.review_summary"), systemImage: "checklist") {
                VStack(alignment: .leading, spacing: 8) {
                    ValuePill(title: L10n.tr("Measures"), value: "\(workspace.scoreSummary.measureCount)", systemImage: "number")
                    ValuePill(title: L10n.tr("Playable Notes"), value: "\(workspace.scoreSummary.playableNoteCount)", systemImage: "music.note")
                    ValuePill(title: L10n.tr("Tempo"), value: "\(score.tempoBPM) bpm", systemImage: "metronome")
                    ValuePill(title: L10n.tr("score.review.corrections"), value: "\(score.corrections.count)", systemImage: "square.and.pencil")
                }
            }

            if let correction = workspace.remoteOMRCorrectionContext {
                StudioPanel(title: L10n.tr("score.review.correction_submission"), systemImage: "checkmark.seal") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(
                            correction.trainingRecordID == nil
                                ? L10n.tr("score.review.correction_submission_description")
                                : L10n.tr("score.review.correction_submitted")
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        HStack(spacing: 10) {
                            Button(L10n.tr("score.review.save_progress")) {
                                workspace.saveCorrectionProgress()
                            }
                            .buttonStyle(.bordered)

                            Button(L10n.tr("score.review.complete_correction")) {
                                workspace.completeRemoteOMRCorrection()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(correction.trainingRecordID != nil || workspace.isCompletingRemoteOMRCorrection)
                        }
                    }
                }
            }

            StudioPanel(title: L10n.tr("Practice Display"), systemImage: "slider.horizontal.3") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.tr("Pitch overlay"), isOn: $showPitchOverlay)
                    Toggle(L10n.tr("Measure numbers"), isOn: $showMeasureNumbers)
                    Toggle(L10n.tr("score.review.show_source_overlay"), isOn: $showSourceOverlay)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(L10n.tr("Zoom"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $pageScale, in: 0.75...1.45, step: 0.05)
                    }
                }
            }

            StudioPanel(title: L10n.tr("Annotations"), systemImage: "pencil.and.outline") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(L10n.tr("Annotation mode"), isOn: $isAnnotating)

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
                        Text(L10n.tr("Line width"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $annotationLineWidth, in: 1.5...8, step: 0.5)
                    }

                    HStack {
                        Button {
                            annotationDraft.removeAll()
                            _ = annotationStrokes.popLast()
                        } label: {
                            Label(L10n.tr("Undo"), systemImage: "arrow.uturn.backward")
                        }
                        .disabled(annotationStrokes.isEmpty)

                        Button(role: .destructive) {
                            annotationDraft.removeAll()
                            annotationStrokes.removeAll()
                        } label: {
                            Label(L10n.tr("Clear"), systemImage: "trash")
                        }
                        .disabled(annotationStrokes.isEmpty)
                    }
                    .buttonStyle(.bordered)
                }
            }

            StudioPanel(title: L10n.tr("Mixer"), systemImage: "slider.vertical.3") {
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
                                .help(mutedPartIDs.contains(part.id) ? L10n.tr("Unmute") : L10n.tr("Mute"))

                                Button {
                                    soloPartID = soloPartID == part.id ? nil : part.id
                                } label: {
                                    Text("S")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(soloPartID == part.id ? Color.accentColor : Color.secondary)
                                }
                                .buttonStyle(.borderless)
                                .help(L10n.tr("Solo"))
                            }
                            Slider(value: bindingForVolume(part.id), in: 0...1)
                        }
                    }
                }
            }
        }
    }

    private func bindingForVolume(_ id: String) -> Binding<Double> {
        Binding(
            get: { partVolumes[id] ?? 0.82 },
            set: { partVolumes[id] = $0 }
        )
    }

    private func toggleMute(_ id: String) {
        if mutedPartIDs.contains(id) {
            mutedPartIDs.remove(id)
        } else {
            mutedPartIDs.insert(id)
        }
    }
}

private struct SelectedReviewSymbolPanel: View {
    @ObservedObject var workspace: VocalDiveWorkspace

    var body: some View {
        StudioPanel(title: L10n.tr("score.review.symbol_inspector"), systemImage: "slider.horizontal.below.square.filled.and.square") {
            if let symbol = workspace.selectedReviewSymbol, let score = workspace.score {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(symbol.kind.localizedDisplayName)
                            .font(.headline)
                        Spacer()
                        Text(L10n.tr("Measure %@", symbol.measureNumber))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let pageIndex = symbol.pageIndex {
                        Text(L10n.tr("score.review.page_number", pageIndex + 1))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    switch symbol.kind {
                    case .note, .rest, .lyric:
                        ReviewNoteInspector(workspace: workspace, score: score, symbol: symbol)
                            .id(symbol.id)
                    case .direction:
                        ReviewDirectionInspector(workspace: workspace, symbol: symbol)
                            .id(symbol.id)
                    case .clef, .keySignature, .timeSignature, .repeatStart, .repeatEnd:
                        ReviewMeasureInspector(workspace: workspace, symbol: symbol)
                            .id(symbol.id)
                    }
                }
            } else {
                ContentUnavailableView(
                    L10n.tr("score.review.no_symbol_selected"),
                    systemImage: "cursorarrow.click",
                    description: Text(L10n.tr("score.review.no_symbol_selected_description"))
                )
            }
        }
    }
}

private struct ReviewNoteInspector: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    let score: ScoreDocument
    let symbol: ScoreReviewSymbol
    @State private var isRest: Bool
    @State private var step: String
    @State private var alter: Int
    @State private var octave: Int
    @State private var noteType: String
    @State private var lyricText: String

    init(workspace: VocalDiveWorkspace, score: ScoreDocument, symbol: ScoreReviewSymbol) {
        self._workspace = ObservedObject(wrappedValue: workspace)
        self.score = score
        self.symbol = symbol
        let note = workspace.reviewNote(for: symbol)
        self._isRest = State(initialValue: note?.isRest ?? (symbol.kind == .rest))
        self._step = State(initialValue: note?.step ?? "C")
        self._alter = State(initialValue: note?.alter ?? 0)
        self._octave = State(initialValue: note?.octave ?? 4)
        self._noteType = State(initialValue: note?.noteType ?? "quarter")
        self._lyricText = State(initialValue: note?.lyrics.first?.text ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L10n.tr("score.review.is_rest"), isOn: $isRest)

            if !isRest {
                Picker(L10n.tr("Pitch"), selection: $step) {
                    ForEach(["C", "D", "E", "F", "G", "A", "B"], id: \.self) { value in
                        Text(value).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Stepper(L10n.tr("score.review.alter_value", alter), value: $alter, in: -2...2)
                Stepper(L10n.tr("score.review.octave_value", octave), value: $octave, in: 1...7)
            }

            Picker(L10n.tr("Value"), selection: $noteType) {
                ForEach(["whole", "half", "quarter", "eighth"], id: \.self) { value in
                    Text(value).tag(value)
                }
            }

            TextField(L10n.tr("score.review.lyric"), text: $lyricText)
                .textFieldStyle(.roundedBorder)

            Button {
                workspace.applyReviewNoteEdit(
                    symbol: symbol,
                    step: step,
                    alter: alter,
                    octave: octave,
                    noteType: noteType,
                    isRest: isRest,
                    lyricText: lyricText
                )
            } label: {
                Label(L10n.tr("score.review.apply_note_changes"), systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ReviewMeasureInspector: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    let symbol: ScoreReviewSymbol
    @State private var beats: Int
    @State private var beatType: Int
    @State private var keyFifths: Int
    @State private var clefSign: String
    @State private var clefLine: Int
    @State private var repeatStart: Bool
    @State private var repeatEnd: Bool

    init(workspace: VocalDiveWorkspace, symbol: ScoreReviewSymbol) {
        self._workspace = ObservedObject(wrappedValue: workspace)
        self.symbol = symbol
        let measure = workspace.reviewMeasure(for: symbol)
        self._beats = State(initialValue: measure?.beats ?? 4)
        self._beatType = State(initialValue: measure?.beatType ?? 4)
        self._keyFifths = State(initialValue: measure?.keyFifths ?? 0)
        self._clefSign = State(initialValue: measure?.clefSign ?? "G")
        self._clefLine = State(initialValue: measure?.clefLine ?? 2)
        self._repeatStart = State(initialValue: measure?.repeatStart ?? false)
        self._repeatEnd = State(initialValue: measure?.repeatEnd ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Stepper(L10n.tr("score.review.beats_value", beats), value: $beats, in: 1...12)
            Stepper(L10n.tr("score.review.beat_type_value", beatType), value: $beatType, in: 1...16)
            Stepper(L10n.tr("score.review.key_fifths_value", keyFifths), value: $keyFifths, in: -7...7)

            Picker(L10n.tr("score.review.clef_sign"), selection: $clefSign) {
                ForEach(["G", "F", "C"], id: \.self) { sign in
                    Text(sign).tag(sign)
                }
            }
            .pickerStyle(.segmented)

            Stepper(L10n.tr("score.review.clef_line_value", clefLine), value: $clefLine, in: 1...5)
            Toggle(L10n.tr("score.review.repeat_start"), isOn: $repeatStart)
            Toggle(L10n.tr("score.review.repeat_end"), isOn: $repeatEnd)

            Button {
                workspace.applyReviewMeasureEdit(
                    symbol: symbol,
                    beats: beats,
                    beatType: beatType,
                    keyFifths: keyFifths,
                    clefSign: clefSign,
                    clefLine: clefLine,
                    repeatStart: repeatStart,
                    repeatEnd: repeatEnd
                )
            } label: {
                Label(L10n.tr("score.review.apply_measure_changes"), systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ReviewDirectionInspector: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    let symbol: ScoreReviewSymbol
    @State private var directionText: String
    @State private var placement: String

    init(workspace: VocalDiveWorkspace, symbol: ScoreReviewSymbol) {
        self._workspace = ObservedObject(wrappedValue: workspace)
        self.symbol = symbol
        let direction = workspace.reviewDirection(for: symbol)
        self._directionText = State(initialValue: direction?.value ?? "")
        self._placement = State(initialValue: direction?.placement ?? "above")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField(L10n.tr("score.review.direction_text"), text: $directionText)
                .textFieldStyle(.roundedBorder)
            Picker(L10n.tr("score.review.direction_placement"), selection: $placement) {
                ForEach(["above", "below"], id: \.self) { value in
                    Text(value).tag(value)
                }
            }
            .pickerStyle(.segmented)

            Button {
                workspace.applyReviewDirectionEdit(
                    symbol: symbol,
                    value: directionText,
                    placement: placement
                )
            } label: {
                Label(L10n.tr("score.review.apply_direction_changes"), systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

private struct ReviewPageCanvas: View {
    var page: ScoreReviewPage
    var symbols: [ScoreReviewSymbol]
    var selectedSymbolID: String?
    var showOverlay: Bool
    var onSelect: (String?) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = fittedSize(in: proxy.size)

            ZStack(alignment: .topLeading) {
                ReviewPageImage(page: page)
                    .frame(width: size.width, height: size.height)

                if showOverlay {
                    ForEach(symbols) { symbol in
                        if let rect = symbol.bounds {
                            let overlayRect = denormalized(rect, in: size)
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(selectedSymbolID == symbol.id ? Color.accentColor : overlayColor(for: symbol.kind), lineWidth: selectedSymbolID == symbol.id ? 3 : 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill((selectedSymbolID == symbol.id ? Color.accentColor : overlayColor(for: symbol.kind)).opacity(selectedSymbolID == symbol.id ? 0.12 : 0.04))
                                )
                                .frame(width: overlayRect.width, height: overlayRect.height)
                                .position(x: overlayRect.midX, y: overlayRect.midY)
                                .onTapGesture {
                                    onSelect(symbol.id)
                                }
                        }
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
    }

    private func fittedSize(in container: CGSize) -> CGSize {
        let aspect = CGFloat(page.pixelWidth) / CGFloat(max(page.pixelHeight, 1))
        let width = min(container.width, 280)
        let height = width / max(aspect, 0.1)
        return CGSize(width: width, height: height)
    }

    private func denormalized(_ rect: NativeOMRNormalizedRect, in size: CGSize) -> CGRect {
        CGRect(
            x: rect.x * size.width,
            y: rect.y * size.height,
            width: rect.width * size.width,
            height: rect.height * size.height
        )
    }

    private func overlayColor(for kind: ScoreReviewSymbolKind) -> Color {
        switch kind {
        case .note, .rest:
            return .blue
        case .lyric:
            return .green
        case .direction:
            return .orange
        case .clef, .keySignature, .timeSignature:
            return .purple
        case .repeatStart, .repeatEnd:
            return .pink
        }
    }
}

private struct ReviewPageImage: View {
    var page: ScoreReviewPage

    var body: some View {
        Group {
            if let image = AppPlatformImage(data: page.imageData) {
                PlatformImageView(image: image)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    )
            }
        }
    }
}

private struct VectorAnnotationLayer: View {
    @Binding var strokes: [ScoreAnnotationStrokePayload]
    @Binding var draft: [CGPoint]
    var tool: ScoreAnnotationTool
    var lineWidth: Double

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                for stroke in strokes {
                    draw(stroke.points.map { CGPoint(x: $0.x, y: $0.y) }, in: size, context: &context, stroke: stroke)
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
        stroke: ScoreAnnotationStrokePayload
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
            with: .color(Color(
                red: stroke.red,
                green: stroke.green,
                blue: stroke.blue
            ).opacity(stroke.opacity)),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }

    private func makeStroke(points: [CGPoint]) -> ScoreAnnotationStrokePayload {
        let normalizedPoints = points.map {
            AnnotationPointPayload(x: $0.x, y: $0.y)
        }
        switch tool {
        case .pen:
            return ScoreAnnotationStrokePayload(
                points: normalizedPoints,
                red: 1,
                green: 0,
                blue: 0,
                opacity: 0.88,
                lineWidth: lineWidth
            )
        case .highlighter:
            return ScoreAnnotationStrokePayload(
                points: normalizedPoints,
                red: 1,
                green: 0.92,
                blue: 0.1,
                opacity: 0.34,
                lineWidth: max(lineWidth * 3.2, 12)
            )
        case .eraser:
            return ScoreAnnotationStrokePayload(
                points: normalizedPoints,
                red: 0,
                green: 0,
                blue: 0,
                opacity: 0,
                lineWidth: lineWidth
            )
        }
    }

    private func erase(near point: CGPoint) {
        let threshold: CGFloat = 0.018
        strokes.removeAll { stroke in
            stroke.points.contains { payload in
                distance(CGPoint(x: payload.x, y: payload.y), point) < threshold
            }
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
    var measureSymbols: [ScoreReviewSymbol]
    var selectedSymbolID: String?
    var ticksPerQuarter: Int
    var showPitchOverlay: Bool
    var showMeasureNumber: Bool
    var onSelectSymbol: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if showMeasureNumber {
                    Text(L10n.tr("Measure %@", measure.number))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                MeasureSymbolStrip(
                    measure: measure,
                    symbols: measureSymbols,
                    selectedSymbolID: selectedSymbolID,
                    onSelectSymbol: onSelectSymbol
                )
            }

            if !measure.directions.isEmpty {
                HStack(spacing: 6) {
                    ForEach(measure.directions) { direction in
                        let symbol = measureSymbols.first(where: { $0.directionID == direction.id })
                        Button {
                            if let symbol {
                                onSelectSymbol(symbol.id)
                            }
                        } label: {
                            Text(direction.value)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background((selectedSymbolID == symbol?.id ? Color.accentColor : .yellow).opacity(selectedSymbolID == symbol?.id ? 0.18 : 0.22), in: RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
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
                        let noteSymbol = measureSymbols.first(where: { $0.noteID == note.id && ($0.kind == .note || $0.kind == .rest) })
                        let lyricSymbol = measureSymbols.first(where: { $0.noteID == note.id && $0.kind == .lyric })

                        NoteGlyph(
                            note: note,
                            ticksPerQuarter: ticksPerQuarter,
                            showPitchOverlay: showPitchOverlay,
                            isSelected: selectedSymbolID == noteSymbol?.id || selectedSymbolID == lyricSymbol?.id,
                            lyricSelected: selectedSymbolID == lyricSymbol?.id,
                            onSelectNote: {
                                if let noteSymbol {
                                    onSelectSymbol(noteSymbol.id)
                                }
                            },
                            onSelectLyric: {
                                if let lyricSymbol {
                                    onSelectSymbol(lyricSymbol.id)
                                } else if let noteSymbol {
                                    onSelectSymbol(noteSymbol.id)
                                }
                            }
                        )
                        .position(x: xPosition(index: index, width: proxy.size.width), y: yPosition(note: note, height: proxy.size.height))
                    }
                }
            }
            .frame(height: 96)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(measureSymbols.contains(where: { $0.id == selectedSymbolID }) ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1.5)
                )
        )
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

private struct MeasureSymbolStrip: View {
    var measure: ScoreMeasure
    var symbols: [ScoreReviewSymbol]
    var selectedSymbolID: String?
    var onSelectSymbol: (String) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if let symbol = symbols.first(where: { $0.kind == .clef }) {
                miniButton(label: "Clef \(measure.clefSign ?? "G")\(measure.clefLine ?? 2)", symbolID: symbol.id)
            }
            if let symbol = symbols.first(where: { $0.kind == .keySignature }) {
                miniButton(label: "Key \(measure.keyFifths ?? 0)", symbolID: symbol.id)
            }
            if let symbol = symbols.first(where: { $0.kind == .timeSignature }) {
                miniButton(label: "\(measure.beats ?? 4)/\(measure.beatType ?? 4)", symbolID: symbol.id)
            }
            if let symbol = symbols.first(where: { $0.kind == .repeatStart }) {
                miniButton(label: "|:", symbolID: symbol.id)
            }
            if let symbol = symbols.first(where: { $0.kind == .repeatEnd }) {
                miniButton(label: ":|", symbolID: symbol.id)
            }
        }
    }

    private func miniButton(label: String, symbolID: String) -> some View {
        Button {
            onSelectSymbol(symbolID)
        } label: {
            Text(label)
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background((selectedSymbolID == symbolID ? Color.accentColor : Color.secondary).opacity(selectedSymbolID == symbolID ? 0.16 : 0.12), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

private struct NoteGlyph: View {
    var note: ScoreNote
    var ticksPerQuarter: Int
    var showPitchOverlay: Bool
    var isSelected: Bool
    var lyricSelected: Bool
    var onSelectNote: () -> Void
    var onSelectLyric: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Button(action: onSelectNote) {
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
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                        .frame(width: noteWidth + 10, height: 24)
                )
            }
            .buttonStyle(.plain)

            Text(ScoreFormatting.noteName(note))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .lineLimit(1)
            if let lyricText = note.lyrics.first?.text {
                Button(action: onSelectLyric) {
                    Text(lyricText)
                        .font(.caption2)
                        .foregroundStyle(lyricSelected ? Color.accentColor : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 3)
                        .background((lyricSelected ? Color.accentColor : .clear).opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
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

#if canImport(WebKit)
private struct MusicXMLScoreWebView: View {
    var musicXMLString: String
    var selectedSymbolID: String?
    var sourceName: String

    var body: some View {
        MusicXMLScoreWebViewRepresentable(
            musicXMLString: musicXMLString,
            selectedSymbolID: selectedSymbolID,
            sourceName: sourceName
        )
        .background(.white)
    }
}

#if os(iOS)
private struct MusicXMLScoreWebViewRepresentable: UIViewRepresentable {
    var musicXMLString: String
    var selectedSymbolID: String?
    var sourceName: String

    func makeCoordinator() -> MusicXMLScoreWebViewCoordinator {
        MusicXMLScoreWebViewCoordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(
            webView: webView,
            musicXMLString: musicXMLString,
            selectedSymbolID: selectedSymbolID,
            sourceName: sourceName
        )
    }
}
#elseif os(macOS)
private struct MusicXMLScoreWebViewRepresentable: NSViewRepresentable {
    var musicXMLString: String
    var selectedSymbolID: String?
    var sourceName: String

    func makeCoordinator() -> MusicXMLScoreWebViewCoordinator {
        MusicXMLScoreWebViewCoordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.render(
            webView: webView,
            musicXMLString: musicXMLString,
            selectedSymbolID: selectedSymbolID,
            sourceName: sourceName
        )
    }
}
#endif

private final class MusicXMLScoreWebViewCoordinator: NSObject, WKNavigationDelegate {
    private var didLoadShell = false
    private var lastRenderedXML: String?
    private var pendingXML: String?
    private var pendingSelectedSymbolID: String?
    private var pendingSourceName: String?

    func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        #if os(iOS)
        webView.isOpaque = false
        #endif
        webView.setValue(false, forKey: "drawsBackground")
        loadShell(into: webView)
        return webView
    }

    func render(webView: WKWebView, musicXMLString: String, selectedSymbolID: String?, sourceName: String) {
        pendingXML = musicXMLString
        pendingSelectedSymbolID = selectedSymbolID
        pendingSourceName = sourceName

        guard didLoadShell else {
            return
        }

        if lastRenderedXML != musicXMLString {
            lastRenderedXML = musicXMLString
            let escapedXML = jsonEscaped(musicXMLString)
            let escapedTitle = jsonEscaped(sourceName)
            webView.evaluateJavaScript("window.vocaldiveRenderScore(\(escapedXML), \(escapedTitle));")
        }

        let escapedSelection = jsonEscaped(selectedSymbolID ?? "")
        webView.evaluateJavaScript("window.vocaldiveSetSelection(\(escapedSelection));")
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        didLoadShell = true
        if let pendingXML, let pendingSourceName {
            render(
                webView: webView,
                musicXMLString: pendingXML,
                selectedSymbolID: pendingSelectedSymbolID,
                sourceName: pendingSourceName
            )
        }
    }

    private func loadShell(into webView: WKWebView) {
        guard let htmlURL = AppResourceLocator.url(forResource: "musicxml-editor", withExtension: "html", subdirectory: "OSMD") else {
            webView.loadHTMLString("<html><body><p>Missing MusicXML editor resource.</p></body></html>", baseURL: nil)
            return
        }
        webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
    }

    private func jsonEscaped(_ value: String) -> String {
        let data = try? JSONEncoder().encode(value)
        return String(data: data ?? Data("".utf8), encoding: .utf8) ?? "\"\""
    }
}
#else
private struct MusicXMLScoreWebView: View {
    var musicXMLString: String
    var selectedSymbolID: String?
    var sourceName: String

    var body: some View {
        Text(L10n.tr("score.editor.webview_unavailable"))
    }
}
#endif

#if os(iOS)
private typealias AppPlatformImage = UIImage
#elseif os(macOS)
private typealias AppPlatformImage = NSImage
#endif

private struct PlatformImageView: View {
    var image: AppPlatformImage

    var body: some View {
        #if os(iOS)
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #elseif os(macOS)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
        #endif
    }
}

private extension ScoreReviewSymbolKind {
    var localizedDisplayName: String {
        switch self {
        case .note:
            return L10n.tr("score.review.symbol.note")
        case .rest:
            return L10n.tr("score.review.symbol.rest")
        case .lyric:
            return L10n.tr("score.review.symbol.lyric")
        case .clef:
            return L10n.tr("score.review.symbol.clef")
        case .keySignature:
            return L10n.tr("score.review.symbol.key_signature")
        case .timeSignature:
            return L10n.tr("score.review.symbol.time_signature")
        case .direction:
            return L10n.tr("score.review.symbol.direction")
        case .repeatStart:
            return L10n.tr("score.review.symbol.repeat_start")
        case .repeatEnd:
            return L10n.tr("score.review.symbol.repeat_end")
        }
    }
}
