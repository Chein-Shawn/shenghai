import Foundation

public struct ScoreDocument: Codable, Equatable, Sendable {
    public var schemaVersion: String
    public var sourceFormat: String
    public var divisions: Int
    public var ticksPerQuarter: Int
    public var tempoBPM: Int
    public var parts: [ScorePart]
    public var expandedMeasureOrder: [ExpandedMeasure]
    public var corrections: [ScoreCorrection]

    public init(
        schemaVersion: String = "0.1",
        sourceFormat: String = "MusicXML",
        divisions: Int,
        ticksPerQuarter: Int = 480,
        tempoBPM: Int = 96,
        parts: [ScorePart],
        expandedMeasureOrder: [ExpandedMeasure],
        corrections: [ScoreCorrection] = []
    ) {
        self.schemaVersion = schemaVersion
        self.sourceFormat = sourceFormat
        self.divisions = divisions
        self.ticksPerQuarter = ticksPerQuarter
        self.tempoBPM = tempoBPM
        self.parts = parts
        self.expandedMeasureOrder = expandedMeasureOrder
        self.corrections = corrections
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
    public var repeatStart: Bool
    public var repeatEnd: Bool
    public var notes: [ScoreNote]

    public init(
        number: String,
        beats: Int? = nil,
        beatType: Int? = nil,
        repeatStart: Bool = false,
        repeatEnd: Bool = false,
        notes: [ScoreNote]
    ) {
        self.number = number
        self.beats = beats
        self.beatType = beatType
        self.repeatStart = repeatStart
        self.repeatEnd = repeatEnd
        self.notes = notes
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
        durationTick: Int
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
    public var measureNumber: String
    public var noteID: String
    public var field: String
    public var value: String

    public init(measureNumber: String, noteID: String, field: String, value: String) {
        self.measureNumber = measureNumber
        self.noteID = noteID
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
