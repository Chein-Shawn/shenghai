import Foundation
import Combine
import UniformTypeIdentifiers
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

enum ScoreLandingMode: String, CaseIterable, Identifiable {
    case editor
    case scan

    var id: String { rawValue }
}

enum ScoreImportFlow {
    case musicXML
    case scan
}

struct RemoteOMRUploadDisclosure: Identifiable {
    let id = UUID()
    let sourceCount: Int
}

@MainActor
final class VocalDiveWorkspace: ObservableObject {
    @Published var selectedSection: AppSection = .dashboard {
        didSet {
            usageTracking.switchTo(selectedSection.usageFeature)
        }
    }
    @Published var score: ScoreDocument?
    @Published var selectedPartID: String?
    @Published var statusMessage = L10n.tr("Ready for MusicXML prototype testing.")
    @Published var errorMessage: String?
    @Published var exportedMIDIURL: URL?
    @Published var exportedMusicXMLURL: URL?
    @Published var isImportingScore = false
    @Published var isPlaying = false
    @Published var scanProgress: NativeOMRScanProgress?
    @Published var scannedMusicXMLCandidate: OMRMusicXMLCandidate?
    @Published var latestNativeOMRSession: NativeOMRPrototypeSessionResult?
    @Published var scoreReviewSession: ScoreReviewSession?
    @Published var musicXMLEditorSession: MusicXMLEditorSession?
    @Published var selectedReviewPageIndex = 0
    @Published var selectedReviewSymbolID: String?
    @Published var currentScoreItemID: String?
    @Published var compactScoreMode: ScoreHubMode = .editor
    @Published var scoreLandingMode: ScoreLandingMode = .editor
    @Published var pendingScoreImportFlow: ScoreImportFlow = .musicXML
    @Published var currentSampleBenchmarkResult: SampleBenchmarkResult?
    @Published var annotationStrokes: [ScoreAnnotationStrokePayload] = [] {
        didSet {
            guard annotationPersistenceEnabled, let currentScoreItemID else {
                return
            }
            persistence.saveAnnotationStrokes(annotationStrokes, for: currentScoreItemID)
        }
    }
    @Published var syncStatus: SyncStatusSnapshot
    @Published var isSyncEnabled: Bool
    @Published var shouldPromptForSyncChoice = false
    let usageTracking: UsageTrackingStore

    private let importer = MusicXMLImporter()
    private let nativeOMRPrototypeService = NativeOMRPrototypeService()
    private let remoteOMRService = RemoteOMRService()
    @Published var remoteOMRUploadDisclosure: RemoteOMRUploadDisclosure?
    private var pendingRemoteOMRURLs: [URL] = []
    private var pendingRemoteOMRSourceKind: MusicXMLEditorSourceKind?
    private var pendingRemoteOMRSecurityScopedURLs: [URL] = []
    private let playbackService = MIDIPlaybackService()
    private let persistence: PersistenceCoordinator
    private var annotationPersistenceEnabled = true
    private var hasBootstrapped = false

    init(persistence: PersistenceCoordinator = .shared) {
        self.persistence = persistence
        self.usageTracking = UsageTrackingStore(persistence: persistence)
        let settings = persistence.settingsSnapshot()
        self.syncStatus = persistence.syncStatusSnapshot()
        self.isSyncEnabled = settings.syncEnabled
    }

    var selectedPartIndex: Int {
        guard let score, let selectedPartID else {
            return 0
        }
        return score.parts.firstIndex { $0.id == selectedPartID } ?? 0
    }

    var selectedPart: ScorePart? {
        guard let score, !score.parts.isEmpty else {
            return nil
        }
        return score.parts.indices.contains(selectedPartIndex) ? score.parts[selectedPartIndex] : score.parts.first
    }

    var scoreSummary: ScoreSummary {
        ScoreSummary(score: score, selectedPart: selectedPart)
    }

    func loadDemoScore() {
        loadSampleGroundTruth()
    }

    func loadSampleGroundTruth() {
        do {
            let pack = try SampleScoreLibrary.bundledTwinklePack()
            let data = Data(pack.groundTruthMusicXML.utf8)
            let importedScore = try importer.importDocument(data: data)
            let scoreItemID = try persistence.persistScoreDocument(
                score: importedScore,
                data: data,
                sourceType: .demo,
                preferredFileName: importedScore.metadata.title ?? "twinkle-ground-truth"
            )
            setScore(importedScore, scoreItemID: scoreItemID)
            latestNativeOMRSession = nil
            refreshReviewArtifacts(
                sourceName: importedScore.metadata.title ?? "twinkle-ground-truth",
                inputKind: .musicXML,
                pages: pack.intactPages
            )
            refreshEditorSession(
                sourceKind: .sampleIntact,
                sourceName: pack.displayName,
                musicXMLString: pack.groundTruthMusicXML
            )
            currentSampleBenchmarkResult = SampleScoreLibrary.verify(
                score: importedScore,
                pageCount: pack.intactPages.count,
                spec: pack.benchmark
            )
            statusMessage = L10n.tr("score.sample.loaded_ground_truth")
            errorMessage = nil
            compactScoreMode = .editor
            scoreLandingMode = .editor
            selectedSection = .scoreWorkspace
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runSampleIntactOMR() {
        do {
            let pack = try SampleScoreLibrary.bundledTwinklePack()
            runRemoteOMRImport(urls: [pack.intactPDFURL], sourceKind: .sampleIntact)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runSampleScannedOMR() {
        do {
            let pack = try SampleScoreLibrary.bundledTwinklePack()
            runRemoteOMRImport(urls: [pack.scannedPDFURL], sourceKind: .sampleScanned)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importMusicXML(url: URL) {
        do {
            let didStartAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            let importedScore = try importer.importDocument(data: data)
            let scoreItemID = try persistence.persistScoreDocument(
                score: importedScore,
                data: data,
                sourceType: .musicXML,
                preferredFileName: url.deletingPathExtension().lastPathComponent
            )
            setScore(importedScore, scoreItemID: scoreItemID)
            createScanReviewCandidate(sourceName: url.lastPathComponent, inputKind: .musicXML)
            refreshReviewArtifacts(sourceName: url.lastPathComponent, inputKind: .musicXML)
            refreshEditorSession(
                sourceKind: .directMusicXML,
                sourceName: url.lastPathComponent,
                musicXMLString: String(decoding: data, as: UTF8.self)
            )
            currentSampleBenchmarkResult = nil
            statusMessage = L10n.tr("Imported %@.", url.lastPathComponent)
            errorMessage = nil
            compactScoreMode = .editor
            scoreLandingMode = .editor
            selectedSection = .scoreWorkspace
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importMusicXMLText(_ musicXML: String, sourceName: String = "Pasted MusicXML") {
        let trimmed = musicXML.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = L10n.tr("score.editor.empty_musicxml")
            return
        }

        do {
            let data = Data(trimmed.utf8)
            let importedScore = try importer.importDocument(data: data)
            let scoreItemID = try persistence.persistScoreDocument(
                score: importedScore,
                data: data,
                sourceType: .musicXML,
                preferredFileName: sourceName
            )
            setScore(importedScore, scoreItemID: scoreItemID)
            refreshReviewArtifacts(sourceName: sourceName, inputKind: .musicXML)
            refreshEditorSession(
                sourceKind: .directMusicXML,
                sourceName: sourceName,
                musicXMLString: trimmed
            )
            currentSampleBenchmarkResult = nil
            statusMessage = L10n.tr("score.editor.loaded_pasted_musicxml")
            errorMessage = nil
            compactScoreMode = .editor
            scoreLandingMode = .editor
            selectedSection = .scoreWorkspace
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importScoreFile(url: URL) {
        importScoreFiles(urls: [url])
    }

    func importScoreFiles(urls: [URL]) {
        guard let firstURL = urls.first else {
            return
        }
        if urls.count > 1 {
            requestRemoteOMRImport(urls: urls, sourceKind: .scanCandidate)
            return
        }
        let url = firstURL
        let lowercasedExtension = url.pathExtension.lowercased()

        if ["xml", "musicxml", "mxl"].contains(lowercasedExtension) {
            importMusicXML(url: url)
            return
        }

        if lowercasedExtension == "pdf" {
            requestRemoteOMRImport(urls: [url], sourceKind: .scanCandidate)
            return
        }

        if let type = UTType(filenameExtension: lowercasedExtension),
           type.conforms(to: .image) {
            requestRemoteOMRImport(urls: [url], sourceKind: .scanCandidate)
            return
        }

        errorMessage = L10n.tr("score.editor.unsupported_import")
    }

    func startMusicXMLImport() {
        pendingScoreImportFlow = .musicXML
        scoreLandingMode = .editor
        isImportingScore = true
    }

    func startScanImport() {
        pendingScoreImportFlow = .scan
        scoreLandingMode = .scan
        isImportingScore = true
    }

    func exportCurrentMusicXML() {
        guard let score else {
            errorMessage = L10n.tr("Load or import a MusicXML score first.")
            return
        }

        do {
            let xml = MusicXMLComposer.makeMusicXML(from: score)
            let title = score.metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeName = (title?.isEmpty == false ? title! : "VocalDive-Score")
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(safeName.isEmpty ? "VocalDive-Score" : safeName).musicxml")
            try xml.write(to: url, atomically: true, encoding: .utf8)
            exportedMusicXMLURL = url
            statusMessage = L10n.tr("score.editor.exported_current_musicxml")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportMIDI() {
        guard let score else {
            errorMessage = L10n.tr("Load or import a MusicXML score first.")
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "VocalDive-\(UUID().uuidString.prefix(8)).mid")
            try MIDIWriter.writeMIDI(score: score, to: url, partIndex: selectedPartIndex)
            exportedMIDIURL = url
            statusMessage = L10n.tr("Exported MIDI for %@.", selectedPart?.name ?? L10n.tr("selected part"))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createScanReviewCandidate(sourceName: String = "Current scanned score", inputKind: OMRInputKind = .image) {
        guard let score else {
            errorMessage = L10n.tr("Load or import a MusicXML candidate first.")
            return
        }

        scannedMusicXMLCandidate = OMRMusicXMLCandidateBuilder.makeCandidate(
            sourceName: sourceName,
            inputKind: inputKind,
            provider: .nativePrototype,
            score: score
        )
        statusMessage = L10n.tr("Created editable MusicXML review candidate.")
        errorMessage = nil
    }

    func loadComposedScore(_ composedScore: ComposedScore) {
        let normalizedScore = composedScore.applyingLocalizedFallbacks()
        let generatedScore = MusicXMLComposer.makeScoreDocument(from: normalizedScore)
        do {
            let xml = MusicXMLComposer.makeMusicXML(from: normalizedScore)
            let scoreItemID = try persistence.persistScoreDocument(
                score: generatedScore,
                data: Data(xml.utf8),
                sourceType: .composed,
                preferredFileName: normalizedScore.title
            )
            setScore(generatedScore, scoreItemID: scoreItemID)
            refreshReviewArtifacts(sourceName: normalizedScore.title, inputKind: .musicXML)
            refreshEditorSession(
                sourceKind: .directMusicXML,
                sourceName: normalizedScore.title,
                musicXMLString: xml
            )
            currentSampleBenchmarkResult = nil
            statusMessage = L10n.tr("Created %d notes from Compose.", normalizedScore.notes.count)
            errorMessage = nil
            compactScoreMode = .editor
            scoreLandingMode = .editor
            selectedSection = .scoreWorkspace
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportMusicXML(_ composedScore: ComposedScore) {
        do {
            let normalizedScore = composedScore.applyingLocalizedFallbacks()
            let fileName = normalizedScore.title
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty ? "VocalDive-Composition" : normalizedScore.title
            let safeName = fileName
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(safeName.isEmpty ? "VocalDive-Composition" : safeName).musicxml")
            let xml = MusicXMLComposer.makeMusicXML(from: normalizedScore)
            try xml.write(to: url, atomically: true, encoding: .utf8)
            exportedMusicXMLURL = url
            statusMessage = L10n.tr("Exported MusicXML: %@.", url.lastPathComponent)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playOrStop() {
        if isPlaying {
            playbackService.stop()
            isPlaying = false
            statusMessage = L10n.tr("Playback stopped.")
            return
        }

        guard let score else {
            errorMessage = L10n.tr("Load or import a MusicXML score first.")
            return
        }

        do {
            let midiData = MIDIWriter.makeMIDIData(score: score, partIndex: selectedPartIndex)
            isPlaying = true
            try playbackService.play(data: midiData) { [weak self] in
                self?.isPlaying = false
                self?.statusMessage = L10n.tr("Playback finished.")
            }
            statusMessage = L10n.tr("Playing %@.", selectedPart?.name ?? L10n.tr("selected part"))
            errorMessage = nil
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    func runNativeOMRImport(url: URL) {
        requestRemoteOMRImport(urls: [url], sourceKind: .scanCandidate)
    }

    func confirmRemoteOMRUpload() {
        let urls = pendingRemoteOMRURLs
        let sourceKind = pendingRemoteOMRSourceKind
        let securityScopedURLs = pendingRemoteOMRSecurityScopedURLs
        clearPendingRemoteOMRUpload(stopAccessing: false)
        UserDefaults.standard.set(true, forKey: "vocaldive.remoteOMR.upload-confirmed")
        guard let sourceKind else { return }
        runRemoteOMRImport(urls: urls, sourceKind: sourceKind, alreadyAccessedURLs: securityScopedURLs)
    }

    func cancelRemoteOMRUpload() {
        clearPendingRemoteOMRUpload(stopAccessing: true)
    }

    private func requestRemoteOMRImport(urls: [URL], sourceKind: MusicXMLEditorSourceKind) {
        guard urls.isEmpty == false else { return }
        guard UserDefaults.standard.bool(forKey: "vocaldive.remoteOMR.upload-confirmed") == false else {
            runRemoteOMRImport(urls: urls, sourceKind: sourceKind)
            return
        }
        clearPendingRemoteOMRUpload(stopAccessing: true)
        pendingRemoteOMRURLs = urls
        pendingRemoteOMRSourceKind = sourceKind
        pendingRemoteOMRSecurityScopedURLs = urls.filter { $0.startAccessingSecurityScopedResource() }
        remoteOMRUploadDisclosure = RemoteOMRUploadDisclosure(sourceCount: urls.count)
    }

    private func clearPendingRemoteOMRUpload(stopAccessing: Bool) {
        if stopAccessing {
            pendingRemoteOMRSecurityScopedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
        }
        pendingRemoteOMRURLs = []
        pendingRemoteOMRSourceKind = nil
        pendingRemoteOMRSecurityScopedURLs = []
        remoteOMRUploadDisclosure = nil
    }

    private func runRemoteOMRImport(
        urls: [URL],
        sourceKind: MusicXMLEditorSourceKind,
        alreadyAccessedURLs: [URL] = []
    ) {
        guard urls.isEmpty == false else {
            return
        }
        let sourceName = urls.count == 1 ? urls[0].lastPathComponent : L10n.tr("score.scan.image_batch", urls.count)
        statusMessage = L10n.tr("score.scan.remote_connecting", sourceName)
        errorMessage = nil
        scanProgress = .make(.connectingToServer, fraction: 0.01)

        Task { [weak self] in
            let accessedURLs = alreadyAccessedURLs.isEmpty
                ? urls.filter { $0.startAccessingSecurityScopedResource() }
                : alreadyAccessedURLs
            defer {
                accessedURLs.forEach { $0.stopAccessingSecurityScopedResource() }
            }
            do {
                guard let self else { return }
                let session = try await remoteOMRService.makeSession(from: urls) { [weak self] progress, detail in
                    self?.scanProgress = progress
                    self?.statusMessage = self?.localizedRemoteScanProgress(
                        progress,
                        sourceName: sourceName,
                        detail: detail
                    ) ?? ""
                }
                try self.finishRemoteOMRImport(session: session, sourceKind: sourceKind)
            } catch {
                self?.scanProgress = nil
                self?.latestNativeOMRSession = nil
                self?.scannedMusicXMLCandidate = nil
                self?.errorMessage = L10n.tr("score.scan.remote_failed_vocaldive", error.localizedDescription)
            }
        }
    }

    private func finishRemoteOMRImport(
        session: RemoteOMRCompletedSession,
        sourceKind: MusicXMLEditorSourceKind
    ) throws {
        let musicXMLData = Data(session.generatedMusicXML.utf8)
        let importedScore = try importer.importDocument(data: musicXMLData)
        let scoreItemID = try persistence.persistScoreDocument(
            score: importedScore,
            data: musicXMLData,
            sourceType: .musicXML,
            preferredFileName: session.sourceName
        )
        setScore(importedScore, scoreItemID: scoreItemID)
        let reviewPages = session.renderedPages.map {
            ScoreReviewPage(
                pageIndex: $0.pageIndex,
                pixelWidth: $0.pixelWidth,
                pixelHeight: $0.pixelHeight,
                imageData: $0.imageData,
                status: .recognized
            )
        }
        refreshReviewArtifacts(
            sourceName: session.sourceName,
            inputKind: session.inputKind,
            pages: reviewPages,
            provider: .oemer
        )
        refreshEditorSession(
            sourceKind: sourceKind,
            sourceName: session.sourceName,
            musicXMLString: session.generatedMusicXML
        )
        currentSampleBenchmarkResult = nil
        scanProgress = .make(.finished, fraction: 1, completedPages: reviewPages.count, totalPages: reviewPages.count)
        statusMessage = L10n.tr("score.scan.remote_completed_vocaldive", reviewPages.count)
        errorMessage = nil
        compactScoreMode = .editor
        scoreLandingMode = .scan
        selectedSection = .scoreWorkspace
    }

    private func runLegacyNativeOMRImport(url: URL) {
        do {
            try runNativeOMRImport(url: url, sourceKind: .scanCandidate)
        } catch {
            scanProgress = nil
            latestNativeOMRSession = nil
            scannedMusicXMLCandidate = nil
            errorMessage = L10n.tr("score.native_omr.failed", error.localizedDescription)
        }
    }

    private func runNativeOMRImport(url: URL, sourceKind: MusicXMLEditorSourceKind) throws {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        statusMessage = L10n.tr("score.native_omr.processing", url.lastPathComponent)
        errorMessage = nil
        scanProgress = .make(.preparing, fraction: 0.01)

        let session = try nativeOMRPrototypeService.makeSession(from: url) { [weak self] progress in
            self?.scanProgress = progress
            self?.statusMessage = self?.localizedScanProgress(progress, sourceName: url.lastPathComponent) ?? ""
        }
        let musicXMLData = Data(session.generatedMusicXML.utf8)
        let importedScore = try importer.importDocument(data: musicXMLData)
        let scoreItemID = try persistence.persistScoreDocument(
            score: importedScore,
            data: musicXMLData,
            sourceType: .musicXML,
            preferredFileName: session.sourceName
        )
        latestNativeOMRSession = session
        setScore(importedScore, scoreItemID: scoreItemID)
        scannedMusicXMLCandidate = OMRMusicXMLCandidateBuilder.makeCandidate(
            sourceName: url.lastPathComponent,
            inputKind: session.inputKind,
            provider: .nativePrototype,
            score: importedScore
        )
        let reviewPages = session.renderedPages.map { page in
            ScoreReviewPage(
                pageIndex: page.pageIndex,
                pixelWidth: page.pixelWidth,
                pixelHeight: page.pixelHeight,
                imageData: page.imageData,
                status: session.scoreNotation.pageResults.first(where: { $0.pageIndex == page.pageIndex })?.status ?? .recognized
            )
        }
        refreshReviewArtifacts(
            sourceName: url.lastPathComponent,
            inputKind: session.inputKind,
            pages: reviewPages,
            scoreNotation: session.scoreNotation
        )
        refreshEditorSession(
            sourceKind: sourceKind,
            sourceName: url.lastPathComponent,
            musicXMLString: session.generatedMusicXML
        )

        if let pack = try? SampleScoreLibrary.bundledTwinklePack(),
           sourceKind == .sampleIntact || sourceKind == .sampleScanned {
            currentSampleBenchmarkResult = SampleScoreLibrary.verify(
                score: importedScore,
                pageCount: reviewPages.count,
                spec: pack.benchmark
            )
        } else {
            currentSampleBenchmarkResult = nil
        }

        if session.scoreNotation.failedPageIndices.isEmpty {
            statusMessage = L10n.tr(
                "score.native_omr.completed",
                session.scoreNotation.pageResults.count
            )
            errorMessage = nil
        } else {
            statusMessage = L10n.tr(
                "score.native_omr.completed_with_review",
                session.scoreNotation.pageResults.count,
                session.scoreNotation.failedPageIndices.count
            )
            errorMessage = L10n.tr(
                "score.native_omr.review_needed",
                session.scoreNotation.failedPageIndices.map { String($0 + 1) }.joined(separator: ", ")
            )
        }

        compactScoreMode = .editor
        scoreLandingMode = .scan
        selectedSection = .scoreWorkspace
    }

    private func localizedScanProgress(_ progress: NativeOMRScanProgress, sourceName: String) -> String {
        let percent = Int((progress.fraction * 100).rounded())
        let phase = L10n.tr(progress.phase.localizationKey)
        if progress.totalPages > 0 {
            return L10n.tr(
                "score.scan.progress.with_pages",
                percent,
                phase,
                progress.completedPages,
                progress.totalPages,
                sourceName
            )
        }
        return L10n.tr("score.scan.progress.simple", percent, phase, sourceName)
    }

    private func localizedRemoteScanProgress(
        _ progress: NativeOMRScanProgress,
        sourceName: String,
        detail: String
    ) -> String {
        let base = localizedScanProgress(progress, sourceName: sourceName)
        return detail.isEmpty ? base : "\(base) - \(detail)"
    }

    func bootstrapIfNeeded() {
        guard !hasBootstrapped else {
            return
        }
        hasBootstrapped = true

        appSettingsReload()
        usageTracking.reloadFromPersistence()
        syncStatus = persistence.syncStatusSnapshot()
        isSyncEnabled = persistence.settingsSnapshot().syncEnabled
        shouldPromptForSyncChoice = persistence.settingsSnapshot().didChooseSyncOnLaunch == false

        if let restored = try? persistence.loadPersistedScore() {
            setScore(restored.score, scoreItemID: restored.scoreItemID, annotationStrokes: restored.annotationStrokes)
            statusMessage = L10n.tr("score.restore_previous_session")
            errorMessage = nil
        }

        Task { [weak self] in
            guard let self else { return }
            let recovered = await remoteOMRService.resumePending { [weak self] progress, detail in
                guard let self else { return }
                self.scanProgress = progress
                self.statusMessage = self.localizedRemoteScanProgress(progress, sourceName: "", detail: detail)
            }
            for result in recovered {
                try? self.finishRemoteOMRImport(session: result, sourceKind: .scanCandidate)
            }
        }
    }

    func completeFirstRunSyncChoice(enableSync: Bool) {
        syncStatus = persistence.completeFirstRunSyncChoice(enableSync: enableSync)
        isSyncEnabled = persistence.settingsSnapshot().syncEnabled
        shouldPromptForSyncChoice = false
        appSettingsReload()
        usageTracking.reloadFromPersistence()
    }

    func setSyncEnabled(_ enabled: Bool) {
        syncStatus = persistence.setSyncEnabled(enabled)
        isSyncEnabled = persistence.settingsSnapshot().syncEnabled
        appSettingsReload()
        usageTracking.reloadFromPersistence()
        if let restored = try? persistence.loadPersistedScore() {
            setScore(restored.score, scoreItemID: restored.scoreItemID, annotationStrokes: restored.annotationStrokes)
        }
    }

    var selectedReviewSymbol: ScoreReviewSymbol? {
        guard let selectedReviewSymbolID else {
            return nil
        }
        return scoreReviewSession?.symbols.first(where: { $0.id == selectedReviewSymbolID })
    }

    func selectReviewPage(_ pageIndex: Int) {
        selectedReviewPageIndex = pageIndex
    }

    func selectReviewSymbol(_ symbolID: String?) {
        selectedReviewSymbolID = symbolID
        if var session = musicXMLEditorSession {
            session.selectedSymbolID = symbolID
            musicXMLEditorSession = session
        }
        if let symbol = symbolID.flatMap({ id in
            scoreReviewSession?.symbols.first(where: { $0.id == id })
        }), let pageIndex = symbol.pageIndex {
            selectedReviewPageIndex = pageIndex
        }
    }

    func reviewMeasure(for symbol: ScoreReviewSymbol) -> ScoreMeasure? {
        guard let part = score?.parts.first(where: { $0.id == symbol.partID }) else {
            return nil
        }
        return part.measures.first(where: { $0.number == symbol.measureNumber })
    }

    func reviewNote(for symbol: ScoreReviewSymbol) -> ScoreNote? {
        guard let measure = reviewMeasure(for: symbol), let noteID = symbol.noteID else {
            return nil
        }
        return measure.notes.first(where: { $0.id == noteID })
    }

    func reviewDirection(for symbol: ScoreReviewSymbol) -> ScoreDirection? {
        guard let measure = reviewMeasure(for: symbol), let directionID = symbol.directionID else {
            return nil
        }
        return measure.directions.first(where: { $0.id == directionID })
    }

    func reviewLyric(for symbol: ScoreReviewSymbol) -> ScoreLyric? {
        guard let note = reviewNote(for: symbol), let lyricID = symbol.lyricID else {
            return nil
        }
        return note.lyrics.first(where: { $0.id == lyricID })
    }

    func applyReviewNoteEdit(
        symbol: ScoreReviewSymbol,
        step: String?,
        alter: Int,
        octave: Int?,
        noteType: String,
        isRest: Bool,
        lyricText: String
    ) {
        guard var score else {
            return
        }
        guard let partIndex = score.parts.firstIndex(where: { $0.id == symbol.partID }) else {
            return
        }
        guard let measureIndex = score.parts[partIndex].measures.firstIndex(where: { $0.number == symbol.measureNumber }) else {
            return
        }
        guard let noteIndex = score.parts[partIndex].measures[measureIndex].notes.firstIndex(where: { $0.id == symbol.noteID }) else {
            return
        }

        let normalizedStep = isRest ? nil : step
        let normalizedOctave = isRest ? nil : octave
        let duration = durationUnits(for: noteType)
        let durationTick = duration * score.ticksPerQuarter / max(score.divisions, 1)
        let midi = isRest ? nil : Self.midiNumber(step: normalizedStep, alter: alter, octave: normalizedOctave)

        score.parts[partIndex].measures[measureIndex].notes[noteIndex].step = normalizedStep
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].alter = alter
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].octave = normalizedOctave
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].noteType = noteType
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].duration = duration
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].durationTick = durationTick
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].isRest = isRest
        score.parts[partIndex].measures[measureIndex].notes[noteIndex].midi = midi

        let trimmedLyric = lyricText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLyric.isEmpty {
            score.parts[partIndex].measures[measureIndex].notes[noteIndex].lyrics.removeAll()
        } else if score.parts[partIndex].measures[measureIndex].notes[noteIndex].lyrics.isEmpty {
            score.parts[partIndex].measures[measureIndex].notes[noteIndex].lyrics = [ScoreLyric(text: trimmedLyric)]
        } else {
            score.parts[partIndex].measures[measureIndex].notes[noteIndex].lyrics[0].text = trimmedLyric
        }

        recordCorrection(
            in: &score,
            partID: symbol.partID,
            measureNumber: symbol.measureNumber,
            symbolID: symbol.id,
            symbolKind: symbol.kind.rawValue,
            field: "note",
            value: isRest ? "rest" : "\(normalizedStep ?? "C"):\(alter):\(normalizedOctave ?? 4):\(noteType):\(trimmedLyric)"
        )
        self.score = score
        persistReviewedScore(statusKey: "score.review.note_saved")
    }

    func applyReviewMeasureEdit(
        symbol: ScoreReviewSymbol,
        beats: Int,
        beatType: Int,
        keyFifths: Int,
        clefSign: String,
        clefLine: Int,
        repeatStart: Bool,
        repeatEnd: Bool
    ) {
        guard var score else {
            return
        }
        guard let partIndex = score.parts.firstIndex(where: { $0.id == symbol.partID }) else {
            return
        }
        guard let measureIndex = score.parts[partIndex].measures.firstIndex(where: { $0.number == symbol.measureNumber }) else {
            return
        }

        score.parts[partIndex].measures[measureIndex].beats = beats
        score.parts[partIndex].measures[measureIndex].beatType = beatType
        score.parts[partIndex].measures[measureIndex].keyFifths = keyFifths
        score.parts[partIndex].measures[measureIndex].clefSign = clefSign
        score.parts[partIndex].measures[measureIndex].clefLine = clefLine
        score.parts[partIndex].measures[measureIndex].repeatStart = repeatStart
        score.parts[partIndex].measures[measureIndex].repeatEnd = repeatEnd
        recordCorrection(
            in: &score,
            partID: symbol.partID,
            measureNumber: symbol.measureNumber,
            symbolID: symbol.id,
            symbolKind: symbol.kind.rawValue,
            field: "measure",
            value: "\(beats)/\(beatType);key=\(keyFifths);clef=\(clefSign)\(clefLine);repeat=\(repeatStart)-\(repeatEnd)"
        )
        self.score = score
        persistReviewedScore(statusKey: "score.review.measure_saved")
    }

    func applyReviewDirectionEdit(
        symbol: ScoreReviewSymbol,
        value: String,
        placement: String?
    ) {
        guard var score else {
            return
        }
        guard let partIndex = score.parts.firstIndex(where: { $0.id == symbol.partID }) else {
            return
        }
        guard let measureIndex = score.parts[partIndex].measures.firstIndex(where: { $0.number == symbol.measureNumber }) else {
            return
        }
        guard let directionIndex = score.parts[partIndex].measures[measureIndex].directions.firstIndex(where: { $0.id == symbol.directionID }) else {
            return
        }

        score.parts[partIndex].measures[measureIndex].directions[directionIndex].value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        score.parts[partIndex].measures[measureIndex].directions[directionIndex].placement = placement?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        recordCorrection(
            in: &score,
            partID: symbol.partID,
            measureNumber: symbol.measureNumber,
            symbolID: symbol.id,
            symbolKind: symbol.kind.rawValue,
            field: "direction",
            value: "\(value)|\(placement ?? "")"
        )
        self.score = score
        persistReviewedScore(statusKey: "score.review.direction_saved")
    }

    private func setScore(
        _ newScore: ScoreDocument,
        scoreItemID: String?,
        annotationStrokes restoredAnnotationStrokes: [ScoreAnnotationStrokePayload]? = nil
    ) {
        score = newScore
        selectedPartID = newScore.parts.first?.id
        exportedMIDIURL = nil
        exportedMusicXMLURL = nil
        scannedMusicXMLCandidate = nil
        latestNativeOMRSession = nil
        scoreReviewSession = nil
        musicXMLEditorSession = nil
        selectedReviewSymbolID = nil
        selectedReviewPageIndex = 0
        currentScoreItemID = scoreItemID
        persistence.setSelectedScoreItemID(scoreItemID)
        annotationPersistenceEnabled = false
        if let restoredAnnotationStrokes {
            annotationStrokes = restoredAnnotationStrokes
        } else if let scoreItemID {
            annotationStrokes = persistence.loadAnnotationStrokes(for: scoreItemID)
        } else {
            annotationStrokes = []
        }
        annotationPersistenceEnabled = true
    }

    private func refreshReviewArtifacts(
        sourceName: String? = nil,
        inputKind: OMRInputKind? = nil,
        pages: [ScoreReviewPage]? = nil,
        scoreNotation: NativeOMRScoreNotation? = nil,
        provider: OMRProvider = .nativePrototype
    ) {
        guard let score else {
            scoreReviewSession = nil
            scannedMusicXMLCandidate = nil
            return
        }

        let resolvedSourceName = sourceName
            ?? scoreReviewSession?.sourceName
            ?? scannedMusicXMLCandidate?.sourceName
            ?? score.metadata.title
            ?? "Current score"
        let resolvedInputKind = inputKind
            ?? scoreReviewSession?.inputKind
            ?? scannedMusicXMLCandidate?.inputKind
            ?? .musicXML
        let resolvedPages = pages ?? scoreReviewSession?.pages ?? []
        let resolvedNotation = scoreNotation ?? latestNativeOMRSession?.scoreNotation

        scoreReviewSession = ScoreReviewSessionBuilder.make(
            sourceName: resolvedSourceName,
            inputKind: resolvedInputKind,
            score: score,
            pages: resolvedPages,
            scoreNotation: resolvedNotation
        )
        scannedMusicXMLCandidate = OMRMusicXMLCandidateBuilder.makeCandidate(
            sourceName: resolvedSourceName,
            inputKind: resolvedInputKind,
            provider: provider,
            score: score
        )

        if let selectedReviewSymbolID,
           scoreReviewSession?.symbols.contains(where: { $0.id == selectedReviewSymbolID }) == false {
            self.selectedReviewSymbolID = nil
        }
        if let firstPageIndex = scoreReviewSession?.pages.first?.pageIndex,
           scoreReviewSession?.pages.contains(where: { $0.pageIndex == selectedReviewPageIndex }) == false {
            selectedReviewPageIndex = firstPageIndex
        }
        if var session = musicXMLEditorSession {
            session.reviewSession = scoreReviewSession
            session.scoreDocument = score
            session.selectedSymbolID = selectedReviewSymbolID
            musicXMLEditorSession = session
        }
    }

    private func persistReviewedScore(statusKey: String) {
        guard let score else {
            return
        }

        do {
            let xml = MusicXMLComposer.makeMusicXML(from: score)
            let data = Data(xml.utf8)
            let scoreItemID = try persistence.overwriteScoreDocument(
                itemID: currentScoreItemID,
                score: score,
                data: data,
                sourceType: .musicXML,
                preferredFileName: score.metadata.title ?? scoreReviewSession?.sourceName ?? "reviewed-score"
            )
            currentScoreItemID = scoreItemID
            refreshReviewArtifacts()
            refreshEditorSession(
                sourceKind: musicXMLEditorSession?.sourceKind ?? .directMusicXML,
                sourceName: musicXMLEditorSession?.sourceName ?? score.metadata.title ?? "MusicXML",
                musicXMLString: xml
            )
            statusMessage = L10n.tr(statusKey)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func durationUnits(for noteType: String) -> Int {
        switch noteType.lowercased() {
        case "whole":
            return 8
        case "half":
            return 4
        case "eighth":
            return 1
        default:
            return 2
        }
    }

    private static func midiNumber(step: String?, alter: Int, octave: Int?) -> Int? {
        guard let step, let octave else {
            return nil
        }
        let semitoneByStep = [
            "C": 0,
            "D": 2,
            "E": 4,
            "F": 5,
            "G": 7,
            "A": 9,
            "B": 11
        ]
        guard let semitone = semitoneByStep[step.uppercased()] else {
            return nil
        }
        return (octave + 1) * 12 + semitone + alter
    }

    private func recordCorrection(
        in score: inout ScoreDocument,
        partID: String,
        measureNumber: String,
        symbolID: String,
        symbolKind: String,
        field: String,
        value: String
    ) {
        let correction = ScoreCorrection(
            partID: partID,
            measureNumber: measureNumber,
            symbolID: symbolID,
            symbolKind: symbolKind,
            field: field,
            value: value
        )
        if let index = score.corrections.firstIndex(where: {
            $0.partID == partID &&
            $0.measureNumber == measureNumber &&
            $0.symbolID == symbolID &&
            $0.field == field
        }) {
            score.corrections[index] = correction
        } else {
            score.corrections.append(correction)
        }
    }

    private func appSettingsReload() {
        AppSettingsStore.shared.reloadFromPersistence()
    }

    private func refreshEditorSession(
        sourceKind: MusicXMLEditorSourceKind,
        sourceName: String,
        musicXMLString: String
    ) {
        guard let score else {
            musicXMLEditorSession = nil
            return
        }
        musicXMLEditorSession = MusicXMLEditorSession(
            sourceKind: sourceKind,
            sourceName: sourceName,
            musicXMLString: musicXMLString,
            scoreDocument: score,
            reviewSession: scoreReviewSession,
            selectedSymbolID: selectedReviewSymbolID
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

struct ScoreSummary {
    var title: String
    var partCount: Int
    var measureCount: Int
    var noteCount: Int
    var playableNoteCount: Int
    var durationTicks: Int

    init(score: ScoreDocument?, selectedPart: ScorePart?) {
        guard let score else {
            title = L10n.tr("No score loaded")
            partCount = 0
            measureCount = 0
            noteCount = 0
            playableNoteCount = 0
            durationTicks = 0
            return
        }

        title = score.metadata.title ?? selectedPart?.name ?? score.parts.first?.name ?? L10n.tr("Imported score")
        partCount = score.parts.count
        measureCount = selectedPart?.measures.count ?? 0
        let notes = selectedPart?.measures.flatMap(\.notes) ?? []
        noteCount = notes.count
        playableNoteCount = notes.filter { !$0.isRest && $0.midi != nil }.count
        durationTicks = notes.map { $0.startTick + $0.durationTick }.max() ?? 0
    }
}
