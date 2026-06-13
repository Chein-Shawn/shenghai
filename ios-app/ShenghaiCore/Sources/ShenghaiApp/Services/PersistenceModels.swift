import Foundation
import CoreGraphics
import SwiftData
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum PersistedScoreSourceType: String, Codable, Sendable {
    case musicXML
    case composed
    case demo
    case pdf
    case image
}

enum SyncState: String, Codable, Sendable {
    case off
    case on
    case syncing
    case unavailable
    case error
}

enum SyncUnavailableReason: String, Codable, Sendable {
    case cloudKitContainerUnavailable
    case iCloudAccountUnavailable
}

struct SyncStatusSnapshot: Sendable {
    var state: SyncState
    var lastSuccessfulSync: Date?
    var lastErrorSummary: String?
    var unavailableReason: SyncUnavailableReason?
    var canEnable: Bool
}

struct PersistedUserSettingsSnapshot: Sendable {
    var selectedLanguage: AppLanguage
    var syncEnabled: Bool
    var didChooseSyncOnLaunch: Bool
    var selectedScoreItemID: String?
}

struct PersistedScoreLoadResult: Sendable {
    var score: ScoreDocument
    var scoreItemID: String
    var annotationStrokes: [ScoreAnnotationStrokePayload]
}

struct AnnotationPointPayload: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}

struct ScoreAnnotationStrokePayload: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var points: [AnnotationPointPayload]
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double
    var lineWidth: Double

    init(
        id: UUID = UUID(),
        points: [AnnotationPointPayload],
        red: Double,
        green: Double,
        blue: Double,
        opacity: Double,
        lineWidth: Double
    ) {
        self.id = id
        self.points = points
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
        self.lineWidth = lineWidth
    }
}

@Model
final class UserProfileSettingsRecord {
    @Attribute(.unique) var id: String
    var selectedLanguageCode: String
    var syncEnabled: Bool
    var didChooseSyncOnLaunch: Bool
    var selectedScoreItemID: String?
    var activeFeatureRawValue: String?
    var activeFeatureStartedAt: Date?
    var updatedAt: Date

    init(
        id: String = PersistenceCoordinator.RecordID.userSettings,
        selectedLanguageCode: String = AppLanguage.english.rawValue,
        syncEnabled: Bool = false,
        didChooseSyncOnLaunch: Bool = false,
        selectedScoreItemID: String? = nil,
        activeFeatureRawValue: String? = nil,
        activeFeatureStartedAt: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.selectedLanguageCode = selectedLanguageCode
        self.syncEnabled = syncEnabled
        self.didChooseSyncOnLaunch = didChooseSyncOnLaunch
        self.selectedScoreItemID = selectedScoreItemID
        self.activeFeatureRawValue = activeFeatureRawValue
        self.activeFeatureStartedAt = activeFeatureStartedAt
        self.updatedAt = updatedAt
    }
}

@Model
final class ScoreLibraryItemRecord {
    @Attribute(.unique) var id: String
    var title: String
    var sourceTypeRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var checksum: String
    var relativeFilePath: String

    init(
        id: String = UUID().uuidString,
        title: String,
        sourceTypeRawValue: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        checksum: String,
        relativeFilePath: String
    ) {
        self.id = id
        self.title = title
        self.sourceTypeRawValue = sourceTypeRawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.checksum = checksum
        self.relativeFilePath = relativeFilePath
    }
}

@Model
final class ScoreAnnotationDocumentRecord {
    @Attribute(.unique) var id: String
    var scoreItemID: String
    var encodedStrokes: Data
    var updatedAt: Date

    init(
        id: String,
        scoreItemID: String,
        encodedStrokes: Data,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.scoreItemID = scoreItemID
        self.encodedStrokes = encodedStrokes
        self.updatedAt = updatedAt
    }
}

@Model
final class PracticeSessionRecord {
    @Attribute(.unique) var id: String
    var scoreItemID: String?
    var partID: String?
    var mode: String
    var startedAt: Date
    var endedAt: Date
    var summaryJSON: Data?

    init(
        id: String = UUID().uuidString,
        scoreItemID: String?,
        partID: String?,
        mode: String,
        startedAt: Date,
        endedAt: Date,
        summaryJSON: Data? = nil
    ) {
        self.id = id
        self.scoreItemID = scoreItemID
        self.partID = partID
        self.mode = mode
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.summaryJSON = summaryJSON
    }
}

@Model
final class TrainingStatisticsSnapshotRecord {
    @Attribute(.unique) var id: String
    var scope: String
    var createdAt: Date
    var totalPracticeSeconds: Double
    var averagePitchScore: Double
    var averageRhythmScore: Double

    init(
        id: String = UUID().uuidString,
        scope: String,
        createdAt: Date = Date(),
        totalPracticeSeconds: Double = 0,
        averagePitchScore: Double = 0,
        averageRhythmScore: Double = 0
    ) {
        self.id = id
        self.scope = scope
        self.createdAt = createdAt
        self.totalPracticeSeconds = totalPracticeSeconds
        self.averagePitchScore = averagePitchScore
        self.averageRhythmScore = averageRhythmScore
    }
}

@Model
final class UsageAnalyticsRecord {
    @Attribute(.unique) var id: String
    var featureRawValue: String
    var startedAt: Date
    var endedAt: Date

    init(
        id: String = UUID().uuidString,
        featureRawValue: String,
        startedAt: Date,
        endedAt: Date
    ) {
        self.id = id
        self.featureRawValue = featureRawValue
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

@Model
final class SyncStatusRecord {
    @Attribute(.unique) var id: String
    var currentStateRawValue: String
    var lastSuccessfulSync: Date?
    var lastErrorSummary: String?
    var unavailableReasonRawValue: String?
    var updatedAt: Date

    init(
        id: String = PersistenceCoordinator.RecordID.syncStatus,
        currentStateRawValue: String = SyncState.off.rawValue,
        lastSuccessfulSync: Date? = nil,
        lastErrorSummary: String? = nil,
        unavailableReasonRawValue: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.currentStateRawValue = currentStateRawValue
        self.lastSuccessfulSync = lastSuccessfulSync
        self.lastErrorSummary = lastErrorSummary
        self.unavailableReasonRawValue = unavailableReasonRawValue
        self.updatedAt = updatedAt
    }
}
