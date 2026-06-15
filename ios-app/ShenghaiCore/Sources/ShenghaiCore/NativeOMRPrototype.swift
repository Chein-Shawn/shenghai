import Foundation

public struct NativeOMRNormalizedRect: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct NativeOMRTileMetadata: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var pageIndex: Int
    public var tileIndex: Int
    public var bounds: NativeOMRNormalizedRect

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int,
        tileIndex: Int,
        bounds: NativeOMRNormalizedRect
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.tileIndex = tileIndex
        self.bounds = bounds
    }
}

public struct NativeOMRPagePreparationMetadata: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { pageIndex }
    public var pageIndex: Int
    public var pixelWidth: Int
    public var pixelHeight: Int
    public var tiles: [NativeOMRTileMetadata]

    public init(pageIndex: Int, pixelWidth: Int, pixelHeight: Int, tiles: [NativeOMRTileMetadata]) {
        self.pageIndex = pageIndex
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.tiles = tiles
    }
}

public enum NativeOMRPageRecognitionStatus: String, Codable, Equatable, Sendable {
    case recognized
    case partial
    case failed
}

public struct NativeOMRDetectedSystem: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var pageIndex: Int
    public var systemIndex: Int
    public var bounds: NativeOMRNormalizedRect
    public var estimatedMeasureCount: Int

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int,
        systemIndex: Int,
        bounds: NativeOMRNormalizedRect,
        estimatedMeasureCount: Int
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.systemIndex = systemIndex
        self.bounds = bounds
        self.estimatedMeasureCount = estimatedMeasureCount
    }
}

public struct NativeOMRDetectedMeasure: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var pageIndex: Int
    public var systemIndex: Int
    public var measureIndexOnPage: Int
    public var globalMeasureIndex: Int
    public var bounds: NativeOMRNormalizedRect

    public init(
        id: String = UUID().uuidString,
        pageIndex: Int,
        systemIndex: Int,
        measureIndexOnPage: Int,
        globalMeasureIndex: Int,
        bounds: NativeOMRNormalizedRect
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.systemIndex = systemIndex
        self.measureIndexOnPage = measureIndexOnPage
        self.globalMeasureIndex = globalMeasureIndex
        self.bounds = bounds
    }
}

public enum NativeOMRDetectedEventKind: String, Codable, Equatable, Sendable {
    case note
    case rest
}

public struct NativeOMRDetectedEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var measureID: String
    public var beatIndex: Int
    public var kind: NativeOMRDetectedEventKind
    public var step: String?
    public var alter: Int
    public var octave: Int?
    public var durationDivisions: Int
    public var bounds: NativeOMRNormalizedRect?

    public init(
        id: String = UUID().uuidString,
        measureID: String,
        beatIndex: Int,
        kind: NativeOMRDetectedEventKind,
        step: String?,
        alter: Int = 0,
        octave: Int?,
        durationDivisions: Int,
        bounds: NativeOMRNormalizedRect? = nil
    ) {
        self.id = id
        self.measureID = measureID
        self.beatIndex = beatIndex
        self.kind = kind
        self.step = step
        self.alter = alter
        self.octave = octave
        self.durationDivisions = durationDivisions
        self.bounds = bounds
    }
}

public struct NativeOMRPageNotation: Codable, Equatable, Sendable, Identifiable {
    public var id: Int { pageIndex }
    public var pageIndex: Int
    public var status: NativeOMRPageRecognitionStatus
    public var preparation: NativeOMRPagePreparationMetadata
    public var systems: [NativeOMRDetectedSystem]
    public var measures: [NativeOMRDetectedMeasure]
    public var events: [NativeOMRDetectedEvent]
    public var confidence: Double

    public init(
        pageIndex: Int,
        status: NativeOMRPageRecognitionStatus,
        preparation: NativeOMRPagePreparationMetadata,
        systems: [NativeOMRDetectedSystem],
        measures: [NativeOMRDetectedMeasure],
        events: [NativeOMRDetectedEvent],
        confidence: Double
    ) {
        self.pageIndex = pageIndex
        self.status = status
        self.preparation = preparation
        self.systems = systems
        self.measures = measures
        self.events = events
        self.confidence = confidence
    }
}

public struct NativeOMRScoreNotation: Codable, Equatable, Sendable {
    public var sourceName: String
    public var inputKind: OMRInputKind
    public var partName: String
    public var beats: Int
    public var beatType: Int
    public var keyFifths: Int
    public var pageResults: [NativeOMRPageNotation]
    public var mergedMeasures: [NativeOMRDetectedMeasure]
    public var mergedEvents: [NativeOMRDetectedEvent]
    public var failedPageIndices: [Int]

    public init(
        sourceName: String,
        inputKind: OMRInputKind,
        partName: String,
        beats: Int,
        beatType: Int,
        keyFifths: Int,
        pageResults: [NativeOMRPageNotation],
        mergedMeasures: [NativeOMRDetectedMeasure],
        mergedEvents: [NativeOMRDetectedEvent],
        failedPageIndices: [Int]
    ) {
        self.sourceName = sourceName
        self.inputKind = inputKind
        self.partName = partName
        self.beats = beats
        self.beatType = beatType
        self.keyFifths = keyFifths
        self.pageResults = pageResults
        self.mergedMeasures = mergedMeasures
        self.mergedEvents = mergedEvents
        self.failedPageIndices = failedPageIndices
    }
}
