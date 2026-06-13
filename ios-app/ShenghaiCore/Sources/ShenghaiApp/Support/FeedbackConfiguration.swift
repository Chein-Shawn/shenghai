import Foundation

struct FeedbackConfiguration: Decodable {
    let appsScriptEndpoint: String
    let officialWebsite: String
    let supportEmail: String
    let supportPhone: String

    static let `default` = FeedbackConfiguration(
        appsScriptEndpoint: "",
        officialWebsite: "https://chein-shawn.github.io/shenghai/",
        supportEmail: "shanewn931131@gmail.com",
        supportPhone: "+886 0901230875"
    )

    static var current: FeedbackConfiguration {
        guard
            let url = baseBundle.url(forResource: "FeedbackConfiguration", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(FeedbackConfiguration.self, from: data)
        else {
            return .default
        }
        return decoded
    }

    var feedbackEndpointURL: URL? {
        let trimmed = appsScriptEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("REPLACE_WITH"), let url = URL(string: trimmed) else {
            return nil
        }
        return url
    }

    var officialWebsiteURL: URL? {
        URL(string: officialWebsite)
    }
}

private final class FeedbackConfigurationBundleToken {}

private extension FeedbackConfiguration {
    static var baseBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: FeedbackConfigurationBundleToken.self)
        #endif
    }
}
