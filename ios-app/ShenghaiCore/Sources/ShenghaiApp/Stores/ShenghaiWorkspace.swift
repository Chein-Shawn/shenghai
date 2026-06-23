import Foundation
import Combine
import UniformTypeIdentifiers
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

@MainActor
final class ShenghaiWorkspace: ObservableObject {
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
    @Published var selectedOMRProvider: OMRProvider = .nativePrototype
    @Published var scannedMusicXMLCandidate: OMRMusicXMLCandidate?
    @Published var latestNativeOMRSession: NativeOMRPrototypeSessionResult?
    @Published var scoreReviewSession: ScoreReviewSession?
    @Published var selectedReviewPageIndex = 0
    @Published var selectedReviewSymbolID: String?
    @Published var currentScoreItemID: String?
    @Published var compactScoreMode: ScoreHubMode = .workspace
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
        do {
            let data = Data(SampleScoreLibrary.twinkleMusicXML.utf8)
            let importedScore = try importer.importDocument(data: data)
            let scoreItemID = try persistence.persistScoreDocument(
                score: importedScore,
                data: data,
                sourceType: .demo,
                preferredFileName: importedScore.metadata.title ?? "twinkle-demo"
            )
            setScore(importedScore, scoreItemID: scoreItemID)
            refreshReviewArtifacts(sourceName: importedScore.metadata.title ?? "twinkle-demo", inputKind: .musicXML)
            statusMessage = L10n.tr("Loaded demo score: Twinkle excerpt.")
            errorMessage = nil
            compactScoreMode = .workspace
            selectedSection = .scoreWorkspace
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
            statusMessage = L10n.tr("Imported %@.", url.lastPathComponent)
            errorMessage = nil
            compactScoreMode = .workspace
            selectedSection = .scoreWorkspace
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importScoreFile(url: URL) {
        let lowercasedExtension = url.pathExtension.lowercased()

        if ["xml", "musicxml", "mxl"].contains(lowercasedExtension) {
            importMusicXML(url: url)
            return
        }

        if lowercasedExtension == "pdf" {
            if selectedOMRProvider.runsInsideAppleApp {
                runNativeOMRImport(url: url)
            } else {
                handlePendingOMRImport(url: url, inputKind: .pdf)
            }
            return
        }

        if let type = UTType(filenameExtension: lowercasedExtension),
           type.conforms(to: .image) {
            if selectedOMRProvider.runsInsideAppleApp {
                runNativeOMRImport(url: url)
            } else {
                handlePendingOMRImport(url: url, inputKind: .image)
            }
            return
        }

        errorMessage = L10n.tr("This file type is not supported yet. Import MusicXML directly, or use PDF/image for the OMR intake path.")
    }

    func exportMIDI() {
        guard let score else {
            errorMessage = L10n.tr("Load or import a MusicXML score first.")
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "Shenghai-\(UUID().uuidString.prefix(8)).mid")
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
            provider: selectedOMRProvider,
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
            statusMessage = L10n.tr("Created %d notes from Compose.", normalizedScore.notes.count)
            errorMessage = nil
            compactScoreMode = .workspace
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
                .isEmpty ? "Shenghai-Composition" : normalizedScore.title
            let safeName = fileName
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            let url = FileManager.default.temporaryDirectory
                .appending(path: "\(safeName.isEmpty ? "Shenghai-Composition" : safeName).musicxml")
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

    private func handlePendingOMRImport(url: URL, inputKind: OMRInputKind) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        statusMessage = L10n.tr("Imported %@ for OMR intake. This build still needs an external OMR step before Shenghai can open it as editable MusicXML.", url.lastPathComponent)
        errorMessage = L10n.tr("PDF/image import is accepted, but in-app OMR is not implemented yet. Convert it to MusicXML first, then import the MusicXML result.")
        scannedMusicXMLCandidate = nil
        latestNativeOMRSession = nil
        scoreReviewSession = nil
        selectedReviewSymbolID = nil
        selectedReviewPageIndex = 0
        compactScoreMode = .workspace
        selectedSection = .scoreWorkspace
    }

    private func runNativeOMRImport(url: URL) {
        let didStartAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            statusMessage = L10n.tr("score.native_omr.processing", url.lastPathComponent)
            errorMessage = nil

            let session = try nativeOMRPrototypeService.makeSession(from: url)
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
                provider: selectedOMRProvider,
                score: importedScore
            )
            refreshReviewArtifacts(
                sourceName: url.lastPathComponent,
                inputKind: session.inputKind,
                pages: session.renderedPages.map { page in
                    ScoreReviewPage(
                        pageIndex: page.pageIndex,
                        pixelWidth: page.pixelWidth,
                        pixelHeight: page.pixelHeight,
                        imageData: page.imageData,
                        status: session.scoreNotation.pageResults.first(where: { $0.pageIndex == page.pageIndex })?.status ?? .recognized
                    )
                },
                scoreNotation: session.scoreNotation
            )

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

            compactScoreMode = .workspace
            selectedSection = .scoreWorkspace
        } catch {
            latestNativeOMRSession = nil
            scannedMusicXMLCandidate = nil
            errorMessage = L10n.tr("score.native_omr.failed", error.localizedDescription)
        }
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
        scoreNotation: NativeOMRScoreNotation? = nil
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
            provider: selectedOMRProvider,
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
