import Foundation

public struct LocalizedTextToken: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var arguments: [String]

    public init(_ key: String, arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }
}

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
    case nativePrototype

    public var displayName: String {
        switch self {
        case .homr:
            return "homr"
        case .oemer:
            return "oemer"
        case .nativePrototype:
            return "VocalDive Native"
        }
    }

    public var summaryText: LocalizedTextToken {
        switch self {
        case .homr:
            return LocalizedTextToken("omr.provider.homr.summary")
        case .oemer:
            return LocalizedTextToken("omr.provider.oemer.summary")
        case .nativePrototype:
            return LocalizedTextToken("omr.provider.native_prototype.summary")
        }
    }

    public var bestForText: LocalizedTextToken {
        switch self {
        case .homr:
            return LocalizedTextToken("omr.provider.homr.best_for")
        case .oemer:
            return LocalizedTextToken("omr.provider.oemer.best_for")
        case .nativePrototype:
            return LocalizedTextToken("omr.provider.native_prototype.best_for")
        }
    }

    public var licenseNoteText: LocalizedTextToken {
        switch self {
        case .homr:
            return LocalizedTextToken("omr.provider.homr.license_note")
        case .oemer:
            return LocalizedTextToken("omr.provider.oemer.license_note")
        case .nativePrototype:
            return LocalizedTextToken("omr.provider.native_prototype.license_note")
        }
    }

    public var runsInsideAppleApp: Bool {
        self == .nativePrototype
    }
}

public struct OMRStagePlan: Codable, Equatable, Sendable, Identifiable {
    public var id: String { stage.rawValue }
    public var stage: OMRPipelineStage
    public var status: OMRPipelineStatus
    public var note: LocalizedTextToken

    public init(stage: OMRPipelineStage, status: OMRPipelineStatus, note: LocalizedTextToken) {
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
                OMRStagePlan(stage: .captureOrImport, status: .ready, note: LocalizedTextToken("omr.stage.capture_or_import.note")),
                OMRStagePlan(stage: .fullPageElementCapture, status: .planned, note: LocalizedTextToken("omr.stage.full_page_element_capture.note")),
                OMRStagePlan(stage: .imagePreprocessing, status: .planned, note: LocalizedTextToken("omr.stage.image_preprocessing.note")),
                OMRStagePlan(stage: .omrRecognition, status: .planned, note: recognitionNote(for: provider)),
                OMRStagePlan(stage: .musicXMLExport, status: .ready, note: LocalizedTextToken("omr.stage.musicxml_export.note")),
                OMRStagePlan(stage: .editableMusicXMLReview, status: .ready, note: LocalizedTextToken("omr.stage.editable_musicxml_review.note")),
                OMRStagePlan(stage: .scoreDocumentImport, status: .ready, note: LocalizedTextToken("omr.stage.scoredocument_import.note")),
                OMRStagePlan(stage: .manualCorrection, status: .planned, note: LocalizedTextToken("omr.stage.manual_correction.note")),
                OMRStagePlan(stage: .playbackValidation, status: .ready, note: LocalizedTextToken("omr.stage.playback_validation.note"))
            ]
        )
    }

    private static func recognitionNote(for provider: OMRProvider?) -> LocalizedTextToken {
        guard let provider else {
            return LocalizedTextToken("omr.stage.omr_recognition.choose_provider")
        }

        return LocalizedTextToken("omr.stage.omr_recognition.use_provider", arguments: [provider.displayName])
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

    public var displayKey: String {
        switch self {
        case .metadata:
            return "omr.element.metadata"
        case .parts:
            return "omr.element.parts"
        case .measures:
            return "omr.element.measures"
        case .notes:
            return "omr.element.notes"
        case .rests:
            return "omr.element.rests"
        case .lyrics:
            return "omr.element.lyrics"
        case .directions:
            return "omr.element.directions"
        case .repeats:
            return "omr.element.repeats"
        case .layout:
            return "omr.element.layout"
        }
    }
}

public struct OMRRecognizedElementSummary: Codable, Equatable, Sendable, Identifiable {
    public var id: String { kind.rawValue }
    public var kind: OMRRecognizedElementKind
    public var count: Int
    public var needsUserReview: Bool
    public var note: LocalizedTextToken

    public init(kind: OMRRecognizedElementKind, count: Int, needsUserReview: Bool, note: LocalizedTextToken) {
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
    public var reviewChecklist: [LocalizedTextToken]
    public var canEnterPracticeWorkflow: Bool

    public init(
        id: String = UUID().uuidString,
        sourceName: String,
        inputKind: OMRInputKind,
        provider: OMRProvider,
        score: ScoreDocument,
        recognizedElements: [OMRRecognizedElementSummary],
        reviewChecklist: [LocalizedTextToken],
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
            OMRRecognizedElementSummary(kind: .metadata, count: metadataCount, needsUserReview: true, note: LocalizedTextToken("omr.review.metadata.note")),
            OMRRecognizedElementSummary(kind: .parts, count: score.parts.count, needsUserReview: true, note: LocalizedTextToken("omr.review.parts.note")),
            OMRRecognizedElementSummary(kind: .measures, count: measures.count, needsUserReview: true, note: LocalizedTextToken("omr.review.measures.note")),
            OMRRecognizedElementSummary(kind: .notes, count: notes.filter { !$0.isRest }.count, needsUserReview: true, note: LocalizedTextToken("omr.review.notes.note")),
            OMRRecognizedElementSummary(kind: .rests, count: notes.filter { $0.isRest }.count, needsUserReview: true, note: LocalizedTextToken("omr.review.rests.note")),
            OMRRecognizedElementSummary(kind: .lyrics, count: lyricCount, needsUserReview: lyricCount > 0, note: LocalizedTextToken("omr.review.lyrics.note")),
            OMRRecognizedElementSummary(kind: .directions, count: directionCount, needsUserReview: directionCount > 0, note: LocalizedTextToken("omr.review.directions.note")),
            OMRRecognizedElementSummary(kind: .repeats, count: repeatCount, needsUserReview: repeatCount > 0, note: LocalizedTextToken("omr.review.repeats.note")),
            OMRRecognizedElementSummary(kind: .layout, count: 0, needsUserReview: true, note: LocalizedTextToken("omr.review.layout.note"))
        ]

        return OMRMusicXMLCandidate(
            sourceName: sourceName,
            inputKind: inputKind,
            provider: provider,
            score: score,
            recognizedElements: summaries,
            reviewChecklist: [
                LocalizedTextToken("omr.checklist.compare_source"),
                LocalizedTextToken("omr.checklist.correct_candidate"),
                LocalizedTextToken("omr.checklist.do_not_treat_as_final")
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
        case .nativePrototype:
            return []
        }
    }

    public var setupNote: String {
        switch provider {
        case .homr:
            return "Install and run homr in a reviewed external environment, then import the MusicXML output into VocalDive."
        case .oemer:
            return "Install oemer and its model checkpoints in a reviewed external environment, then import the MusicXML output into VocalDive."
        case .nativePrototype:
            return "Run VocalDive's native prototype pipeline in-app: rasterize pages, estimate notation structure, generate MusicXML, then review every page."
        }
    }

    public var shellPreview: String {
        guard !provider.runsInsideAppleApp else {
            return provider.displayName
        }
        return ([commandName] + arguments)
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
