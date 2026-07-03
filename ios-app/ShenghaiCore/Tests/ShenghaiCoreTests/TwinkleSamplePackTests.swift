import Foundation
import Testing
@testable import ShenghaiCore

struct TwinkleSamplePackTests {
    @Test func importsTwinkleMultipageGroundTruth() throws {
        let sampleURL = repoRoot()
            .appendingPathComponent("samples/musicxml/twinkle-multipage-ground-truth.musicxml")
        let score = try MusicXMLImporter().importDocument(url: sampleURL)

        #expect(score.metadata.title == "Twinkle Twinkle Little Star Sample")
        #expect(score.parts.count == 1)
        #expect(score.parts[0].name == "Voice")
        #expect(score.parts[0].measures.count == 24)

        let playableNotes = score.parts
            .flatMap(\.measures)
            .flatMap(\.notes)
            .filter { !$0.isRest }
        #expect(playableNotes.count == 84)
        #expect(playableNotes.prefix(8).map(\.midi) == [60, 60, 67, 67, 69, 69, 67, 65])
        #expect(score.parts[0].measures[0].directions.first?.value == "Andante")
        #expect(score.parts[0].measures[8].directions.first?.value == "mf")
        #expect(score.parts[0].measures[16].directions.first?.value == "rit.")
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
