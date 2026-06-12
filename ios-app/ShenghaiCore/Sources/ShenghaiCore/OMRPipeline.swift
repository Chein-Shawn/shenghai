import Foundation

public enum OMRInputKind: String, Codable, Sendable {
    case image
    case pdf
    case musicXML
}

public enum OMRPipelineStage: String, Codable, CaseIterable, Sendable {
    case captureOrImport
    case fullPageElementCapture
    case imagePreprocessing
    case omrRecognition
    case musicXMLExport
    case editableMusicXMLReview
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
            return L10n.tr("Camera/photo-oriented OMR that produces machine-readable MusicXML.")
        case .oemer:
            return L10n.tr("Deep-learning OMR baseline for skewed or phone-taken score images.")
        }
    }

    public var bestFor: String {
        switch self {
        case .homr:
            return L10n.tr("Phone photos, quick MusicXML trials, and future Mac/server helper research.")
        case .oemer:
            return L10n.tr("Research comparison, skewed images, and MusicXML output benchmarking.")
        }
    }

    public var licenseNote: String {
        switch self {
        case .homr:
            return L10n.tr("AGPL-3.0 project; keep as an external pipeline until launch/legal review.")
        case .oemer:
            return L10n.tr("Open-source ML tool with model checkpoints; review code/model licenses before bundling.")
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
                OMRStagePlan(stage: .captureOrImport, status: .ready, note: L10n.tr("Use iOS document/photo import or macOS file import.")),
                OMRStagePlan(stage: .fullPageElementCapture, status: .planned, note: L10n.tr("Capture notes, rests, lyrics, dynamics, tempo text, articulations, repeats, and layout-critical markings into editable MusicXML.")),
                OMRStagePlan(stage: .imagePreprocessing, status: .planned, note: L10n.tr("Prioritize de-skew, contrast normalization, and clean binarization before recognition.")),
                OMRStagePlan(stage: .omrRecognition, status: .planned, note: recognitionNote(for: provider)),
                OMRStagePlan(stage: .musicXMLExport, status: .ready, note: L10n.tr("MusicXML remains the canonical interchange output.")),
                OMRStagePlan(stage: .editableMusicXMLReview, status: .ready, note: L10n.tr("User checks the scanned MusicXML candidate before using it for notes, playback, and practice feedback.")),
                OMRStagePlan(stage: .scoreDocumentImport, status: .ready, note: L10n.tr("Existing MusicXMLImporter converts the output into ScoreDocument.")),
                OMRStagePlan(stage: .manualCorrection, status: .planned, note: L10n.tr("Needed because OMR accuracy is not perfect, especially with dense scores.")),
                OMRStagePlan(stage: .playbackValidation, status: .ready, note: L10n.tr("Existing MIDIWriter can validate playable notes after import."))
            ]
        )
    }

    private static func recognitionNote(for provider: OMRProvider?) -> String {
        guard let provider else {
            return L10n.tr("Choose homr or oemer as an external MusicXML-producing OMR pipeline.")
        }

        return L10n.tr("Use %@ outside the app, then import its MusicXML output.", provider.displayName)
    }
}

public enum OMRRecognizedElementKind: String, Codable, CaseIterable, Sendable {
    case metadata
    case parts
    case measures
    case notes
    case rests
    case lyrics
    case directions
    case repeats
    case layout

    public var displayName: String {
        switch self {
        case .metadata:
            return L10n.tr("Title and credits")
        case .parts:
            return L10n.tr("Parts and staves")
        case .measures:
            return L10n.tr("Measures")
        case .notes:
            return L10n.tr("Notes")
        case .rests:
            return L10n.tr("Rests")
        case .lyrics:
            return L10n.tr("Lyrics")
        case .directions:
            return L10n.tr("Directions and markings")
        case .repeats:
            return L10n.tr("Repeats")
        case .layout:
            return L10n.tr("Layout")
        }
    }
}

public struct OMRRecognizedElementSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { kind.rawValue }
    public var kind: OMRRecognizedElementKind
    public var count: Int
    public var needsUserReview: Bool
    public var note: String

    public init(kind: OMRRecognizedElementKind, count: Int, needsUserReview: Bool, note: String) {
        self.kind = kind
        self.count = count
        self.needsUserReview = needsUserReview
        self.note = note
    }
}

public struct OMRMusicXMLCandidate: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var sourceName: String
    public var inputKind: OMRInputKind
    public var provider: OMRProvider
    public var score: ScoreDocument
    public var recognizedElements: [OMRRecognizedElementSummary]
    public var reviewChecklist: [String]
    public var canEnterPracticeWorkflow: Bool

    public init(
        id: String = UUID().uuidString,
        sourceName: String,
        inputKind: OMRInputKind,
        provider: OMRProvider,
        score: ScoreDocument,
        recognizedElements: [OMRRecognizedElementSummary],
        reviewChecklist: [String],
        canEnterPracticeWorkflow: Bool
    ) {
        self.id = id
        self.sourceName = sourceName
        self.inputKind = inputKind
        self.provider = provider
        self.score = score
        self.recognizedElements = recognizedElements
        self.reviewChecklist = reviewChecklist
        self.canEnterPracticeWorkflow = canEnterPracticeWorkflow
    }
}

public enum OMRMusicXMLCandidateBuilder {
    public static func makeCandidate(
        sourceName: String,
        inputKind: OMRInputKind,
        provider: OMRProvider,
        score: ScoreDocument
    ) -> OMRMusicXMLCandidate {
        let measures = score.parts.flatMap(\.measures)
        let notes = measures.flatMap(\.notes)
        let lyricCount = notes.flatMap(\.lyrics).count
        let directionCount = measures.flatMap(\.directions).count
        let repeatCount = measures.filter { $0.repeatStart || $0.repeatEnd }.count
        let metadataCount = [
            score.metadata.title,
            score.metadata.composer,
            score.metadata.lyricist,
            score.metadata.arranger,
            score.metadata.copyright
        ].compactMap { $0 }.count

        let summaries = [
            OMRRecognizedElementSummary(kind: .metadata, count: metadataCount, needsUserReview: true, note: L10n.tr("Check title, composer, lyricist, arranger, and copyright.")),
            OMRRecognizedElementSummary(kind: .parts, count: score.parts.count, needsUserReview: true, note: L10n.tr("Check SATB/instrument names and staff mapping.")),
            OMRRecognizedElementSummary(kind: .measures, count: measures.count, needsUserReview: true, note: L10n.tr("Check measure count, time signature changes, and barlines.")),
            OMRRecognizedElementSummary(kind: .notes, count: notes.filter { !$0.isRest }.count, needsUserReview: true, note: L10n.tr("Check pitch, octave, rhythm, ties, and voice assignment.")),
            OMRRecognizedElementSummary(kind: .rests, count: notes.filter { $0.isRest }.count, needsUserReview: true, note: L10n.tr("Check rests and empty measures.")),
            OMRRecognizedElementSummary(kind: .lyrics, count: lyricCount, needsUserReview: lyricCount > 0, note: L10n.tr("Check syllables, hyphenation, melisma, and verse numbers.")),
            OMRRecognizedElementSummary(kind: .directions, count: directionCount, needsUserReview: directionCount > 0, note: L10n.tr("Check tempo words, dynamics, rehearsal text, and expressive markings.")),
            OMRRecognizedElementSummary(kind: .repeats, count: repeatCount, needsUserReview: repeatCount > 0, note: L10n.tr("Check repeat starts, endings, D.C./D.S., coda, and expanded playback order.")),
            OMRRecognizedElementSummary(kind: .layout, count: 0, needsUserReview: true, note: L10n.tr("Check page/system layout visually against the source PDF or image."))
        ]

        return OMRMusicXMLCandidate(
            sourceName: sourceName,
            inputKind: inputKind,
            provider: provider,
            score: score,
            recognizedElements: summaries,
            reviewChecklist: [
                L10n.tr("Compare every staff, measure, note, rest, lyric, dynamic, tempo word, repeat, and rehearsal marking against the original PDF/image."),
                L10n.tr("Correct the MusicXML candidate first; then use the corrected file for annotation, playback, pitch tracking, and practice history."),
                L10n.tr("Do not treat OMR output as final until playback and visual review both pass.")
            ],
            canEnterPracticeWorkflow: !score.parts.isEmpty && !notes.isEmpty
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
