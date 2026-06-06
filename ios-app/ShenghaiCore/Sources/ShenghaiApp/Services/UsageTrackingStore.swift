import Foundation
import Observation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

@MainActor
@Observable
final class UsageTrackingStore {
    private let defaults: UserDefaults
    private let storageKey = "shenghai.usageLedger.v1"
    private var ledger: UsageAnalyticsLedger

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(UsageAnalyticsLedger.self, from: data) {
            ledger = decoded
        } else {
            ledger = UsageAnalyticsLedger()
        }
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
        guard let data = try? JSONEncoder().encode(ledger) else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}
