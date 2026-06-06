import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case scoreWorkspace
    case practice
    case researchStatus

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
        }
    }
}
