import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case scoreWorkspace
    case practice
    case researchStatus
    case support
    case usageStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Overview"
        case .scoreWorkspace:
            return "Score"
        case .practice:
            return "Practice"
        case .researchStatus:
            return "Research"
        case .support:
            return "Support"
        case .usageStats:
            return "Usage"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .scoreWorkspace:
            return "music.note.list"
        case .practice:
            return "waveform.and.mic"
        case .researchStatus:
            return "book.pages"
        case .support:
            return "questionmark.bubble"
        case .usageStats:
            return "chart.bar.xaxis"
        }
    }

    var usageFeature: UsageFeature {
        switch self {
        case .dashboard:
            return .dashboard
        case .scoreWorkspace:
            return .scoreWorkspace
        case .practice:
            return .practice
        case .researchStatus:
            return .researchStatus
        case .support:
            return .support
        case .usageStats:
            return .usageStats
        }
    }
}
