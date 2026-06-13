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
    @Published var selectedOMRProvider: OMRProvider = .homr
    @Published var scannedMusicXMLCandidate: OMRMusicXMLCandidate?
    let usageTracking = UsageTrackingStore()

    private let importer = MusicXMLImporter()
    private let playbackService = MIDIPlaybackService()

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
            setScore(importedScore)
            statusMessage = L10n.tr("Loaded demo score: Twinkle excerpt.")
            errorMessage = nil
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

            let importedScore = try importer.importDocument(url: url)
            setScore(importedScore)
            createScanReviewCandidate(sourceName: url.lastPathComponent, inputKind: .musicXML)
            statusMessage = L10n.tr("Imported %@.", url.lastPathComponent)
            errorMessage = nil
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
            handlePendingOMRImport(url: url, inputKind: .pdf)
            return
        }

        if let type = UTType(filenameExtension: lowercasedExtension),
           type.conforms(to: .image) {
            handlePendingOMRImport(url: url, inputKind: .image)
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
        setScore(generatedScore)
        statusMessage = L10n.tr("Created %d notes from Compose.", normalizedScore.notes.count)
        errorMessage = nil
        selectedSection = .scoreWorkspace
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
        selectedSection = .scoreWorkspace
    }

    private func setScore(_ newScore: ScoreDocument) {
        score = newScore
        selectedPartID = newScore.parts.first?.id
        exportedMIDIURL = nil
        exportedMusicXMLURL = nil
        scannedMusicXMLCandidate = nil
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
