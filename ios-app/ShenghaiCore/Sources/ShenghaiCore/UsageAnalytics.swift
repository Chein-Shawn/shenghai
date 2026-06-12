import Foundation

public enum UsageFeature: String, CaseIterable, Codable, Sendable {
    case dashboard
    case scoreComposer
    case scoreWorkspace
    case practice
    case experimentalFeatures
    case researchStatus
    case support
    case usageStats

    public var displayName: String {
        switch self {
        case .dashboard:
            return L10n.tr("Overview")
        case .scoreComposer:
            return L10n.tr("Compose")
        case .scoreWorkspace:
            return L10n.tr("Score")
        case .practice:
            return L10n.tr("Practice")
        case .experimentalFeatures:
            return L10n.tr("Experimental")
        case .researchStatus:
            return L10n.tr("Research")
        case .support:
            return L10n.tr("Support")
        case .usageStats:
            return L10n.tr("Usage")
        }
    }
}

public struct UsageSessionEvent: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var feature: UsageFeature
    public var startedAt: Date
    public var endedAt: Date

    public init(id: UUID = UUID(), feature: UsageFeature, startedAt: Date, endedAt: Date) {
        self.id = id
        self.feature = feature
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    public var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }
}

public struct DailyUsageSummary: Codable, Equatable, Sendable, Identifiable {
    public var dayKey: String
    public var totalDuration: TimeInterval
    public var featureDurations: [UsageFeature: TimeInterval]

    public var id: String { dayKey }

    public init(dayKey: String, totalDuration: TimeInterval, featureDurations: [UsageFeature: TimeInterval]) {
        self.dayKey = dayKey
        self.totalDuration = totalDuration
        self.featureDurations = featureDurations
    }
}

public struct UsageAnalyticsLedger: Codable, Equatable, Sendable {
    public private(set) var events: [UsageSessionEvent]
    public private(set) var activeFeature: UsageFeature?
    public private(set) var activeStartedAt: Date?

    public init(
        events: [UsageSessionEvent] = [],
        activeFeature: UsageFeature? = nil,
        activeStartedAt: Date? = nil
    ) {
        self.events = events
        self.activeFeature = activeFeature
        self.activeStartedAt = activeStartedAt
    }

    public mutating func switchTo(_ feature: UsageFeature, at date: Date = Date()) {
        closeActiveEvent(at: date)
        activeFeature = feature
        activeStartedAt = date
    }

    public mutating func closeActiveEvent(at date: Date = Date()) {
        guard let activeFeature, let activeStartedAt else {
            return
        }

        if date > activeStartedAt {
            events.append(
                UsageSessionEvent(
                    feature: activeFeature,
                    startedAt: activeStartedAt,
                    endedAt: date
                )
            )
        }

        self.activeFeature = nil
        self.activeStartedAt = nil
    }

    public func dailySummaries(calendar: Calendar = .current) -> [DailyUsageSummary] {
        let formatter = Self.dayFormatter(calendar: calendar)
        var grouped: [String: [UsageSessionEvent]] = [:]

        for event in events {
            let day = formatter.string(from: event.startedAt)
            grouped[day, default: []].append(event)
        }

        return grouped.keys.sorted().map { dayKey in
            let dayEvents = grouped[dayKey] ?? []
            var featureDurations: [UsageFeature: TimeInterval] = [:]

            for event in dayEvents {
                featureDurations[event.feature, default: 0] += event.duration
            }

            return DailyUsageSummary(
                dayKey: dayKey,
                totalDuration: dayEvents.reduce(0) { $0 + $1.duration },
                featureDurations: featureDurations
            )
        }
    }

    public func featureDurationsIncludingActive(now: Date = Date()) -> [UsageFeature: TimeInterval] {
        var durations: [UsageFeature: TimeInterval] = [:]
        for event in events {
            durations[event.feature, default: 0] += event.duration
        }

        if let activeFeature, let activeStartedAt, now > activeStartedAt {
            durations[activeFeature, default: 0] += now.timeIntervalSince(activeStartedAt)
        }

        return durations
    }

    private static func dayFormatter(calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
