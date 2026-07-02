import Foundation
import CoreGraphics
import ImageIO
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum SampleScoreVariant: String, CaseIterable, Identifiable {
    case intact
    case scanned

    var id: String { rawValue }
}

struct SampleBenchmarkSpec: Equatable {
    var sampleID: String
    var expectedPageCount: Int
    var expectedMeasureCount: Int
    var expectedPlayableNoteCount: Int
    var expectedPitchSequence: [Int]
    var expectedTitle: String
    var expectedPartName: String
}

struct SampleBenchmarkResult: Equatable {
    var spec: SampleBenchmarkSpec
    var actualPageCount: Int
    var actualMeasureCount: Int
    var actualPlayableNoteCount: Int
    var actualPitchSequence: [Int]

    var importSucceeded: Bool {
        actualMeasureCount > 0 && actualPlayableNoteCount > 0
    }

    var passed: Bool {
        actualPageCount == spec.expectedPageCount &&
        actualMeasureCount == spec.expectedMeasureCount &&
        actualPlayableNoteCount == spec.expectedPlayableNoteCount &&
        actualPitchSequence == spec.expectedPitchSequence
    }
}

struct SampleScorePack: Equatable {
    var id: String
    var displayName: String
    var groundTruthMusicXML: String
    var intactPDFURL: URL
    var intactPages: [ScoreReviewPage]
    var scannedPDFURL: URL
    var scannedPageURLs: [URL]
    var benchmark: SampleBenchmarkSpec
}

enum SampleScoreLibrary {
    static func bundledTwinklePack() throws -> SampleScorePack {
        let groundTruthURL = try resourceURL(
            resource: "twinkle-multipage-ground-truth",
            extension: "musicxml",
            subdirectory: "SampleScores"
        )
        let groundTruthMusicXML = try String(contentsOf: groundTruthURL, encoding: .utf8)

        let intactPDFURL = try resourceURL(
            resource: "twinkle-multipage",
            extension: "pdf",
            subdirectory: "SampleScores/twinkle_intact"
        )
        let intactPages = try makeReviewPages(
            subdirectory: "SampleScores/twinkle_intact",
            fileNames: [
                "twinkle-page-1.png",
                "twinkle-page-2.png",
                "twinkle-page-3.png"
            ]
        )
        let scannedPDFURL = try resourceURL(
            resource: "Twinkle_scanned",
            extension: "pdf",
            subdirectory: "SampleScores/twinkle_scanned"
        )
        let scannedPageURLs = try [
            resourceURL(
                resource: "twinkle-scanned-page-1",
                extension: "HEIC",
                subdirectory: "SampleScores/twinkle_scanned"
            ),
            resourceURL(
                resource: "twinkle-scanned-page-2",
                extension: "HEIC",
                subdirectory: "SampleScores/twinkle_scanned"
            ),
            resourceURL(
                resource: "twinkle-scanned-page-3",
                extension: "HEIC",
                subdirectory: "SampleScores/twinkle_scanned"
            )
        ]

        return SampleScorePack(
            id: "twinkle",
            displayName: "Twinkle Twinkle Little Star",
            groundTruthMusicXML: groundTruthMusicXML,
            intactPDFURL: intactPDFURL,
            intactPages: intactPages,
            scannedPDFURL: scannedPDFURL,
            scannedPageURLs: scannedPageURLs,
            benchmark: SampleBenchmarkSpec(
                sampleID: "twinkle",
                expectedPageCount: 3,
                expectedMeasureCount: 24,
                expectedPlayableNoteCount: 84,
                expectedPitchSequence: [60, 60, 67, 67, 69, 69, 67, 65],
                expectedTitle: "Twinkle Twinkle Little Star Sample",
                expectedPartName: "Voice"
            )
        )
    }

    static func verify(score: ScoreDocument, pageCount: Int, spec: SampleBenchmarkSpec) -> SampleBenchmarkResult {
        let playableNotes = score.parts
            .flatMap { $0.measures }
            .flatMap { $0.notes }
            .filter { !$0.isRest }
        return SampleBenchmarkResult(
            spec: spec,
            actualPageCount: pageCount,
            actualMeasureCount: score.parts.first?.measures.count ?? 0,
            actualPlayableNoteCount: playableNotes.count,
            actualPitchSequence: playableNotes.prefix(spec.expectedPitchSequence.count).compactMap { $0.midi }
        )
    }

    private static func resourceURL(resource: String, extension ext: String, subdirectory: String) throws -> URL {
        guard let url = L10n.baseBundle.url(
            forResource: resource,
            withExtension: ext,
            subdirectory: subdirectory
        ) else {
            throw SampleScoreLibraryError.missingResource("\(subdirectory)/\(resource).\(ext)")
        }
        return url
    }

    private static func makeReviewPages(subdirectory: String, fileNames: [String]) throws -> [ScoreReviewPage] {
        try fileNames.enumerated().map { pageIndex, fileName in
            let fileURL = try resourceURL(
                resource: URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent,
                extension: URL(fileURLWithPath: fileName).pathExtension,
                subdirectory: subdirectory
            )
            let data = try Data(contentsOf: fileURL)
            let size = imagePixelSize(data: data) ?? CGSize(width: 2480, height: 3508)
            return ScoreReviewPage(
                pageIndex: pageIndex,
                pixelWidth: Int(size.width),
                pixelHeight: Int(size.height),
                imageData: data,
                status: .recognized
            )
        }
    }

    private static func imagePixelSize(data: Data) -> CGSize? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

enum SampleScoreLibraryError: LocalizedError {
    case missingResource(String)

    var errorDescription: String? {
        switch self {
        case let .missingResource(path):
            return "Missing sample resource: \(path)"
        }
    }
}
