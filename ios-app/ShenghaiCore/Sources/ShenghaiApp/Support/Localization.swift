import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case traditionalChinese = "zh-Hant"
    case simplifiedChinese = "zh-Hans"
    case cantonese = "yue"
    case spanish = "es"
    case arabic = "ar"
    case russian = "ru"
    case portuguese = "pt"
    case indonesian = "id"
    case japanese = "ja"
    case korean = "ko"
    case thai = "th"
    case italian = "it"
    case german = "de"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    var resourceIdentifiers: [String] {
        switch self {
        case .english:
            return ["en"]
        case .traditionalChinese:
            return ["zh-Hant", "zh-TW"]
        case .simplifiedChinese:
            return ["zh-Hans", "zh-CN"]
        case .cantonese:
            return ["yue", "zh-HK"]
        case .spanish:
            return ["es"]
        case .arabic:
            return ["ar"]
        case .russian:
            return ["ru"]
        case .portuguese:
            return ["pt", "pt-PT", "pt-BR"]
        case .indonesian:
            return ["id"]
        case .japanese:
            return ["ja"]
        case .korean:
            return ["ko"]
        case .thai:
            return ["th"]
        case .italian:
            return ["it"]
        case .german:
            return ["de"]
        }
    }

    var isRightToLeft: Bool {
        self == .arabic
    }

    var nativeDisplayName: String {
        switch self {
        case .english: return "English"
        case .traditionalChinese: return "繁體中文"
        case .simplifiedChinese: return "简体中文"
        case .cantonese: return "粵語"
        case .spanish: return "Español"
        case .arabic: return "العربية"
        case .russian: return "Русский"
        case .portuguese: return "Português"
        case .indonesian: return "Bahasa Indonesia"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .thai: return "ไทย"
        case .italian: return "Italiano"
        case .german: return "Deutsch"
        }
    }
}

final class AppSettingsStore: ObservableObject, @unchecked Sendable {
    static let shared = AppSettingsStore()

    @Published var selectedLanguage: AppLanguage {
        didSet {
            Task { @MainActor in
                PersistenceCoordinator.shared.updateSelectedLanguage(selectedLanguage)
            }
        }
    }

    private let defaults: UserDefaults
    private static let languageKey = "shenghai.displayLanguage"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let rawValue = defaults.string(forKey: Self.languageKey),
           let storedLanguage = AppLanguage(rawValue: rawValue) {
            selectedLanguage = storedLanguage
        } else {
            selectedLanguage = .english
        }
    }

    func reloadFromPersistence() {
        Task { @MainActor in
            let language = PersistenceCoordinator.shared.settingsSnapshot().selectedLanguage
            guard language != self.selectedLanguage else {
                return
            }
            self.selectedLanguage = language
        }
    }
}

private final class LocalizationBundleToken {}

enum L10n {
    static func tr(_ key: String) -> String {
        let resolvedKey = aliases[key] ?? key
        let bundle = AppSettingsStore.shared.selectedLanguage.localizationBundle
        let localized = bundle.localizedString(forKey: resolvedKey, value: nil, table: "Localizable")
        if localized != resolvedKey {
            return localized
        }

        let fallback = baseBundle.localizedString(forKey: resolvedKey, value: nil, table: "Localizable")
        if fallback != resolvedKey {
            return fallback
        }

        return key
    }

    static func tr(_ key: String, _ arguments: CVarArg...) -> String {
        let format = tr(key)
        return String(
            format: format,
            locale: Locale(identifier: AppSettingsStore.shared.selectedLanguage.localeIdentifier),
            arguments: arguments
        )
    }

    private static let aliases: [String: String] = {
        guard
            let url = baseBundle.url(forResource: "LocalizationAliases", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else {
            return [:]
        }
        return object
    }()

    fileprivate static var baseBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: LocalizationBundleToken.self)
        #endif
    }
}

private extension AppLanguage {
    var localizationBundle: Bundle {
        let base = L10n.baseBundle
        for identifier in resourceIdentifiers {
            if let path = base.path(forResource: identifier, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return base
    }
}
