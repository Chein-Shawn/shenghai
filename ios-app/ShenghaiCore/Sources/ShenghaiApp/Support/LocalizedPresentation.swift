import Foundation
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

extension L10n {
    static func tr(_ token: LocalizedTextToken) -> String {
        if token.arguments.isEmpty {
            return tr(token.key)
        }
        return tr(token.key, token.arguments)
    }

    static func tr(_ key: String, _ arguments: [String]) -> String {
        let format = tr(key)
        var rendered = format
        for argument in arguments {
            if let range = rendered.range(of: "%@") {
                rendered.replaceSubrange(range, with: argument)
            }
        }
        return rendered
    }
}

extension ComposedScore {
    static func localizedDraftTemplate() -> ComposedScore {
        ComposedScore(
            title: L10n.tr("text.untitled_shenghai_score"),
            partName: L10n.tr("text.voice")
        )
    }

    func applyingLocalizedFallbacks() -> ComposedScore {
        var normalized = self
        normalized.title = title.localizedTrimmedOrFallback(L10n.tr("text.untitled_shenghai_score"))
        normalized.partName = partName.localizedTrimmedOrFallback(L10n.tr("text.voice"))
        return normalized
    }
}

extension ComposedNoteValue {
    var localizedDisplayName: String {
        switch self {
        case .whole:
            return L10n.tr("text.whole")
        case .half:
            return L10n.tr("text.half")
        case .quarter:
            return L10n.tr("text.quarter")
        case .eighth:
            return L10n.tr("text.eighth")
        }
    }
}

extension UsageFeature {
    var localizedDisplayName: String {
        switch self {
        case .dashboard:
            return L10n.tr("nav.overview")
        case .scoreComposer:
            return L10n.tr("nav.compose")
        case .scoreWorkspace:
            return L10n.tr("nav.score")
        case .practice:
            return L10n.tr("nav.practice")
        case .experimentalFeatures:
            return L10n.tr("nav.experimental")
        case .settings:
            return L10n.tr("nav.settings")
        }
    }
}

extension OMRInputKind {
    var localizedDisplayName: String {
        switch self {
        case .image:
            return L10n.tr("omr.input.image")
        case .pdf:
            return L10n.tr("omr.input.pdf")
        case .musicXML:
            return L10n.tr("omr.input.musicxml")
        }
    }
}

extension OMRProvider {
    var localizedSummary: String {
        L10n.tr(summaryText)
    }

    var localizedBestFor: String {
        L10n.tr(bestForText)
    }

    var localizedLicenseNote: String {
        L10n.tr(licenseNoteText)
    }
}

extension OMRRecognizedElementKind {
    var localizedDisplayName: String {
        L10n.tr(displayKey)
    }
}

private extension String {
    func localizedTrimmedOrFallback(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
