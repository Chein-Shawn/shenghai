import Foundation
import Combine
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

@MainActor
final class UsageTrackingStore: ObservableObject {
    private let persistence: PersistenceCoordinator
    @Published private var ledger: UsageAnalyticsLedger

    init(persistence: PersistenceCoordinator = .shared) {
        self.persistence = persistence
        ledger = persistence.loadUsageLedger()
    }

    var dailySummaries: [DailyUsageSummary] {
        ledger.dailySummaries()
    }

    var featureDurations: [UsageFeature: TimeInterval] {
        ledger.featureDurationsIncludingActive()
    }

    var totalDuration: TimeInterval {
        featureDurations.values.reduce(0, +)
    }

    var activeFeature: UsageFeature? {
        ledger.activeFeature
    }

    func switchTo(_ feature: UsageFeature) {
        ledger.switchTo(feature)
        save()
    }

    func closeActiveSession() {
        ledger.closeActiveEvent()
        save()
    }

    private func save() {
        persistence.persistUsageLedger(ledger)
    }

    func reloadFromPersistence() {
        ledger = persistence.loadUsageLedger()
    }
}
