import Foundation

public enum ComposedPitchStep: String, CaseIterable, Codable, Sendable {
    case C
    case D
    case E
    case F
    case G
    case A
    case B

    var semitone: Int {
        switch self {
        case .C:
            return 0
        case .D:
            return 2
        case .E:
            return 4
        case .F:
            return 5
        case .G:
            return 7
        case .A:
            return 9
        case .B:
            return 11
        }
    }
}

public enum ComposedNoteValue: String, CaseIterable, Codable, Sendable, Identifiable {
    case whole
    case half
    case quarter
    case eighth

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .whole:
            return "Whole"
        case .half:
            return "Half"
        case .quarter:
            return "Quarter"
        case .eighth:
            return "Eighth"
        }
    }

    public var musicXMLType: String {
        rawValue
    }

    public var durationUnits: Int {
        switch self {
        case .whole:
            return 8
        case .half:
            return 4
        case .quarter:
            return 2
        case .eighth:
            return 1
        }
    }
}

public struct ComposedPitch: Codable, Equatable, Sendable {
    public var step: ComposedPitchStep
    public var alter: Int
    public var octave: Int

    public init(step: ComposedPitchStep, alter: Int = 0, octave: Int = 4) {
        self.step = step
        self.alter = alter
        self.octave = octave
    }

    public var midi: Int {
        (octave + 1) * 12 + step.semitone + alter
    }

    public var displayName: String {
        let accidental: String
        switch alter {
        case 1:
            accidental = "#"
        case -1:
            accidental = "b"
        default:
            accidental = ""
        }
        return "\(step.rawValue)\(accidental)\(octave)"
    }
}

public struct ComposedScoreNote: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var pitch: ComposedPitch?
    public var value: ComposedNoteValue

    public init(id: UUID = UUID(), pitch: ComposedPitch?, value: ComposedNoteValue) {
        self.id = id
        self.pitch = pitch
        self.value = value
    }

    public var isRest: Bool {
        pitch == nil
    }

    public var displayName: String {
        if let pitch {
            return "\(pitch.displayName) \(value.displayName)"
        }
        return "Rest \(value.displayName)"
    }
}

public struct ComposedScore: Codable, Equatable, Sendable {
    public var title: String
    public var partName: String
    public var tempoBPM: Int
    public var beats: Int
    public var beatType: Int
    public var notes: [ComposedScoreNote]

    public init(
        title: String = "Untitled Shenghai Score",
        partName: String = "Voice",
        tempoBPM: Int = 96,
        beats: Int = 4,
        beatType: Int = 4,
        notes: [ComposedScoreNote] = []
    ) {
        self.title = title
        self.partName = partName
        self.tempoBPM = tempoBPM
        self.beats = beats
        self.beatType = beatType
        self.notes = notes
    }
}

public enum MusicXMLComposer {
    public static let divisions = 2
    public static let ticksPerQuarter = 480

    public static func makeScoreDocument(from composedScore: ComposedScore) -> ScoreDocument {
        let measures = makeMeasures(from: composedScore)
        let part = ScorePart(id: "P1", name: composedScore.partName.trimmedOrFallback("Voice"), measures: measures)
        let expandedOrder = measures.map { ExpandedMeasure(partID: part.id, measureNumber: $0.number) }
        return ScoreDocument(
            sourceFormat: "Shenghai Composer",
            metadata: ScoreMetadata(title: composedScore.title.trimmedOrFallback("Untitled Shenghai Score")),
            divisions: divisions,
            ticksPerQuarter: ticksPerQuarter,
            tempoBPM: composedScore.tempoBPM,
            parts: [part],
            expandedMeasureOrder: expandedOrder
        )
    }

    public static func makeMusicXML(from composedScore: ComposedScore) -> String {
        let title = composedScore.title.trimmedOrFallback("Untitled Shenghai Score")
        let partName = composedScore.partName.trimmedOrFallback("Voice")
        let measureGroups = makeMeasureGroups(from: composedScore)

        let measures = measureGroups.enumerated().map { index, group in
            makeMusicXMLMeasure(
                number: index + 1,
                group: group,
                includeAttributes: index == 0,
                tempoBPM: composedScore.tempoBPM,
                beats: composedScore.beats,
                beatType: composedScore.beatType
            )
        }.joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="no"?>
        <!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "https://www.musicxml.org/dtds/partwise.dtd">
        <score-partwise version="4.0">
          <work>
            <work-title>\(escapeXML(title))</work-title>
          </work>
          <part-list>
            <score-part id="P1">
              <part-name>\(escapeXML(partName))</part-name>
            </score-part>
          </part-list>
          <part id="P1">
        \(measures)
          </part>
        </score-partwise>
        """
    }

    private static func makeMeasures(from composedScore: ComposedScore) -> [ScoreMeasure] {
        let groups = makeMeasureGroups(from: composedScore)
        var absoluteTick = 0
        return groups.enumerated().map { measureIndex, group in
            let notes = group.enumerated().map { noteIndex, note in
                let durationTick = note.value.durationUnits * ticksPerQuarter / divisions
                let scoreNote = ScoreNote(
                    id: "P1-\(measureIndex + 1)-\(noteIndex)",
                    step: note.pitch?.step.rawValue,
                    alter: note.pitch?.alter ?? 0,
                    octave: note.pitch?.octave,
                    duration: note.value.durationUnits,
                    noteType: note.value.musicXMLType,
                    isRest: note.isRest,
                    midi: note.pitch?.midi,
                    startTick: absoluteTick,
                    durationTick: durationTick
                )
                absoluteTick += durationTick
                return scoreNote
            }

            return ScoreMeasure(
                number: "\(measureIndex + 1)",
                beats: measureIndex == 0 ? composedScore.beats : nil,
                beatType: measureIndex == 0 ? composedScore.beatType : nil,
                notes: notes
            )
        }
    }

    private static func makeMeasureGroups(from composedScore: ComposedScore) -> [[ComposedScoreNote]] {
        let capacity = max(1, composedScore.beats * divisions * 4 / max(composedScore.beatType, 1))
        var groups: [[ComposedScoreNote]] = [[]]
        var remaining = capacity

        for note in composedScore.notes {
            if note.value.durationUnits > remaining, !groups[groups.count - 1].isEmpty {
                groups.append([])
                remaining = capacity
            }

            groups[groups.count - 1].append(note)
            remaining -= note.value.durationUnits

            if remaining <= 0 {
                groups.append([])
                remaining = capacity
            }
        }

        if groups.last?.isEmpty == true, groups.count > 1 {
            groups.removeLast()
        }

        return groups.isEmpty ? [[]] : groups
    }

    private static func makeMusicXMLMeasure(
        number: Int,
        group: [ComposedScoreNote],
        includeAttributes: Bool,
        tempoBPM: Int,
        beats: Int,
        beatType: Int
    ) -> String {
        var lines: [String] = ["    <measure number=\"\(number)\">"]

        if includeAttributes {
            lines.append("""
              <attributes>
                <divisions>\(divisions)</divisions>
                <key>
                  <fifths>0</fifths>
                </key>
                <time>
                  <beats>\(beats)</beats>
                  <beat-type>\(beatType)</beat-type>
                </time>
                <clef>
                  <sign>G</sign>
                  <line>2</line>
                </clef>
              </attributes>
              <direction placement="above">
                <direction-type>
                  <metronome>
                    <beat-unit>quarter</beat-unit>
                    <per-minute>\(tempoBPM)</per-minute>
                  </metronome>
                </direction-type>
                <sound tempo="\(tempoBPM)"/>
              </direction>
            """)
        }

        for note in group {
            lines.append(makeMusicXMLNote(note))
        }

        lines.append("    </measure>")
        return lines.joined(separator: "\n")
    }

    private static func makeMusicXMLNote(_ note: ComposedScoreNote) -> String {
        let pitchXML: String
        if let pitch = note.pitch {
            let alterXML = pitch.alter == 0 ? "" : "\n        <alter>\(pitch.alter)</alter>"
            pitchXML = """
              <pitch>
                <step>\(pitch.step.rawValue)</step>\(alterXML)
                <octave>\(pitch.octave)</octave>
              </pitch>
            """
        } else {
            pitchXML = "      <rest/>"
        }

        return """
              <note>
        \(pitchXML)
                <duration>\(note.value.durationUnits)</duration>
                <type>\(note.value.musicXMLType)</type>
              </note>
        """
    }

    private static func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private extension String {
    func trimmedOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
