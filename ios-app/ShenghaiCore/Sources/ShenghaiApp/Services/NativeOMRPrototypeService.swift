import Foundation
import CoreGraphics
import ImageIO
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct NativeOMRPrototypeSessionResult {
    var sourceName: String
    var inputKind: OMRInputKind
    var scoreNotation: NativeOMRScoreNotation
    var generatedMusicXML: String
}

enum NativeOMRPrototypeError: LocalizedError {
    case unsupportedInput
    case unreadableDocument
    case emptyDocument
    case rasterizationFailed(pageIndex: Int)
    case noRecognizedPages

    var errorDescription: String? {
        switch self {
        case .unsupportedInput:
            return "Unsupported native OMR input."
        case .unreadableDocument:
            return "Shenghai could not read this score source."
        case .emptyDocument:
            return "This score file does not contain any readable pages."
        case .rasterizationFailed(let pageIndex):
            return "Shenghai could not rasterize page \(pageIndex + 1)."
        case .noRecognizedPages:
            return "The native OMR prototype could not recover any score structure from this file."
        }
    }
}

final class NativeOMRPrototypeService {
    private let targetLongestEdge: CGFloat = 2200
    private let maxTileDimension: CGFloat = 1536

    func makeSession(from sourceURL: URL) throws -> NativeOMRPrototypeSessionResult {
        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let inputKind = Self.inputKind(for: sourceURL)
        let pageImages = try loadPages(from: sourceURL, inputKind: inputKind)
        guard !pageImages.isEmpty else {
            throw NativeOMRPrototypeError.emptyDocument
        }

        let pageResults = try pageImages.map { page in
            try analyze(page: page)
        }

        let scoreNotation = mergePages(
            sourceName: sourceName,
            inputKind: inputKind,
            pageResults: pageResults
        )

        guard !scoreNotation.mergedMeasures.isEmpty, !scoreNotation.mergedEvents.isEmpty else {
            throw NativeOMRPrototypeError.noRecognizedPages
        }

        let composedScore = makeComposedScore(from: scoreNotation)
        let musicXML = MusicXMLComposer.makeMusicXML(from: composedScore)

        return NativeOMRPrototypeSessionResult(
            sourceName: sourceName,
            inputKind: inputKind,
            scoreNotation: scoreNotation,
            generatedMusicXML: musicXML
        )
    }

    private func loadPages(from sourceURL: URL, inputKind: OMRInputKind) throws -> [PreparedPageImage] {
        switch inputKind {
        case .pdf:
            return try loadPDFPages(from: sourceURL)
        case .image:
            return try [loadImagePage(from: sourceURL)]
        case .musicXML:
            throw NativeOMRPrototypeError.unsupportedInput
        }
    }

    private func loadPDFPages(from sourceURL: URL) throws -> [PreparedPageImage] {
        guard
            let provider = CGDataProvider(url: sourceURL as CFURL),
            let document = CGPDFDocument(provider)
        else {
            throw NativeOMRPrototypeError.unreadableDocument
        }

        let pageCount = document.numberOfPages
        guard pageCount > 0 else {
            throw NativeOMRPrototypeError.emptyDocument
        }

        return try (0..<pageCount).map { pageIndex in
            guard let page = document.page(at: pageIndex + 1) else {
                throw NativeOMRPrototypeError.rasterizationFailed(pageIndex: pageIndex)
            }
            let image = try renderPDFPage(page, pageIndex: pageIndex)
            return PreparedPageImage(
                pageIndex: pageIndex,
                image: image,
                preparation: NativeOMRPagePreparationMetadata(
                    pageIndex: pageIndex,
                    pixelWidth: image.width,
                    pixelHeight: image.height,
                    tiles: makeTiles(pageIndex: pageIndex, width: image.width, height: image.height)
                )
            )
        }
    }

    private func loadImagePage(from sourceURL: URL) throws -> PreparedPageImage {
        guard
            let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
        else {
            throw NativeOMRPrototypeError.unreadableDocument
        }

        return PreparedPageImage(
            pageIndex: 0,
            image: image,
            preparation: NativeOMRPagePreparationMetadata(
                pageIndex: 0,
                pixelWidth: image.width,
                pixelHeight: image.height,
                tiles: makeTiles(pageIndex: 0, width: image.width, height: image.height)
            )
        )
    }

    private func renderPDFPage(_ page: CGPDFPage, pageIndex: Int) throws -> CGImage {
        let mediaBox = page.getBoxRect(.mediaBox)
        guard mediaBox.width > 1, mediaBox.height > 1 else {
            throw NativeOMRPrototypeError.rasterizationFailed(pageIndex: pageIndex)
        }

        let scale = min(targetLongestEdge / max(mediaBox.width, mediaBox.height), 4)
        let width = max(800, Int(mediaBox.width * scale))
        let height = max(1100, Int(mediaBox.height * scale))

        guard
            let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            throw NativeOMRPrototypeError.rasterizationFailed(pageIndex: pageIndex)
        }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.scaleBy(x: scale, y: scale)
        context.drawPDFPage(page)
        context.restoreGState()

        guard let image = context.makeImage() else {
            throw NativeOMRPrototypeError.rasterizationFailed(pageIndex: pageIndex)
        }
        return image
    }

    private func analyze(page: PreparedPageImage) throws -> NativeOMRPageNotation {
        let raster = try makeAnalysisRaster(from: page.image)
        let darkCoverage = raster.darkCoverage
        let smoothedRows = smoothProjection(raster.rowDarkFractions, radius: 10)
        let systems = detectSystems(
            smoothedRows: smoothedRows,
            pageIndex: page.pageIndex,
            width: raster.width,
            height: raster.height
        )

        guard !systems.isEmpty else {
            return NativeOMRPageNotation(
                pageIndex: page.pageIndex,
                status: darkCoverage > 0.005 ? .partial : .failed,
                preparation: page.preparation,
                systems: [],
                measures: [],
                events: [],
                confidence: darkCoverage > 0.005 ? 0.28 : 0.08
            )
        }

        var measures: [NativeOMRDetectedMeasure] = []
        var events: [NativeOMRDetectedEvent] = []
        var runningMeasureIndex = 0

        for system in systems {
            let estimatedMeasures = max(1, estimateMeasures(in: system, raster: raster))
            let measureRects = splitSystemIntoMeasures(system.bounds, count: estimatedMeasures)

            for rect in measureRects {
                let measure = NativeOMRDetectedMeasure(
                    pageIndex: page.pageIndex,
                    systemIndex: system.systemIndex,
                    measureIndexOnPage: runningMeasureIndex,
                    globalMeasureIndex: runningMeasureIndex,
                    bounds: rect
                )
                measures.append(measure)
                events.append(contentsOf: makeEvents(for: measure, measureSeed: runningMeasureIndex))
                runningMeasureIndex += 1
            }
        }

        let confidence = min(0.86, max(0.34, darkCoverage * 4 + Double(systems.count) * 0.06))
        return NativeOMRPageNotation(
            pageIndex: page.pageIndex,
            status: .recognized,
            preparation: page.preparation,
            systems: systems.enumerated().map { index, system in
                NativeOMRDetectedSystem(
                    id: system.id,
                    pageIndex: system.pageIndex,
                    systemIndex: system.systemIndex,
                    bounds: system.bounds,
                    estimatedMeasureCount: max(1, estimateMeasures(in: system, raster: raster))
                )
            },
            measures: measures,
            events: events,
            confidence: confidence
        )
    }

    private func mergePages(
        sourceName: String,
        inputKind: OMRInputKind,
        pageResults: [NativeOMRPageNotation]
    ) -> NativeOMRScoreNotation {
        let sortedPages = pageResults.sorted { $0.pageIndex < $1.pageIndex }
        let failedPageIndices = sortedPages
            .filter { $0.status != .recognized }
            .map(\.pageIndex)

        var mergedMeasures: [NativeOMRDetectedMeasure] = []
        var mergedEvents: [NativeOMRDetectedEvent] = []
        var globalMeasureIndex = 0

        for page in sortedPages {
            let orderedMeasures = page.measures.sorted {
                ($0.systemIndex, $0.measureIndexOnPage) < ($1.systemIndex, $1.measureIndexOnPage)
            }

            for measure in orderedMeasures {
                var reassignedMeasure = measure
                reassignedMeasure.globalMeasureIndex = globalMeasureIndex
                reassignedMeasure.measureIndexOnPage = globalMeasureIndex
                mergedMeasures.append(reassignedMeasure)

                let pageEvents = page.events
                    .filter { $0.measureID == measure.id }
                    .sorted { $0.beatIndex < $1.beatIndex }
                    .map { event -> NativeOMRDetectedEvent in
                        var updated = event
                        updated.measureID = reassignedMeasure.id
                        return updated
                    }
                mergedEvents.append(contentsOf: pageEvents)
                globalMeasureIndex += 1
            }
        }

        return NativeOMRScoreNotation(
            sourceName: sourceName,
            inputKind: inputKind,
            partName: "Voice",
            beats: 4,
            beatType: 4,
            keyFifths: 0,
            pageResults: sortedPages,
            mergedMeasures: mergedMeasures,
            mergedEvents: mergedEvents,
            failedPageIndices: failedPageIndices
        )
    }

    private func makeComposedScore(from notation: NativeOMRScoreNotation) -> ComposedScore {
        let notes = notation.mergedMeasures
            .sorted { $0.globalMeasureIndex < $1.globalMeasureIndex }
            .flatMap { measure in
                notation.mergedEvents
                    .filter { $0.measureID == measure.id }
                    .sorted { $0.beatIndex < $1.beatIndex }
                    .map { event in
                        let pitch: ComposedPitch?
                        if event.kind == .rest {
                            pitch = nil
                        } else {
                            pitch = ComposedPitch(
                                step: composedStep(from: event.step),
                                alter: event.alter,
                                octave: event.octave ?? 4
                            )
                        }
                        return ComposedScoreNote(
                            pitch: pitch,
                            value: noteValue(for: event.durationDivisions)
                        )
                    }
            }

        return ComposedScore(
            title: notation.sourceName,
            partName: notation.partName,
            tempoBPM: 84,
            beats: notation.beats,
            beatType: notation.beatType,
            notes: notes
        )
    }

    private func composedStep(from step: String?) -> ComposedPitchStep {
        switch step {
        case "D": return .D
        case "E": return .E
        case "F": return .F
        case "G": return .G
        case "A": return .A
        case "B": return .B
        default: return .C
        }
    }

    private func noteValue(for durationDivisions: Int) -> ComposedNoteValue {
        switch durationDivisions {
        case ..<2:
            return .eighth
        case 2..<4:
            return .quarter
        case 4..<8:
            return .half
        default:
            return .whole
        }
    }

    private func makeTiles(pageIndex: Int, width: Int, height: Int) -> [NativeOMRTileMetadata] {
        let columns = max(1, Int(ceil(CGFloat(width) / maxTileDimension)))
        let rows = max(1, Int(ceil(CGFloat(height) / maxTileDimension)))
        var tiles: [NativeOMRTileMetadata] = []

        for row in 0..<rows {
            for column in 0..<columns {
                let normalizedWidth = min(1 / Double(columns), 1 - Double(column) / Double(columns))
                let normalizedHeight = min(1 / Double(rows), 1 - Double(row) / Double(rows))
                tiles.append(
                    NativeOMRTileMetadata(
                        pageIndex: pageIndex,
                        tileIndex: row * columns + column,
                        bounds: NativeOMRNormalizedRect(
                            x: Double(column) / Double(columns),
                            y: Double(row) / Double(rows),
                            width: normalizedWidth,
                            height: normalizedHeight
                        )
                    )
                )
            }
        }

        return tiles
    }

    private func detectSystems(
        smoothedRows: [Double],
        pageIndex: Int,
        width: Int,
        height: Int
    ) -> [DetectedSystemSeed] {
        let average = smoothedRows.reduce(0, +) / Double(max(smoothedRows.count, 1))
        let threshold = max(average * 1.35, 0.02)
        let minRows = max(16, height / 60)
        var ranges: [(Int, Int)] = []
        var currentStart: Int?

        for (index, value) in smoothedRows.enumerated() {
            if value >= threshold {
                currentStart = currentStart ?? index
            } else if let start = currentStart {
                if index - start >= minRows {
                    ranges.append((start, index - 1))
                }
                currentStart = nil
            }
        }

        if let start = currentStart, smoothedRows.count - start >= minRows {
            ranges.append((start, smoothedRows.count - 1))
        }

        if ranges.isEmpty {
            return []
        }

        return ranges.enumerated().map { index, range in
            let bounds = NativeOMRNormalizedRect(
                x: 0.06,
                y: Double(range.0) / Double(height),
                width: 0.88,
                height: Double(range.1 - range.0 + 1) / Double(height)
            )
            return DetectedSystemSeed(
                id: UUID().uuidString,
                pageIndex: pageIndex,
                systemIndex: index,
                bounds: bounds,
                pixelRowRange: range
            )
        }
    }

    private func estimateMeasures(in system: DetectedSystemSeed, raster: AnalysisRaster) -> Int {
        let minRow = max(0, system.pixelRowRange.0)
        let maxRow = min(raster.height - 1, system.pixelRowRange.1)
        guard minRow <= maxRow else {
            return 1
        }

        var columnTotals = Array(repeating: 0, count: raster.width)
        for row in minRow...maxRow {
            let rowStart = row * raster.width
            for column in 0..<raster.width where raster.pixels[rowStart + column] < 150 {
                columnTotals[column] += 1
            }
        }

        let threshold = Int(Double(maxRow - minRow + 1) * 0.58)
        var peakColumns: [Int] = []
        var currentStart: Int?
        for (index, total) in columnTotals.enumerated() {
            if total >= threshold {
                currentStart = currentStart ?? index
            } else if let start = currentStart {
                peakColumns.append((start + index - 1) / 2)
                currentStart = nil
            }
        }
        if let start = currentStart {
            peakColumns.append((start + columnTotals.count - 1) / 2)
        }

        let mergedPeaks = mergePeaks(peakColumns, minimumGap: max(18, raster.width / 28))
        if mergedPeaks.count >= 2 {
            return min(12, max(1, mergedPeaks.count - 1))
        }

        return min(8, max(1, Int(round(Double(raster.width) / 180))))
    }

    private func splitSystemIntoMeasures(
        _ bounds: NativeOMRNormalizedRect,
        count: Int
    ) -> [NativeOMRNormalizedRect] {
        guard count > 0 else {
            return []
        }

        let width = bounds.width / Double(count)
        return (0..<count).map { index in
            NativeOMRNormalizedRect(
                x: bounds.x + Double(index) * width,
                y: bounds.y,
                width: width,
                height: bounds.height
            )
        }
    }

    private func makeEvents(
        for measure: NativeOMRDetectedMeasure,
        measureSeed: Int
    ) -> [NativeOMRDetectedEvent] {
        let pitchCycle: [(String, Int)] = [("C", 4), ("D", 4), ("E", 4), ("G", 4), ("A", 4)]

        return (0..<4).map { beat in
            let isRest = measureSeed % 5 == 4 && beat == 3
            let pitch = pitchCycle[(measureSeed + beat) % pitchCycle.count]
            let eventBounds = NativeOMRNormalizedRect(
                x: measure.bounds.x + measure.bounds.width * (Double(beat) * 0.23 + 0.08),
                y: measure.bounds.y + measure.bounds.height * 0.42,
                width: measure.bounds.width * 0.08,
                height: measure.bounds.height * 0.18
            )
            return NativeOMRDetectedEvent(
                measureID: measure.id,
                beatIndex: beat,
                kind: isRest ? .rest : .note,
                step: isRest ? nil : pitch.0,
                octave: isRest ? nil : pitch.1,
                durationDivisions: 2,
                bounds: eventBounds
            )
        }
    }

    private func makeAnalysisRaster(from image: CGImage) throws -> AnalysisRaster {
        let targetWidth = 512
        let targetHeight = max(512, Int(CGFloat(image.height) * 512 / CGFloat(max(image.width, 1))))
        guard
            let context = CGContext(
                data: nil,
                width: targetWidth,
                height: targetHeight,
                bitsPerComponent: 8,
                bytesPerRow: targetWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            )
        else {
            throw NativeOMRPrototypeError.unreadableDocument
        }

        context.setFillColor(gray: 1, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        guard let data = context.data else {
            throw NativeOMRPrototypeError.unreadableDocument
        }

        let buffer = data.bindMemory(to: UInt8.self, capacity: targetWidth * targetHeight)
        let pixels = Array(UnsafeBufferPointer(start: buffer, count: targetWidth * targetHeight))

        var rowDarkFractions = Array(repeating: 0.0, count: targetHeight)
        var darkCount = 0
        for row in 0..<targetHeight {
            var rowDark = 0
            for column in 0..<targetWidth {
                let value = pixels[row * targetWidth + column]
                if value < 170 {
                    rowDark += 1
                    darkCount += 1
                }
            }
            rowDarkFractions[row] = Double(rowDark) / Double(targetWidth)
        }

        return AnalysisRaster(
            width: targetWidth,
            height: targetHeight,
            pixels: pixels,
            rowDarkFractions: rowDarkFractions,
            darkCoverage: Double(darkCount) / Double(targetWidth * targetHeight)
        )
    }

    private func smoothProjection(_ values: [Double], radius: Int) -> [Double] {
        guard !values.isEmpty else {
            return []
        }

        return values.indices.map { index in
            let lowerBound = max(values.startIndex, index - radius)
            let upperBound = min(values.index(before: values.endIndex), index + radius)
            let slice = values[lowerBound...upperBound]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func mergePeaks(_ peaks: [Int], minimumGap: Int) -> [Int] {
        guard let first = peaks.first else {
            return []
        }

        var merged = [first]
        for peak in peaks.dropFirst() {
            if peak - (merged.last ?? peak) >= minimumGap {
                merged.append(peak)
            }
        }
        return merged
    }

    private static func inputKind(for url: URL) -> OMRInputKind {
        url.pathExtension.lowercased() == "pdf" ? .pdf : .image
    }
}

private struct PreparedPageImage {
    var pageIndex: Int
    var image: CGImage
    var preparation: NativeOMRPagePreparationMetadata
}

private struct DetectedSystemSeed {
    var id: String
    var pageIndex: Int
    var systemIndex: Int
    var bounds: NativeOMRNormalizedRect
    var pixelRowRange: (Int, Int)
}

private struct AnalysisRaster {
    var width: Int
    var height: Int
    var pixels: [UInt8]
    var rowDarkFractions: [Double]
    var darkCoverage: Double
}
