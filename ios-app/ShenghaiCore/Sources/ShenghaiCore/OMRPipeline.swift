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

public enum OMRProvider: String, Codable, CaseIterable, Sendable {
    case homr
    case oemer

    public var displayName: String {
        switch self {
        case .homr:
            return "homr"
        case .oemer:
            return "oemer"
        }
    }

    public var summary: String {
        switch self {
        case .homr:
            return "Camera/photo-oriented OMR that produces machine-readable MusicXML."
        case .oemer:
            return "Deep-learning OMR baseline for skewed or phone-taken score images."
        }
    }

    public var bestFor: String {
        switch self {
        case .homr:
            return "Phone photos, quick MusicXML trials, and future Mac/server helper research."
        case .oemer:
            return "Research comparison, skewed images, and MusicXML output benchmarking."
        }
    }

    public var licenseNote: String {
        switch self {
        case .homr:
            return "AGPL-3.0 project; keep as an external pipeline until launch/legal review."
        case .oemer:
            return "Open-source ML tool with model checkpoints; review code/model licenses before bundling."
        }
    }

    public var runsInsideAppleApp: Bool {
        false
    }
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
    public var provider: OMRProvider?
    public var stages: [OMRStagePlan]

    public init(inputKind: OMRInputKind, provider: OMRProvider? = nil, stages: [OMRStagePlan]) {
        self.inputKind = inputKind
        self.provider = provider
        self.stages = stages
    }

    public static func mvpBaseline(inputKind: OMRInputKind, provider: OMRProvider? = nil) -> OMRPipelinePlan {
        OMRPipelinePlan(
            inputKind: inputKind,
            provider: provider,
            stages: [
                OMRStagePlan(stage: .captureOrImport, status: .ready, note: "Use iOS document/photo import or macOS file import."),
                OMRStagePlan(stage: .imagePreprocessing, status: .planned, note: "Prioritize de-skew, contrast normalization, and clean binarization before recognition."),
                OMRStagePlan(stage: .omrRecognition, status: .planned, note: recognitionNote(for: provider)),
                OMRStagePlan(stage: .musicXMLExport, status: .ready, note: "MusicXML remains the canonical interchange output."),
                OMRStagePlan(stage: .scoreDocumentImport, status: .ready, note: "Existing MusicXMLImporter converts the output into ScoreDocument."),
                OMRStagePlan(stage: .manualCorrection, status: .planned, note: "Needed because OMR accuracy is not perfect, especially with dense scores."),
                OMRStagePlan(stage: .playbackValidation, status: .ready, note: "Existing MIDIWriter can validate playable notes after import.")
            ]
        )
    }

    private static func recognitionNote(for provider: OMRProvider?) -> String {
        guard let provider else {
            return "Choose homr or oemer as an external MusicXML-producing OMR pipeline."
        }

        return "Use \(provider.displayName) outside the app, then import its MusicXML output."
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

public struct OMRProviderCommandPlan: Codable, Equatable, Sendable {
    public var provider: OMRProvider
    public var inputPath: String
    public var outputPath: String

    public init(provider: OMRProvider, inputPath: String, outputPath: String) {
        self.provider = provider
        self.inputPath = inputPath
        self.outputPath = outputPath
    }

    public var commandName: String {
        provider.rawValue
    }

    public var arguments: [String] {
        switch provider {
        case .homr:
            return [
                inputPath,
                "--output",
                outputPath
            ]
        case .oemer:
            return [
                "-o",
                outputPath,
                inputPath
            ]
        }
    }

    public var setupNote: String {
        switch provider {
        case .homr:
            return "Install and run homr in a reviewed external environment, then import the MusicXML output into Shenghai."
        case .oemer:
            return "Install oemer and its model checkpoints in a reviewed external environment, then import the MusicXML output into Shenghai."
        }
    }

    public var shellPreview: String {
        ([commandName] + arguments)
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
