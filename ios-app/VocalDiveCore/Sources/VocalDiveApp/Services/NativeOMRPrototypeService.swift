import Foundation
import CoreGraphics
import ImageIO
#if canImport(CoreML)
import CoreML
#endif
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

struct NativeOMRPrototypeSessionResult {
    var sourceName: String
    var inputKind: OMRInputKind
    var renderedPages: [NativeOMRRenderedPage]
    var scoreNotation: NativeOMRScoreNotation
    var generatedMusicXML: String
}

enum NativeOMRScanProgressPhase: String {
    case preparing
    case rasterizingPages
    case runningModel
    case reconstructingScore
    case generatingMusicXML
    case openingEditor
    case finished

    var localizationKey: String {
        "score.scan.progress.\(rawValue)"
    }
}

struct NativeOMRScanProgress: Equatable {
    var phase: NativeOMRScanProgressPhase
    var fraction: Double
    var completedPages: Int
    var totalPages: Int

    static func make(
        _ phase: NativeOMRScanProgressPhase,
        fraction: Double,
        completedPages: Int = 0,
        totalPages: Int = 0
    ) -> NativeOMRScanProgress {
        NativeOMRScanProgress(
            phase: phase,
            fraction: min(1, max(0, fraction)),
            completedPages: completedPages,
            totalPages: totalPages
        )
    }
}

struct NativeOMRRenderedPage {
    var pageIndex: Int
    var pixelWidth: Int
    var pixelHeight: Int
    var imageData: Data
}

enum NativeOMRPrototypeError: LocalizedError {
    case unsupportedInput
    case unreadableDocument
    case emptyDocument
    case rasterizationFailed(pageIndex: Int)
    case oemerModelUnavailable(String)
    case noRecognizedPages

    var errorDescription: String? {
        switch self {
        case .unsupportedInput:
            return "Unsupported native OMR input."
        case .unreadableDocument:
            return "VocalDive could not read this score source."
        case .emptyDocument:
            return "This score file does not contain any readable pages."
        case .rasterizationFailed(let pageIndex):
            return "VocalDive could not rasterize page \(pageIndex + 1)."
        case .oemerModelUnavailable(let reason):
            return "The bundled oemer Core ML model is not available yet: \(reason)"
        case .noRecognizedPages:
            return "The native OMR prototype could not recover any score structure from this file."
        }
    }
}

final class NativeOMRPrototypeService {
    private let targetLongestEdge: CGFloat = 2200
    private let maxTileDimension: CGFloat = 1536
    private let modelService = VocalDiveOMRModelService()

    func makeSession(
        from sourceURL: URL,
        progress: ((NativeOMRScanProgress) -> Void)? = nil
    ) throws -> NativeOMRPrototypeSessionResult {
        progress?(.make(.preparing, fraction: 0.01))
        let sourceName = sourceURL.deletingPathExtension().lastPathComponent
        let inputKind = Self.inputKind(for: sourceURL)
        progress?(.make(.rasterizingPages, fraction: 0.10))
        let pageImages = try loadPages(from: sourceURL, inputKind: inputKind)
        guard !pageImages.isEmpty else {
            throw NativeOMRPrototypeError.emptyDocument
        }

        progress?(.make(.runningModel, fraction: 0.30, totalPages: pageImages.count))
        let modelReadiness = modelService.readiness()
        guard modelReadiness.isReady else {
            throw NativeOMRPrototypeError.oemerModelUnavailable(modelReadiness.message)
        }

        var predictionResults: [VocalDiveOMRPagePrediction] = []
        for (index, page) in pageImages.enumerated() {
            predictionResults.append(try modelService.predict(page: page))
            let pageProgress = 0.30 + (Double(index + 1) / Double(pageImages.count)) * 0.42
            progress?(.make(.runningModel, fraction: pageProgress, completedPages: index + 1, totalPages: pageImages.count))
        }

        progress?(.make(.reconstructingScore, fraction: 0.78, completedPages: pageImages.count, totalPages: pageImages.count))
        let pageResults = try zip(pageImages, predictionResults).map { page, prediction in
            try analyze(page: page, prediction: prediction)
        }

        let scoreNotation = mergePages(
            sourceName: sourceName,
            inputKind: inputKind,
            pageResults: pageResults
        )

        guard !scoreNotation.mergedMeasures.isEmpty, !scoreNotation.mergedEvents.isEmpty else {
            throw NativeOMRPrototypeError.noRecognizedPages
        }

        progress?(.make(.generatingMusicXML, fraction: 0.88, completedPages: pageImages.count, totalPages: pageImages.count))
        let composedScore = makeComposedScore(from: scoreNotation)
        let musicXML = MusicXMLComposer.makeMusicXML(from: composedScore)

        progress?(.make(.openingEditor, fraction: 0.96, completedPages: pageImages.count, totalPages: pageImages.count))
        let result = NativeOMRPrototypeSessionResult(
            sourceName: sourceName,
            inputKind: inputKind,
            renderedPages: try pageImages.map(makeRenderedPage),
            scoreNotation: scoreNotation,
            generatedMusicXML: musicXML
        )
        progress?(.make(.finished, fraction: 1, completedPages: pageImages.count, totalPages: pageImages.count))
        return result
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

    private func makeRenderedPage(from preparedPage: PreparedPageImage) throws -> NativeOMRRenderedPage {
        guard let data = pngData(from: preparedPage.image) else {
            throw NativeOMRPrototypeError.rasterizationFailed(pageIndex: preparedPage.pageIndex)
        }
        return NativeOMRRenderedPage(
            pageIndex: preparedPage.pageIndex,
            pixelWidth: preparedPage.image.width,
            pixelHeight: preparedPage.image.height,
            imageData: data
        )
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

    private func analyze(page: PreparedPageImage, prediction: VocalDiveOMRPagePrediction) throws -> NativeOMRPageNotation {
        let raster = try makeAnalysisRaster(from: page.image)
        let darkCoverage = raster.darkCoverage
        let modelStaffRows = prediction.stafflineRowFractions(targetCount: raster.height)
        let smoothedRows = smoothProjection(
            mergedStaffProjection(rasterRows: raster.rowDarkFractions, modelRows: modelStaffRows),
            radius: 10
        )
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

        let confidence = min(0.94, max(0.36, darkCoverage * 4 + Double(systems.count) * 0.06 + prediction.confidence * 0.16))
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

    private func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
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

    private func mergedStaffProjection(rasterRows: [Double], modelRows: [Double]) -> [Double] {
        guard rasterRows.count == modelRows.count, let modelPeak = modelRows.max(), modelPeak > 0.001 else {
            return rasterRows
        }

        let rasterPeak = max(rasterRows.max() ?? 0.001, 0.001)
        return zip(rasterRows, modelRows).map { raster, model in
            let normalizedRaster = raster / rasterPeak
            let normalizedModel = model / modelPeak
            return normalizedRaster * 0.35 + normalizedModel * 0.65
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

private struct VocalDiveOMRModelReadiness {
    var isReady: Bool
    var message: String
}

private struct VocalDiveOMRPagePrediction {
    var pageIndex: Int
    var stafflineMap: VocalDiveOMRPredictionMap?
    var symbolMap: VocalDiveOMRPredictionMap?
    var confidence: Double

    func stafflineRowFractions(targetCount: Int) -> [Double] {
        guard let stafflineMap else {
            return []
        }
        return stafflineMap.rowProjection(channel: 1, targetCount: targetCount)
    }
}

private struct VocalDiveOMRPredictionMap {
    var width: Int
    var height: Int
    var channels: Int
    var values: [Float]

    func channelMean(_ channel: Int) -> Double {
        guard channels > channel, width > 0, height > 0 else {
            return 0
        }
        var total = 0.0
        var count = 0
        for row in 0..<height {
            for column in 0..<width {
                total += Double(value(row: row, column: column, channel: channel))
                count += 1
            }
        }
        return total / Double(max(count, 1))
    }

    func rowProjection(channel: Int, targetCount: Int) -> [Double] {
        guard channels > channel, width > 0, height > 0, targetCount > 0 else {
            return []
        }

        let raw = (0..<height).map { row in
            var total = 0.0
            for column in 0..<width {
                total += Double(value(row: row, column: column, channel: channel))
            }
            return total / Double(width)
        }

        guard raw.count != targetCount else {
            return raw
        }

        return (0..<targetCount).map { index in
            let source = Double(index) * Double(max(raw.count - 1, 0)) / Double(max(targetCount - 1, 1))
            let lower = max(0, min(raw.count - 1, Int(source.rounded(.down))))
            let upper = max(0, min(raw.count - 1, lower + 1))
            let weight = source - Double(lower)
            return raw[lower] * (1 - weight) + raw[upper] * weight
        }
    }

    private func value(row: Int, column: Int, channel: Int) -> Float {
        values[(row * width + column) * channels + channel]
    }
}

private final class VocalDiveOMRModelService {
    private let firstModelName = "oemer_1st_model"
    private let secondModelName = "oemer_2nd_model"

    func readiness() -> VocalDiveOMRModelReadiness {
        #if canImport(CoreML)
        guard compiledModelURL(named: firstModelName) != nil else {
            return VocalDiveOMRModelReadiness(
                isReady: false,
                message: "Missing OMRModels/\(firstModelName).mlmodelc in the app bundle. Convert oemer 1st_model.onnx before enabling Scan to MusicXML."
            )
        }
        guard compiledModelURL(named: secondModelName) != nil else {
            return VocalDiveOMRModelReadiness(
                isReady: false,
                message: "Missing OMRModels/\(secondModelName).mlmodelc in the app bundle. Convert oemer 2nd_model.onnx before enabling Scan to MusicXML."
            )
        }
        return VocalDiveOMRModelReadiness(isReady: true, message: "oemer Core ML models are bundled.")
        #else
        return VocalDiveOMRModelReadiness(isReady: false, message: "Core ML is unavailable on this platform.")
        #endif
    }

    func predict(page: PreparedPageImage) throws -> VocalDiveOMRPagePrediction {
        #if canImport(CoreML)
        let firstModel = try loadModel(named: firstModelName)
        let secondModel = try loadModel(named: secondModelName)

        let firstFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input": makeInputFeatureValue(for: firstModel, image: page.image, fallbackWidth: 256, fallbackHeight: 256)
        ])
        let secondFeatures = try MLDictionaryFeatureProvider(dictionary: [
            "input": makeInputFeatureValue(for: secondModel, image: page.image, fallbackWidth: 288, fallbackHeight: 288)
        ])
        let firstOutput = try firstModel.prediction(from: firstFeatures)
        let secondOutput = try secondModel.prediction(from: secondFeatures)

        let firstMap = predictionMap(from: firstOutput.featureValue(for: "prediction")?.multiArrayValue)
        let secondMap = predictionMap(from: secondOutput.featureValue(for: "conv2d_25")?.multiArrayValue)
        let confidence = [
            confidence(from: firstMap),
            confidence(from: secondMap)
        ].reduce(0, +) / 2
        return VocalDiveOMRPagePrediction(
            pageIndex: page.pageIndex,
            stafflineMap: firstMap,
            symbolMap: secondMap,
            confidence: confidence
        )
        #else
        throw NativeOMRPrototypeError.oemerModelUnavailable("Core ML is unavailable on this platform.")
        #endif
    }

    #if canImport(CoreML)
    private func compiledModelURL(named name: String) -> URL? {
        Bundle.main.url(forResource: name, withExtension: "mlmodelc", subdirectory: "OMRModels")
            ?? Bundle.main.url(forResource: name, withExtension: "mlmodelc")
    }

    private func loadModel(named name: String) throws -> MLModel {
        guard let url = compiledModelURL(named: name) else {
            throw NativeOMRPrototypeError.oemerModelUnavailable("Missing \(name).mlmodelc")
        }
        return try MLModel(contentsOf: url)
    }

    private func makeInputFeatureValue(
        for model: MLModel,
        image: CGImage,
        fallbackWidth: Int,
        fallbackHeight: Int
    ) throws -> MLFeatureValue {
        let inputDescription = model.modelDescription.inputDescriptionsByName["input"]
        if let imageConstraint = inputDescription?.imageConstraint {
            let width = imageConstraint.pixelsWide > 0 ? imageConstraint.pixelsWide : fallbackWidth
            let height = imageConstraint.pixelsHigh > 0 ? imageConstraint.pixelsHigh : fallbackHeight
            return try MLFeatureValue(pixelBuffer: makePixelBuffer(from: image, width: width, height: height))
        }

        if let multiArrayConstraint = inputDescription?.multiArrayConstraint {
            return MLFeatureValue(
                multiArray: try makeImageMultiArray(
                    from: image,
                    constraint: multiArrayConstraint,
                    fallbackWidth: fallbackWidth,
                    fallbackHeight: fallbackHeight
                )
            )
        }

        return try MLFeatureValue(pixelBuffer: makePixelBuffer(from: image, width: fallbackWidth, height: fallbackHeight))
    }

    private func makePixelBuffer(from image: CGImage, width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw NativeOMRPrototypeError.unreadableDocument
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw NativeOMRPrototypeError.unreadableDocument
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelBuffer
    }

    private func makeImageMultiArray(
        from image: CGImage,
        constraint: MLMultiArrayConstraint,
        fallbackWidth: Int,
        fallbackHeight: Int
    ) throws -> MLMultiArray {
        let shape = staticShape(from: constraint.shape)
        let layout = inputLayout(from: shape)
        let width = layout.width ?? fallbackWidth
        let height = layout.height ?? fallbackHeight
        let channels = layout.channels ?? 3
        let pixels = try makeRGBBytes(from: image, width: width, height: height)
        let dataType = constraint.dataType == .double ? MLMultiArrayDataType.double : .float32
        let arrayShape = shape.isEmpty ? [1, height, width, channels] : shape
        let multiArray = try MLMultiArray(shape: arrayShape.map(NSNumber.init(value:)), dataType: dataType)

        for row in 0..<height {
            for column in 0..<width {
                for channel in 0..<min(channels, 3) {
                    let pixelOffset = (row * width + column) * 4 + channel
                    let value = NSNumber(value: Float(pixels[pixelOffset]))
                    let arrayOffset: [Int]
                    switch layout.order {
                    case .nchw:
                        arrayOffset = [0, channel, row, column]
                    case .chw:
                        arrayOffset = [channel, row, column]
                    case .hwc:
                        arrayOffset = [row, column, channel]
                    case .nhwc:
                        arrayOffset = [0, row, column, channel]
                    }
                    multiArray[arrayOffset.map(NSNumber.init(value:))] = value
                }
            }
        }

        return multiArray
    }

    private enum MultiArrayImageOrder {
        case nhwc
        case nchw
        case hwc
        case chw
    }

    private func staticShape(from shape: [NSNumber]) -> [Int] {
        shape.map(\.intValue).filter { $0 > 0 }
    }

    private func inputLayout(from shape: [Int]) -> (order: MultiArrayImageOrder, width: Int?, height: Int?, channels: Int?) {
        guard !shape.isEmpty else {
            return (.nhwc, nil, nil, nil)
        }

        if shape.count == 4 {
            if shape[1] == 1 || shape[1] == 3 || shape[1] == 4 {
                return (.nchw, shape[3], shape[2], shape[1])
            }
            return (.nhwc, shape[2], shape[1], shape[3])
        }

        if shape.count == 3 {
            if shape[0] == 1 || shape[0] == 3 || shape[0] == 4 {
                return (.chw, shape[2], shape[1], shape[0])
            }
            return (.hwc, shape[1], shape[0], shape[2])
        }

        return (.nhwc, nil, nil, nil)
    }

    private func makeRGBBytes(from image: CGImage, width: Int, height: Int) throws -> [UInt8] {
        var bytes = Array(repeating: UInt8(255), count: width * height * 4)
        guard let context = CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw NativeOMRPrototypeError.unreadableDocument
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return bytes
    }

    private func predictionMap(from array: MLMultiArray?) -> VocalDiveOMRPredictionMap? {
        guard let array else {
            return nil
        }

        let shape = array.shape.map(\.intValue)
        let strides = array.strides.map(\.intValue)
        let width: Int
        let height: Int
        let channels: Int
        let layout: MultiArrayImageOrder
        let rank = shape.count
        if rank == 4 {
            if shape[1] <= 16, shape[2] > 16, shape[3] > 16 {
                layout = .nchw
                channels = shape[1]
                height = shape[2]
                width = shape[3]
            } else {
                layout = .nhwc
                height = shape[1]
                width = shape[2]
                channels = shape[3]
            }
        } else if rank == 3 {
            if shape[0] <= 16, shape[1] > 16, shape[2] > 16 {
                layout = .chw
                channels = shape[0]
                height = shape[1]
                width = shape[2]
            } else {
                layout = .hwc
                height = shape[0]
                width = shape[1]
                channels = shape[2]
            }
        } else {
            return nil
        }
        guard width > 0, height > 0, channels > 0 else {
            return nil
        }

        var values = Array(repeating: Float(0), count: width * height * channels)
        for row in 0..<height {
            for column in 0..<width {
                for channel in 0..<channels {
                    let offset: Int
                    switch layout {
                    case .nhwc:
                        offset = row * strides[1] + column * strides[2] + channel * strides[3]
                    case .nchw:
                        offset = channel * strides[1] + row * strides[2] + column * strides[3]
                    case .hwc:
                        offset = row * strides[0] + column * strides[1] + channel * strides[2]
                    case .chw:
                        offset = channel * strides[0] + row * strides[1] + column * strides[2]
                    }
                    values[(row * width + column) * channels + channel] = array[offset].floatValue
                }
            }
        }

        return VocalDiveOMRPredictionMap(
            width: width,
            height: height,
            channels: channels,
            values: values
        )
    }

    private func confidence(from map: VocalDiveOMRPredictionMap?) -> Double {
        guard let map else {
            return 0
        }
        if map.channels > 1 {
            let activeMeans = (1..<map.channels).map(map.channelMean)
            return min(1, max(0, activeMeans.max() ?? 0))
        }
        return min(1, max(0, map.channelMean(0)))
    }
    #endif
}
