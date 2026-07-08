import Foundation

public enum MusicXMLImportError: Error, LocalizedError, Sendable {
    case invalidDocument
    case parserFailure(String)

    public var errorDescription: String? {
        switch self {
        case .invalidDocument:
            return "The MusicXML document could not be parsed."
        case .parserFailure(let message):
            return message
        }
    }
}

public final class MusicXMLImporter: NSObject, XMLParserDelegate {
    private let defaultTempoBPM: Int
    private let ticksPerQuarter: Int

    private var parserError: Error?
    private var elementStack: [String] = []
    private var textBuffer = ""

    private var partNames: [String: String] = [:]
    private var scorePartID: String?
    private var currentPartID: String?
    private var currentPartMeasures: [ScoreMeasure] = []
    private var parts: [ScorePart] = []
    private var expandedMeasureOrder: [ExpandedMeasure] = []
    private var metadata = ScoreMetadata()
    private var creatorType: String?

    private var globalDivisions = 1
    private var activeDivisions = 1
    private var parsedTempoBPM: Int?
    private var activeBeats: Int?
    private var activeBeatType: Int?
    private var activeKeyFifths: Int?
    private var activeClefSign: String?
    private var activeClefLine: Int?
    private var currentMeasureNumber: String?
    private var currentMeasureNotes: [ScoreNote] = []
    private var currentMeasureBeats: Int?
    private var currentMeasureBeatType: Int?
    private var currentMeasureKeyFifths: Int?
    private var currentMeasureClefSign: String?
    private var currentMeasureClefLine: Int?
    private var currentMeasureRepeatStart = false
    private var currentMeasureRepeatEnd = false
    private var currentMeasureDirections: [ScoreDirection] = []
    private var currentTick = 0

    private var inNote = false
    private var inDirection = false
    private var directionPlacement: String?
    private var noteStep: String?
    private var noteAlter = 0
    private var noteOctave: Int?
    private var noteDuration = 0
    private var noteType: String?
    private var noteIsRest = false
    private var noteLyrics: [ScoreLyric] = []
    private var lyricNumber: String?
    private var lyricSyllabic: String?

    public init(tempoBPM: Int = 96, ticksPerQuarter: Int = 480) {
        self.defaultTempoBPM = tempoBPM
        self.ticksPerQuarter = ticksPerQuarter
    }

    public func importDocument(data: Data) throws -> ScoreDocument {
        reset()
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            if let parserError {
                throw parserError
            }
            if let error = parser.parserError {
                throw MusicXMLImportError.parserFailure(error.localizedDescription)
            }
            throw MusicXMLImportError.invalidDocument
        }

        return ScoreDocument(
            metadata: metadata,
            divisions: globalDivisions,
            ticksPerQuarter: ticksPerQuarter,
            tempoBPM: parsedTempoBPM ?? defaultTempoBPM,
            parts: parts,
            expandedMeasureOrder: expandedMeasureOrder
        )
    }

    public func importDocument(url: URL) throws -> ScoreDocument {
        try importDocument(data: Data(contentsOf: url))
    }

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        textBuffer = ""

        switch elementName {
        case "score-part":
            scorePartID = attributeDict["id"]
        case "part":
            currentPartID = attributeDict["id"]
            currentPartMeasures = []
            currentTick = 0
            activeDivisions = globalDivisions
            activeBeats = nil
            activeBeatType = nil
            activeKeyFifths = nil
            activeClefSign = nil
            activeClefLine = nil
        case "measure":
            currentMeasureNumber = attributeDict["number"] ?? "\(currentPartMeasures.count + 1)"
            currentMeasureNotes = []
            currentMeasureDirections = []
            currentMeasureBeats = activeBeats
            currentMeasureBeatType = activeBeatType
            currentMeasureKeyFifths = activeKeyFifths
            currentMeasureClefSign = activeClefSign
            currentMeasureClefLine = activeClefLine
            currentMeasureRepeatStart = false
            currentMeasureRepeatEnd = false
        case "creator":
            creatorType = attributeDict["type"]
        case "direction":
            inDirection = true
            directionPlacement = attributeDict["placement"]
        case "p", "pp", "ppp", "f", "ff", "fff", "mp", "mf", "sfz", "fp":
            if inDirection, isInside("dynamics") {
                currentMeasureDirections.append(
                    ScoreDirection(
                        id: "\(currentPartID ?? "part")-\(currentMeasureNumber ?? "measure")-dynamic-\(currentMeasureDirections.count)",
                        kind: "dynamics",
                        value: elementName,
                        placement: directionPlacement,
                        tick: currentTick
                    )
                )
            }
        case "note":
            inNote = true
            noteStep = nil
            noteAlter = 0
            noteOctave = nil
            noteDuration = 0
            noteType = nil
            noteIsRest = false
            noteLyrics = []
            lyricNumber = nil
            lyricSyllabic = nil
        case "lyric":
            if inNote {
                lyricNumber = attributeDict["number"]
                lyricSyllabic = nil
            }
        case "rest":
            if inNote {
                noteIsRest = true
            }
        case "sound":
            if let tempoValue = attributeDict["tempo"], let tempo = Double(tempoValue), tempo > 0 {
                parsedTempoBPM = Int(tempo.rounded())
            }
        case "repeat":
            switch attributeDict["direction"] {
            case "forward":
                currentMeasureRepeatStart = true
            case "backward":
                currentMeasureRepeatEnd = true
            default:
                break
            }
        default:
            break
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "work-title", "movement-title":
            if !value.isEmpty, metadata.title == nil {
                metadata.title = value
            }
        case "creator":
            assignCreator(value)
            creatorType = nil
        case "rights":
            if !value.isEmpty {
                metadata.copyright = value
            }
        case "part-name":
            if let scorePartID, !value.isEmpty {
                partNames[scorePartID] = value
            }
        case "divisions":
            if let divisions = Int(value), divisions > 0 {
                activeDivisions = divisions
                globalDivisions = divisions
            }
        case "beats":
            if isInside("time"), let beats = Int(value), beats > 0 {
                activeBeats = beats
                currentMeasureBeats = beats
            }
        case "beat-type":
            if isInside("time"), let beatType = Int(value), beatType > 0 {
                activeBeatType = beatType
                currentMeasureBeatType = beatType
            }
        case "fifths":
            if isInside("key"), let fifths = Int(value) {
                activeKeyFifths = fifths
                currentMeasureKeyFifths = fifths
            }
        case "sign":
            if isInside("clef"), !value.isEmpty {
                activeClefSign = value
                currentMeasureClefSign = value
            }
        case "line":
            if isInside("clef"), let line = Int(value), line > 0 {
                activeClefLine = line
                currentMeasureClefLine = line
            }
        case "step":
            if inNote {
                noteStep = value
            }
        case "alter":
            if inNote {
                noteAlter = Int(value) ?? 0
            }
        case "octave":
            if inNote {
                noteOctave = Int(value)
            }
        case "duration":
            if inNote {
                noteDuration = Int(value) ?? 0
            }
        case "type":
            if inNote {
                noteType = value.isEmpty ? nil : value
            }
        case "syllabic":
            if inNote, isInside("lyric") {
                lyricSyllabic = value.isEmpty ? nil : value
            }
        case "text":
            if inNote, isInside("lyric"), !value.isEmpty {
                noteLyrics.append(
                    ScoreLyric(
                        id: "\(currentPartID ?? "part")-\(currentMeasureNumber ?? "measure")-lyric-\(currentMeasureNotes.count)-\(noteLyrics.count)",
                        number: lyricNumber,
                        syllabic: lyricSyllabic,
                        text: value
                    )
                )
            }
        case "words":
            if inDirection, !value.isEmpty {
                currentMeasureDirections.append(
                    ScoreDirection(
                        id: "\(currentPartID ?? "part")-\(currentMeasureNumber ?? "measure")-direction-\(currentMeasureDirections.count)",
                        kind: "words",
                        value: value,
                        placement: directionPlacement,
                        tick: currentTick
                    )
                )
            }
        case "direction":
            inDirection = false
            directionPlacement = nil
        case "note":
            finishNote()
        case "measure":
            finishMeasure()
        case "part":
            finishPart()
        case "score-part":
            scorePartID = nil
        default:
            break
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
        textBuffer = ""
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = MusicXMLImportError.parserFailure(parseError.localizedDescription)
    }

    private func reset() {
        parserError = nil
        elementStack = []
        textBuffer = ""
        partNames = [:]
        scorePartID = nil
        currentPartID = nil
        currentPartMeasures = []
        parts = []
        expandedMeasureOrder = []
        metadata = ScoreMetadata()
        creatorType = nil
        globalDivisions = 1
        activeDivisions = 1
        parsedTempoBPM = nil
        activeBeats = nil
        activeBeatType = nil
        activeKeyFifths = nil
        activeClefSign = nil
        activeClefLine = nil
        currentMeasureNumber = nil
        currentMeasureNotes = []
        currentMeasureDirections = []
        currentMeasureBeats = nil
        currentMeasureBeatType = nil
        currentMeasureKeyFifths = nil
        currentMeasureClefSign = nil
        currentMeasureClefLine = nil
        currentMeasureRepeatStart = false
        currentMeasureRepeatEnd = false
        currentTick = 0
        inNote = false
        inDirection = false
        directionPlacement = nil
        noteLyrics = []
        lyricNumber = nil
        lyricSyllabic = nil
    }

    private func finishNote() {
        let durationTick = noteDuration * ticksPerQuarter / max(activeDivisions, 1)
        let midi: Int?
        if let noteStep, let noteOctave, !noteIsRest {
            midi = Self.midiNumber(step: noteStep, alter: noteAlter, octave: noteOctave)
        } else {
            midi = nil
        }

        let note = ScoreNote(
            id: "\(currentPartID ?? "part")-\(currentMeasureNumber ?? "measure")-\(currentMeasureNotes.count)",
            step: noteStep,
            alter: noteAlter,
            octave: noteOctave,
            duration: noteDuration,
            noteType: noteType,
            isRest: noteIsRest,
            midi: midi,
            startTick: currentTick,
            durationTick: durationTick,
            lyrics: noteLyrics
        )
        currentMeasureNotes.append(note)
        currentTick += durationTick
        inNote = false
        noteLyrics = []
        lyricNumber = nil
        lyricSyllabic = nil
    }

    private func finishMeasure() {
        let number = currentMeasureNumber ?? "\(currentPartMeasures.count + 1)"
        currentPartMeasures.append(
            ScoreMeasure(
                number: number,
                beats: currentMeasureBeats,
                beatType: currentMeasureBeatType,
                keyFifths: currentMeasureKeyFifths,
                clefSign: currentMeasureClefSign,
                clefLine: currentMeasureClefLine,
                repeatStart: currentMeasureRepeatStart,
                repeatEnd: currentMeasureRepeatEnd,
                directions: currentMeasureDirections,
                notes: currentMeasureNotes
            )
        )
        if let currentPartID {
            expandedMeasureOrder.append(ExpandedMeasure(partID: currentPartID, measureNumber: number))
        }
        currentMeasureNumber = nil
        currentMeasureNotes = []
        currentMeasureDirections = []
        currentMeasureBeats = nil
        currentMeasureBeatType = nil
        currentMeasureKeyFifths = nil
        currentMeasureClefSign = nil
        currentMeasureClefLine = nil
        currentMeasureRepeatStart = false
        currentMeasureRepeatEnd = false
    }

    private func finishPart() {
        guard let currentPartID else {
            return
        }
        parts.append(
            ScorePart(
                id: currentPartID,
                name: partNames[currentPartID] ?? currentPartID,
                measures: currentPartMeasures
            )
        )
        self.currentPartID = nil
        currentPartMeasures = []
    }

    private static func midiNumber(step: String, alter: Int, octave: Int) -> Int? {
        let semitoneByStep = [
            "C": 0,
            "D": 2,
            "E": 4,
            "F": 5,
            "G": 7,
            "A": 9,
            "B": 11
        ]
        guard let semitone = semitoneByStep[step] else {
            return nil
        }
        return (octave + 1) * 12 + semitone + alter
    }

    private func isInside(_ elementName: String) -> Bool {
        elementStack.contains(elementName)
    }

    private func assignCreator(_ value: String) {
        guard !value.isEmpty else {
            return
        }

        switch creatorType?.lowercased() {
        case "composer":
            metadata.composer = value
        case "lyricist":
            metadata.lyricist = value
        case "arranger":
            metadata.arranger = value
        default:
            if metadata.composer == nil {
                metadata.composer = value
            }
        }
    }
}
