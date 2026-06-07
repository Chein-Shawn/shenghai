import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case scoreComposer
    case scoreWorkspace
    case practice
    case experimentalFeatures
    case researchStatus
    case support
    case usageStats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Overview"
        case .scoreComposer:
            return "Compose"
        case .scoreWorkspace:
            return "Score"
        case .practice:
            return "Practice"
        case .experimentalFeatures:
            return "Experimental"
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
        case .scoreComposer:
            return "square.and.pencil"
        case .scoreWorkspace:
            return "music.note.list"
        case .practice:
            return "waveform.and.mic"
        case .experimentalFeatures:
            return "testtube.2"
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
        case .scoreComposer:
            return .scoreComposer
        case .scoreWorkspace:
            return .scoreWorkspace
        case .practice:
            return .practice
        case .experimentalFeatures:
            return .experimentalFeatures
        case .researchStatus:
            return .researchStatus
        case .support:
            return .support
        case .usageStats:
            return .usageStats
        }
    }
}
