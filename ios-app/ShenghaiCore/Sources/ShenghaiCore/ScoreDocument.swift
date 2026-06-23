import Foundation

public struct ScoreDocument: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var sourceFormat: String
    public var metadata: ScoreMetadata
    public var divisions: Int
    public var ticksPerQuarter: Int
    public var tempoBPM: Int
    public var parts: [ScorePart]
    public var expandedMeasureOrder: [ExpandedMeasure]
    public var corrections: [ScoreCorrection]

    public init(
        schemaVersion: String = "0.1",
        sourceFormat: String = "MusicXML",
        metadata: ScoreMetadata = ScoreMetadata(),
        divisions: Int,
        ticksPerQuarter: Int = 480,
        tempoBPM: Int = 96,
        parts: [ScorePart],
        expandedMeasureOrder: [ExpandedMeasure],
        corrections: [ScoreCorrection] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sourceFormat = sourceFormat
        self.metadata = metadata
        self.divisions = divisions
        self.ticksPerQuarter = ticksPerQuarter
        self.tempoBPM = tempoBPM
        self.parts = parts
        self.expandedMeasureOrder = expandedMeasureOrder
        self.corrections = corrections
    }
}

public struct ScoreMetadata: Codable, Equatable, Sendable {
    public var title: String?
    public var composer: String?
    public var lyricist: String?
    public var arranger: String?
    public var copyright: String?

    public init(
        title: String? = nil,
        composer: String? = nil,
        lyricist: String? = nil,
        arranger: String? = nil,
        copyright: String? = nil
    ) {
        self.title = title
        self.composer = composer
        self.lyricist = lyricist
        self.arranger = arranger
        self.copyright = copyright
    }
}

public struct ScorePart: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var measures: [ScoreMeasure]

    public init(id: String, name: String, measures: [ScoreMeasure]) {
        self.id = id
        self.name = name
        self.measures = measures
    }
}

public struct ScoreMeasure: Codable, Equatable, Sendable, Identifiable {
    public var id: String { number }
    public var number: String
    public var beats: Int?
    public var beatType: Int?
    public var keyFifths: Int?
    public var clefSign: String?
    public var clefLine: Int?
    public var repeatStart: Bool
    public var repeatEnd: Bool
    public var directions: [ScoreDirection]
    public var notes: [ScoreNote]

    public init(
        number: String,
        beats: Int? = nil,
        beatType: Int? = nil,
        keyFifths: Int? = nil,
        clefSign: String? = nil,
        clefLine: Int? = nil,
        repeatStart: Bool = false,
        repeatEnd: Bool = false,
        directions: [ScoreDirection] = [],
        notes: [ScoreNote]
    ) {
        self.number = number
        self.beats = beats
        self.beatType = beatType
        self.keyFifths = keyFifths
        self.clefSign = clefSign
        self.clefLine = clefLine
        self.repeatStart = repeatStart
        self.repeatEnd = repeatEnd
        self.directions = directions
        self.notes = notes
    }
}

public struct ScoreDirection: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var kind: String
    public var value: String
    public var placement: String?
    public var tick: Int

    public init(id: String = UUID().uuidString, kind: String, value: String, placement: String? = nil, tick: Int) {
        self.id = id
        self.kind = kind
        self.value = value
        self.placement = placement
        self.tick = tick
    }
}

public struct ScoreNote: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var step: String?
    public var alter: Int
    public var octave: Int?
    public var duration: Int
    public var noteType: String?
    public var isRest: Bool
    public var midi: Int?
    public var startTick: Int
    public var durationTick: Int
    public var lyrics: [ScoreLyric]

    public init(
        id: String = UUID().uuidString,
        step: String?,
        alter: Int,
        octave: Int?,
        duration: Int,
        noteType: String?,
        isRest: Bool,
        midi: Int?,
        startTick: Int,
        durationTick: Int,
        lyrics: [ScoreLyric] = []
    ) {
        self.id = id
        self.step = step
        self.alter = alter
        self.octave = octave
        self.duration = duration
        self.noteType = noteType
        self.isRest = isRest
        self.midi = midi
        self.startTick = startTick
        self.durationTick = durationTick
        self.lyrics = lyrics
    }
}

public struct ScoreLyric: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var number: String?
    public var syllabic: String?
    public var text: String

    public init(id: String = UUID().uuidString, number: String? = nil, syllabic: String? = nil, text: String) {
        self.id = id
        self.number = number
        self.syllabic = syllabic
        self.text = text
    }
}

public struct ExpandedMeasure: Codable, Equatable, Sendable {
    public var partID: String
    public var measureNumber: String

    public init(partID: String, measureNumber: String) {
        self.partID = partID
        self.measureNumber = measureNumber
    }
}

public struct ScoreCorrection: Codable, Equatable, Sendable {
    public var partID: String
    public var measureNumber: String
    public var symbolID: String
    public var symbolKind: String
    public var field: String
    public var value: String

    public init(partID: String, measureNumber: String, symbolID: String, symbolKind: String, field: String, value: String) {
        self.partID = partID
        self.measureNumber = measureNumber
        self.symbolID = symbolID
        self.symbolKind = symbolKind
        self.field = field
        self.value = value
    }
}

public struct PlaybackEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case noteOn
        case noteOff
    }

    public var tick: Int
    public var midi: Int
    public var velocity: UInt8
    public var kind: Kind

    public init(tick: Int, midi: Int, velocity: UInt8, kind: Kind) {
        self.tick = tick
        self.midi = midi
        self.velocity = velocity
        self.kind = kind
    }
}
