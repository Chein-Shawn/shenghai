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
    private let tempoBPM: Int
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

    private var globalDivisions = 1
    private var activeDivisions = 1
    private var currentMeasureNumber: String?
    private var currentMeasureNotes: [ScoreNote] = []
    private var currentTick = 0

    private var inNote = false
    private var noteStep: String?
    private var noteAlter = 0
    private var noteOctave: Int?
    private var noteDuration = 0
    private var noteType: String?
    private var noteIsRest = false

    public init(tempoBPM: Int = 96, ticksPerQuarter: Int = 480) {
        self.tempoBPM = tempoBPM
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
            divisions: globalDivisions,
            ticksPerQuarter: ticksPerQuarter,
            tempoBPM: tempoBPM,
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
        case "measure":
            currentMeasureNumber = attributeDict["number"] ?? "\(currentPartMeasures.count + 1)"
            currentMeasureNotes = []
        case "note":
            inNote = true
            noteStep = nil
            noteAlter = 0
            noteOctave = nil
            noteDuration = 0
            noteType = nil
            noteIsRest = false
        case "rest":
            if inNote {
                noteIsRest = true
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
        case "part-name":
            if let scorePartID, !value.isEmpty {
                partNames[scorePartID] = value
            }
        case "divisions":
            if let divisions = Int(value), divisions > 0 {
                activeDivisions = divisions
                globalDivisions = divisions
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
        globalDivisions = 1
        activeDivisions = 1
        currentMeasureNumber = nil
        currentMeasureNotes = []
        currentTick = 0
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
            durationTick: durationTick
        )
        currentMeasureNotes.append(note)
        currentTick += durationTick
        inNote = false
    }

    private func finishMeasure() {
        let number = currentMeasureNumber ?? "\(currentPartMeasures.count + 1)"
        currentPartMeasures.append(ScoreMeasure(number: number, notes: currentMeasureNotes))
        if let currentPartID {
            expandedMeasureOrder.append(ExpandedMeasure(partID: currentPartID, measureNumber: number))
        }
        currentMeasureNumber = nil
        currentMeasureNotes = []
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
}
