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
    case settings

    var id: String { rawValue }

    var title: String {
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
        case .settings:
            return L10n.tr("Settings")
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
        case .settings:
            return "gearshape"
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
        case .settings:
            return .settings
        }
    }
}

enum ScoreHubMode: String, CaseIterable, Identifiable {
    case editor
    case scan
    case compose

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editor:
            return L10n.tr("score.mode.musicxml_editor")
        case .scan:
            return L10n.tr("score.mode.scan_to_musicxml")
        case .compose:
            return L10n.tr("Compose")
        }
    }
}
