import Foundation
import SwiftData
import CloudKit
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

@MainActor
final class PersistenceCoordinator {
    enum RecordID {
        static let userSettings = "user-settings"
        static let syncStatus = "sync-status"
    }

    static let shared = PersistenceCoordinator()

    let importedAssetStore: ImportedAssetStore

    private let defaults: UserDefaults
    private let importer = MusicXMLImporter()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let schema = Schema([
        UserProfileSettingsRecord.self,
        ScoreLibraryItemRecord.self,
        ScoreAnnotationDocumentRecord.self,
        PracticeSessionRecord.self,
        TrainingStatisticsSnapshotRecord.self,
        UsageAnalyticsRecord.self,
        SyncStatusRecord.self
    ])

    private let localContainer: ModelContainer
    private let cloudContainer: ModelContainer?
    private let cloudAvailabilityReason: SyncUnavailableReason?
    private var activeStorageMode: StorageMode

    private enum StorageMode {
        case local
        case cloud
    }

    private enum DefaultsKey {
        static let legacyLanguage = "shenghai.displayLanguage"
        static let legacyUsageLedger = "shenghai.usageLedger.v1"
        static let syncPreference = "shenghai.syncEnabledPreference.v1"
        static let usageMigrated = "shenghai.usageMigration.v1"
        static let settingsMigrated = "shenghai.settingsMigration.v1"
    }

    init(
        defaults: UserDefaults = .standard,
        importedAssetStore: ImportedAssetStore = ImportedAssetStore()
    ) {
        self.defaults = defaults
        self.importedAssetStore = importedAssetStore

        let localConfiguration = ModelConfiguration(schema: schema, url: Self.storeURL(fileName: "ShenghaiLocal.store"))
        self.localContainer = try! ModelContainer(for: schema, configurations: [localConfiguration])

        if FileManager.default.ubiquityIdentityToken == nil {
            self.cloudContainer = nil
            self.cloudAvailabilityReason = .iCloudAccountUnavailable
        } else {
            do {
                let cloudConfiguration = ModelConfiguration(
                    schema: schema,
                    url: Self.storeURL(fileName: "ShenghaiCloud.store"),
                    cloudKitDatabase: .automatic
                )
                self.cloudContainer = try ModelContainer(for: schema, configurations: [cloudConfiguration])
                self.cloudAvailabilityReason = nil
            } catch {
                self.cloudContainer = nil
                self.cloudAvailabilityReason = .cloudKitContainerUnavailable
            }
        }

        let bootstrapSyncEnabled = defaults.bool(forKey: DefaultsKey.syncPreference)
        if bootstrapSyncEnabled, cloudContainer != nil {
            activeStorageMode = .cloud
        } else {
            activeStorageMode = .local
        }

        bootstrapPersistentState()
    }

    func settingsSnapshot() -> PersistedUserSettingsSnapshot {
        let context = activeContext
        let record = ensureUserSettings(in: context)
        let language = AppLanguage(rawValue: record.selectedLanguageCode) ?? .english
        return PersistedUserSettingsSnapshot(
            selectedLanguage: language,
            syncEnabled: record.syncEnabled,
            didChooseSyncOnLaunch: record.didChooseSyncOnLaunch,
            selectedScoreItemID: record.selectedScoreItemID
        )
    }

    func syncStatusSnapshot() -> SyncStatusSnapshot {
        let context = activeContext
        let record = ensureSyncStatus(in: context)
        let state = SyncState(rawValue: record.currentStateRawValue) ?? .off
        let reason = record.unavailableReasonRawValue.flatMap(SyncUnavailableReason.init(rawValue:))
        let canEnable = cloudContainer != nil && cloudAvailabilityReason == nil
        return SyncStatusSnapshot(
            state: state,
            lastSuccessfulSync: record.lastSuccessfulSync,
            lastErrorSummary: record.lastErrorSummary,
            unavailableReason: reason,
            canEnable: canEnable
        )
    }

    func updateSelectedLanguage(_ language: AppLanguage) {
        let context = activeContext
        let record = ensureUserSettings(in: context)
        record.selectedLanguageCode = language.rawValue
        record.updatedAt = Date()
        save(context)
        defaults.set(language.rawValue, forKey: DefaultsKey.legacyLanguage)
        mirrorUserSettingsToLocalIfNeeded()
    }

    func setSelectedScoreItemID(_ scoreItemID: String?) {
        let context = activeContext
        let record = ensureUserSettings(in: context)
        record.selectedScoreItemID = scoreItemID
        record.updatedAt = Date()
        save(context)
        mirrorUserSettingsToLocalIfNeeded()
    }

    func completeFirstRunSyncChoice(enableSync: Bool) -> SyncStatusSnapshot {
        let currentSettings = settingsSnapshot()
        let _ = setSyncEnabled(enableSync)
        let context = activeContext
        let record = ensureUserSettings(in: context)
        record.didChooseSyncOnLaunch = true
        record.updatedAt = Date()
        save(context)

        if currentSettings.didChooseSyncOnLaunch == false {
            mirrorUserSettingsToLocalIfNeeded()
        }
        return syncStatusSnapshot()
    }

    func setSyncEnabled(_ enabled: Bool) -> SyncStatusSnapshot {
        if enabled {
            guard let cloudContainer else {
                defaults.set(false, forKey: DefaultsKey.syncPreference)
                activeStorageMode = .local
                updateSyncStatus(
                    state: .unavailable,
                    error: nil,
                    unavailableReason: cloudAvailabilityReason ?? .cloudKitContainerUnavailable,
                    markSuccess: false
                )
                return syncStatusSnapshot()
            }

            do {
                try migrateRecords(from: localContainer.mainContext, to: cloudContainer.mainContext)
                activeStorageMode = .cloud
                defaults.set(true, forKey: DefaultsKey.syncPreference)
                let settings = ensureUserSettings(in: activeContext)
                settings.syncEnabled = true
                settings.updatedAt = Date()
                updateSyncStatus(state: .on, error: nil, unavailableReason: nil, markSuccess: true)
                save(activeContext)
            } catch {
                activeStorageMode = .local
                defaults.set(false, forKey: DefaultsKey.syncPreference)
                updateSyncStatus(
                    state: .error,
                    error: error.localizedDescription,
                    unavailableReason: nil,
                    markSuccess: false
                )
            }
        } else {
            if let cloudContainer, activeStorageMode == .cloud {
                do {
                    try migrateRecords(from: cloudContainer.mainContext, to: localContainer.mainContext)
                } catch {
                    updateSyncStatus(
                        state: .error,
                        error: error.localizedDescription,
                        unavailableReason: nil,
                        markSuccess: false
                    )
                }
            }
            activeStorageMode = .local
            defaults.set(false, forKey: DefaultsKey.syncPreference)
            let settings = ensureUserSettings(in: activeContext)
            settings.syncEnabled = false
            settings.updatedAt = Date()
            updateSyncStatus(state: .off, error: nil, unavailableReason: nil, markSuccess: false)
            save(activeContext)
        }

        mirrorUserSettingsToLocalIfNeeded()
        return syncStatusSnapshot()
    }

    func loadUsageLedger() -> UsageAnalyticsLedger {
        let context = activeContext
        let descriptor = FetchDescriptor<UsageAnalyticsRecord>(sortBy: [SortDescriptor(\.startedAt)])
        let records = (try? context.fetch(descriptor)) ?? []
        let events = records.compactMap { record -> UsageSessionEvent? in
            guard let feature = UsageFeature(rawValue: record.featureRawValue) else {
                return nil
            }
            return UsageSessionEvent(
                id: UUID(uuidString: record.id) ?? UUID(),
                feature: feature,
                startedAt: record.startedAt,
                endedAt: record.endedAt
            )
        }

        let settings = ensureUserSettings(in: context)
        let activeFeature = settings.activeFeatureRawValue.flatMap(UsageFeature.init(rawValue:))
        return UsageAnalyticsLedger(
            events: events,
            activeFeature: activeFeature,
            activeStartedAt: settings.activeFeatureStartedAt
        )
    }

    func persistUsageLedger(_ ledger: UsageAnalyticsLedger) {
        let context = activeContext
        let existing = (try? context.fetch(FetchDescriptor<UsageAnalyticsRecord>())) ?? []
        for item in existing {
            context.delete(item)
        }

        for event in ledger.events {
            context.insert(
                UsageAnalyticsRecord(
                    id: event.id.uuidString,
                    featureRawValue: event.feature.rawValue,
                    startedAt: event.startedAt,
                    endedAt: event.endedAt
                )
            )
        }

        let settings = ensureUserSettings(in: context)
        settings.activeFeatureRawValue = ledger.activeFeature?.rawValue
        settings.activeFeatureStartedAt = ledger.activeStartedAt
        settings.updatedAt = Date()
        save(context)
        updateCloudSaveTimestampIfNeeded()
        mirrorUserSettingsToLocalIfNeeded()
    }

    func persistScoreDocument(
        score: ScoreDocument,
        data: Data,
        sourceType: PersistedScoreSourceType,
        preferredFileName: String
    ) throws -> String {
        let storedAsset = try importedAssetStore.writeScoreData(data, preferredName: preferredFileName, fileExtension: "musicxml")
        let context = activeContext
        let existingItems = (try? context.fetch(FetchDescriptor<ScoreLibraryItemRecord>())) ?? []
        let now = Date()

        if let existing = existingItems.first(where: { $0.checksum == storedAsset.checksum }) {
            existing.title = score.metadata.title ?? preferredFileName
            existing.sourceTypeRawValue = sourceType.rawValue
            existing.relativeFilePath = storedAsset.relativePath
            existing.updatedAt = now
            save(context)
            setSelectedScoreItemID(existing.id)
            updateCloudSaveTimestampIfNeeded()
            return existing.id
        }

        let item = ScoreLibraryItemRecord(
            title: score.metadata.title ?? preferredFileName,
            sourceTypeRawValue: sourceType.rawValue,
            createdAt: now,
            updatedAt: now,
            checksum: storedAsset.checksum,
            relativeFilePath: storedAsset.relativePath
        )
        context.insert(item)
        save(context)
        setSelectedScoreItemID(item.id)
        updateCloudSaveTimestampIfNeeded()
        return item.id
    }

    func overwriteScoreDocument(
        itemID: String?,
        score: ScoreDocument,
        data: Data,
        sourceType: PersistedScoreSourceType,
        preferredFileName: String
    ) throws -> String {
        guard let itemID else {
            return try persistScoreDocument(
                score: score,
                data: data,
                sourceType: sourceType,
                preferredFileName: preferredFileName
            )
        }

        let storedAsset = try importedAssetStore.writeScoreData(data, preferredName: preferredFileName, fileExtension: "musicxml")
        let context = activeContext
        let descriptor = FetchDescriptor<ScoreLibraryItemRecord>(
            predicate: #Predicate { $0.id == itemID }
        )
        let now = Date()

        if let existing = try? context.fetch(descriptor).first {
            existing.title = score.metadata.title ?? preferredFileName
            existing.sourceTypeRawValue = sourceType.rawValue
            existing.relativeFilePath = storedAsset.relativePath
            existing.checksum = storedAsset.checksum
            existing.updatedAt = now
            save(context)
            setSelectedScoreItemID(existing.id)
            updateCloudSaveTimestampIfNeeded()
            return existing.id
        }

        return try persistScoreDocument(
            score: score,
            data: data,
            sourceType: sourceType,
            preferredFileName: preferredFileName
        )
    }

    func loadPersistedScore() throws -> PersistedScoreLoadResult? {
        let context = activeContext
        let settings = ensureUserSettings(in: context)
        let items = (try? context.fetch(FetchDescriptor<ScoreLibraryItemRecord>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        guard !items.isEmpty else {
            return nil
        }

        let selectedItem = items.first(where: { $0.id == settings.selectedScoreItemID }) ?? items.first!
        let fileURL = try importedAssetStore.resolveReadURL(relativePath: selectedItem.relativeFilePath)
        let score = try importer.importDocument(url: fileURL)
        let annotations = loadAnnotationStrokes(for: selectedItem.id)
        return PersistedScoreLoadResult(score: score, scoreItemID: selectedItem.id, annotationStrokes: annotations)
    }

    func saveAnnotationStrokes(_ strokes: [ScoreAnnotationStrokePayload], for scoreItemID: String) {
        let context = activeContext
        let descriptor = FetchDescriptor<ScoreAnnotationDocumentRecord>(
            predicate: #Predicate { $0.scoreItemID == scoreItemID }
        )
        let existing = try? context.fetch(descriptor)

        if strokes.isEmpty {
            existing?.forEach(context.delete)
            save(context)
            updateCloudSaveTimestampIfNeeded()
            return
        }

        let payload = (try? encoder.encode(strokes)) ?? Data()
        if let document = existing?.first {
            document.encodedStrokes = payload
            document.updatedAt = Date()
        } else {
            context.insert(
                ScoreAnnotationDocumentRecord(
                    id: "annotation-\(scoreItemID)",
                    scoreItemID: scoreItemID,
                    encodedStrokes: payload
                )
            )
        }
        save(context)
        updateCloudSaveTimestampIfNeeded()
    }

    func loadAnnotationStrokes(for scoreItemID: String) -> [ScoreAnnotationStrokePayload] {
        let context = activeContext
        let descriptor = FetchDescriptor<ScoreAnnotationDocumentRecord>(
            predicate: #Predicate { $0.scoreItemID == scoreItemID }
        )
        guard
            let document = try? context.fetch(descriptor).first,
            let strokes = try? decoder.decode([ScoreAnnotationStrokePayload].self, from: document.encodedStrokes)
        else {
            return []
        }
        return strokes
    }

    private var activeContext: ModelContext {
        switch activeStorageMode {
        case .local:
            return localContainer.mainContext
        case .cloud:
            return cloudContainer?.mainContext ?? localContainer.mainContext
        }
    }

    private func bootstrapPersistentState() {
        migrateLegacySettingsIfNeeded()
        migrateLegacyUsageIfNeeded()

        if defaults.bool(forKey: DefaultsKey.syncPreference), cloudContainer == nil {
            updateSyncStatus(
                state: .unavailable,
                error: nil,
                unavailableReason: cloudAvailabilityReason ?? .cloudKitContainerUnavailable,
                markSuccess: false
            )
        } else if settingsSnapshot().syncEnabled {
            updateSyncStatus(state: .on, error: nil, unavailableReason: nil, markSuccess: false)
        } else {
            updateSyncStatus(state: .off, error: nil, unavailableReason: nil, markSuccess: false)
        }
    }

    private func migrateLegacySettingsIfNeeded() {
        guard defaults.bool(forKey: DefaultsKey.settingsMigrated) == false else {
            _ = ensureUserSettings(in: localContainer.mainContext)
            if let cloudContainer {
                _ = ensureUserSettings(in: cloudContainer.mainContext)
            }
            return
        }

        let localSettings = ensureUserSettings(in: localContainer.mainContext)
        if let rawValue = defaults.string(forKey: DefaultsKey.legacyLanguage),
           let language = AppLanguage(rawValue: rawValue) {
            localSettings.selectedLanguageCode = language.rawValue
        }
        localSettings.syncEnabled = defaults.bool(forKey: DefaultsKey.syncPreference) && cloudContainer != nil
        localSettings.didChooseSyncOnLaunch = defaults.object(forKey: DefaultsKey.syncPreference) != nil
        save(localContainer.mainContext)

        if let cloudContainer {
            let cloudSettings = ensureUserSettings(in: cloudContainer.mainContext)
            cloudSettings.selectedLanguageCode = localSettings.selectedLanguageCode
            cloudSettings.syncEnabled = localSettings.syncEnabled
            cloudSettings.didChooseSyncOnLaunch = localSettings.didChooseSyncOnLaunch
            save(cloudContainer.mainContext)
        }

        defaults.set(true, forKey: DefaultsKey.settingsMigrated)
    }

    private func migrateLegacyUsageIfNeeded() {
        guard defaults.bool(forKey: DefaultsKey.usageMigrated) == false else {
            return
        }
        guard
            let data = defaults.data(forKey: DefaultsKey.legacyUsageLedger),
            let ledger = try? JSONDecoder().decode(UsageAnalyticsLedger.self, from: data)
        else {
            defaults.set(true, forKey: DefaultsKey.usageMigrated)
            return
        }
        persistUsageLedger(ledger)
        defaults.set(true, forKey: DefaultsKey.usageMigrated)
    }

    private func mirrorUserSettingsToLocalIfNeeded() {
        guard activeStorageMode == .cloud else {
            return
        }
        let cloudSettings = ensureUserSettings(in: activeContext)
        let localSettings = ensureUserSettings(in: localContainer.mainContext)
        localSettings.selectedLanguageCode = cloudSettings.selectedLanguageCode
        localSettings.syncEnabled = cloudSettings.syncEnabled
        localSettings.didChooseSyncOnLaunch = cloudSettings.didChooseSyncOnLaunch
        localSettings.selectedScoreItemID = cloudSettings.selectedScoreItemID
        localSettings.activeFeatureRawValue = cloudSettings.activeFeatureRawValue
        localSettings.activeFeatureStartedAt = cloudSettings.activeFeatureStartedAt
        localSettings.updatedAt = Date()
        save(localContainer.mainContext)
    }

    private func migrateRecords(from source: ModelContext, to destination: ModelContext) throws {
        let sourceSettings = ensureUserSettings(in: source)
        let destinationSettings = ensureUserSettings(in: destination)
        destinationSettings.selectedLanguageCode = sourceSettings.selectedLanguageCode
        destinationSettings.syncEnabled = sourceSettings.syncEnabled
        destinationSettings.didChooseSyncOnLaunch = sourceSettings.didChooseSyncOnLaunch
        destinationSettings.selectedScoreItemID = sourceSettings.selectedScoreItemID
        destinationSettings.activeFeatureRawValue = sourceSettings.activeFeatureRawValue
        destinationSettings.activeFeatureStartedAt = sourceSettings.activeFeatureStartedAt
        destinationSettings.updatedAt = Date()

        try replaceRecords(of: ScoreLibraryItemRecord.self, in: destination, with: try source.fetch(FetchDescriptor<ScoreLibraryItemRecord>()))
        try replaceRecords(of: ScoreAnnotationDocumentRecord.self, in: destination, with: try source.fetch(FetchDescriptor<ScoreAnnotationDocumentRecord>()))
        try replaceRecords(of: PracticeSessionRecord.self, in: destination, with: try source.fetch(FetchDescriptor<PracticeSessionRecord>()))
        try replaceRecords(of: TrainingStatisticsSnapshotRecord.self, in: destination, with: try source.fetch(FetchDescriptor<TrainingStatisticsSnapshotRecord>()))
        try replaceRecords(of: UsageAnalyticsRecord.self, in: destination, with: try source.fetch(FetchDescriptor<UsageAnalyticsRecord>()))

        let sourceSync = ensureSyncStatus(in: source)
        let destinationSync = ensureSyncStatus(in: destination)
        destinationSync.currentStateRawValue = sourceSync.currentStateRawValue
        destinationSync.lastSuccessfulSync = sourceSync.lastSuccessfulSync
        destinationSync.lastErrorSummary = sourceSync.lastErrorSummary
        destinationSync.unavailableReasonRawValue = sourceSync.unavailableReasonRawValue
        destinationSync.updatedAt = Date()
        save(destination)
    }

    private func replaceRecords<T: PersistentModel>(of type: T.Type, in context: ModelContext, with sourceRecords: [T]) throws {
        let existing = try context.fetch(FetchDescriptor<T>())
        for item in existing {
            context.delete(item)
        }

        for source in sourceRecords {
            switch source {
            case let item as ScoreLibraryItemRecord:
                context.insert(
                    ScoreLibraryItemRecord(
                        id: item.id,
                        title: item.title,
                        sourceTypeRawValue: item.sourceTypeRawValue,
                        createdAt: item.createdAt,
                        updatedAt: item.updatedAt,
                        checksum: item.checksum,
                        relativeFilePath: item.relativeFilePath
                    ) as! T
                )
            case let item as ScoreAnnotationDocumentRecord:
                context.insert(
                    ScoreAnnotationDocumentRecord(
                        id: item.id,
                        scoreItemID: item.scoreItemID,
                        encodedStrokes: item.encodedStrokes,
                        updatedAt: item.updatedAt
                    ) as! T
                )
            case let item as PracticeSessionRecord:
                context.insert(
                    PracticeSessionRecord(
                        id: item.id,
                        scoreItemID: item.scoreItemID,
                        partID: item.partID,
                        mode: item.mode,
                        startedAt: item.startedAt,
                        endedAt: item.endedAt,
                        summaryJSON: item.summaryJSON
                    ) as! T
                )
            case let item as TrainingStatisticsSnapshotRecord:
                context.insert(
                    TrainingStatisticsSnapshotRecord(
                        id: item.id,
                        scope: item.scope,
                        createdAt: item.createdAt,
                        totalPracticeSeconds: item.totalPracticeSeconds,
                        averagePitchScore: item.averagePitchScore,
                        averageRhythmScore: item.averageRhythmScore
                    ) as! T
                )
            case let item as UsageAnalyticsRecord:
                context.insert(
                    UsageAnalyticsRecord(
                        id: item.id,
                        featureRawValue: item.featureRawValue,
                        startedAt: item.startedAt,
                        endedAt: item.endedAt
                    ) as! T
                )
            default:
                break
            }
        }
    }

    private func ensureUserSettings(in context: ModelContext) -> UserProfileSettingsRecord {
        let descriptor = FetchDescriptor<UserProfileSettingsRecord>()
        if let existing = try? context.fetch(descriptor).first(where: { $0.id == RecordID.userSettings }) {
            return existing
        }

        let record = UserProfileSettingsRecord()
        context.insert(record)
        save(context)
        return record
    }

    private func ensureSyncStatus(in context: ModelContext) -> SyncStatusRecord {
        let descriptor = FetchDescriptor<SyncStatusRecord>()
        if let existing = try? context.fetch(descriptor).first(where: { $0.id == RecordID.syncStatus }) {
            return existing
        }

        let record = SyncStatusRecord()
        context.insert(record)
        save(context)
        return record
    }

    private func updateSyncStatus(
        state: SyncState,
        error: String?,
        unavailableReason: SyncUnavailableReason?,
        markSuccess: Bool
    ) {
        let context = activeContext
        let status = ensureSyncStatus(in: context)
        status.currentStateRawValue = state.rawValue
        status.lastErrorSummary = error
        status.unavailableReasonRawValue = unavailableReason?.rawValue
        status.updatedAt = Date()
        if markSuccess {
            status.lastSuccessfulSync = Date()
        }
        save(context)

        if activeStorageMode == .cloud {
            let localStatus = ensureSyncStatus(in: localContainer.mainContext)
            localStatus.currentStateRawValue = state.rawValue
            localStatus.lastErrorSummary = error
            localStatus.unavailableReasonRawValue = unavailableReason?.rawValue
            localStatus.updatedAt = Date()
            if markSuccess {
                localStatus.lastSuccessfulSync = status.lastSuccessfulSync
            }
            save(localContainer.mainContext)
        }
    }

    private func updateCloudSaveTimestampIfNeeded() {
        guard activeStorageMode == .cloud else {
            return
        }
        updateSyncStatus(state: .on, error: nil, unavailableReason: nil, markSuccess: true)
    }

    private func save(_ context: ModelContext) {
        try? context.save()
    }

    private static func storeURL(fileName: String) -> URL {
        let root = try! FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appending(path: "VocalDiveData")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root.appending(path: fileName)
    }
}
