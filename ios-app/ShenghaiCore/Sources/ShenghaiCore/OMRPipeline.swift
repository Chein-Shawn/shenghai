import Foundation

public enum OMRInputKind: String, Codable, Sendable {
    case image
    case pdf
    case musicXML
}

public enum OMRPipelineStage: String, Codable, CaseIterable, Sendable {
    case captureOrImport
    case imagePreprocessing
    case omrRecognition
    case musicXMLExport
    case scoreDocumentImport
    case manualCorrection
    case playbackValidation
}

public enum OMRPipelineStatus: String, Codable, Sendable {
    case planned
    case ready
    case blocked
}

public struct OMRStagePlan: Codable, Equatable, Sendable, Identifiable {
    public var id: String { stage.rawValue }
    public var stage: OMRPipelineStage
    public var status: OMRPipelineStatus
    public var note: String

    public init(stage: OMRPipelineStage, status: OMRPipelineStatus, note: String) {
        self.stage = stage
        self.status = status
        self.note = note
    }
}

public struct OMRPipelinePlan: Codable, Equatable, Sendable {
    public var inputKind: OMRInputKind
    public var stages: [OMRStagePlan]

    public init(inputKind: OMRInputKind, stages: [OMRStagePlan]) {
        self.inputKind = inputKind
        self.stages = stages
    }

    public static func mvpBaseline(inputKind: OMRInputKind) -> OMRPipelinePlan {
        OMRPipelinePlan(
            inputKind: inputKind,
            stages: [
                OMRStagePlan(stage: .captureOrImport, status: .ready, note: "Use iOS document/photo import or macOS file import."),
                OMRStagePlan(stage: .imagePreprocessing, status: .planned, note: "Prioritize de-skew, contrast normalization, and clean binarization before recognition."),
                OMRStagePlan(stage: .omrRecognition, status: .blocked, note: "Use Audiveris release build first; keep deep-learning OMR as later research."),
                OMRStagePlan(stage: .musicXMLExport, status: .ready, note: "MusicXML remains the canonical interchange output."),
                OMRStagePlan(stage: .scoreDocumentImport, status: .ready, note: "Existing MusicXMLImporter converts the output into ScoreDocument."),
                OMRStagePlan(stage: .manualCorrection, status: .planned, note: "Needed because OMR accuracy is not perfect, especially with dense scores."),
                OMRStagePlan(stage: .playbackValidation, status: .ready, note: "Existing MIDIWriter can validate playable notes after import.")
            ]
        )
    }
}

public struct AudiverisCommandPlan: Codable, Equatable, Sendable {
    public var executablePath: String
    public var inputPath: String
    public var outputDirectory: String

    public init(
        executablePath: String = "/Applications/Audiveris.app/Contents/MacOS/Audiveris",
        inputPath: String,
        outputDirectory: String
    ) {
        self.executablePath = executablePath
        self.inputPath = inputPath
        self.outputDirectory = outputDirectory
    }

    public var arguments: [String] {
        [
            "-batch",
            "-transcribe",
            "-export",
            "-output",
            outputDirectory,
            inputPath
        ]
    }

    public var shellPreview: String {
        ([executablePath] + arguments)
            .map(Self.shellEscaped)
            .joined(separator: " ")
    }

    private static func shellEscaped(_ value: String) -> String {
        if value.rangeOfCharacter(from: CharacterSet.whitespacesAndNewlines.union(.init(charactersIn: "'\""))) == nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
