import Foundation
import Observation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

@MainActor
@Observable
final class ShenghaiWorkspace {
    var selectedSection: AppSection = .dashboard {
        didSet {
            usageTracking.switchTo(selectedSection.usageFeature)
        }
    }
    var score: ScoreDocument?
    var selectedPartID: String?
    var statusMessage = "Ready for MusicXML prototype testing."
    var errorMessage: String?
    var exportedMIDIURL: URL?
    var isImportingScore = false
    var isPlaying = false
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
            statusMessage = "Loaded demo score: Twinkle excerpt."
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
            statusMessage = "Imported \(url.lastPathComponent)."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func exportMIDI() {
        guard let score else {
            errorMessage = "Load or import a MusicXML score first."
            return
        }

        do {
            let url = FileManager.default.temporaryDirectory
                .appending(path: "Shenghai-\(UUID().uuidString.prefix(8)).mid")
            try MIDIWriter.writeMIDI(score: score, to: url, partIndex: selectedPartIndex)
            exportedMIDIURL = url
            statusMessage = "Exported MIDI for \(selectedPart?.name ?? "selected part")."
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playOrStop() {
        if isPlaying {
            playbackService.stop()
            isPlaying = false
            statusMessage = "Playback stopped."
            return
        }

        guard let score else {
            errorMessage = "Load or import a MusicXML score first."
            return
        }

        do {
            let midiData = MIDIWriter.makeMIDIData(score: score, partIndex: selectedPartIndex)
            isPlaying = true
            try playbackService.play(data: midiData) { [weak self] in
                self?.isPlaying = false
                self?.statusMessage = "Playback finished."
            }
            statusMessage = "Playing \(selectedPart?.name ?? "selected part")."
            errorMessage = nil
        } catch {
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    private func setScore(_ newScore: ScoreDocument) {
        score = newScore
        selectedPartID = newScore.parts.first?.id
        exportedMIDIURL = nil
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
            title = "No score loaded"
            partCount = 0
            measureCount = 0
            noteCount = 0
            playableNoteCount = 0
            durationTicks = 0
            return
        }

        title = selectedPart?.name ?? score.parts.first?.name ?? "Imported score"
        partCount = score.parts.count
        measureCount = selectedPart?.measures.count ?? 0
        let notes = selectedPart?.measures.flatMap(\.notes) ?? []
        noteCount = notes.count
        playableNoteCount = notes.filter { !$0.isRest && $0.midi != nil }.count
        durationTicks = notes.map { $0.startTick + $0.durationTick }.max() ?? 0
    }
}
