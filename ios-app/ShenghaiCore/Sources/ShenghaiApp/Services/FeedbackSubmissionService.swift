import Foundation
#if os(iOS)
import UIKit
#endif

struct FeedbackSubmissionPayload: Codable {
    let source: String
    let appName: String
    let appStage: String
    let submittedAt: String
    let category: String
    let summary: String
    let details: String
    let replyEmail: String?
    let currentScreenKey: String
    let currentScreenTitle: String
    let appVersion: String
    let buildNumber: String
    let platform: String
    let osVersion: String
    let displayLanguage: String
    let website: String
}

struct FeedbackSubmissionResponse: Codable {
    let ok: Bool?
    let message: String?
    let rowNumber: Int?
}

enum FeedbackSubmissionError: LocalizedError {
    case backendNotConfigured
    case cooldown(secondsRemaining: Int)
    case invalidResponse
    case serverMessage(String)
    case networkFailure

    var errorDescription: String? {
        switch self {
        case .backendNotConfigured:
            return L10n.tr("support.feedback.backend_not_configured")
        case let .cooldown(secondsRemaining):
            return L10n.tr("support.feedback.cooldown", secondsRemaining)
        case .invalidResponse:
            return L10n.tr("support.feedback.invalid_response")
        case let .serverMessage(message):
            return message
        case .networkFailure:
            return L10n.tr("support.feedback.network")
        }
    }
}

actor FeedbackSubmissionService {
    private let session: URLSession
    private let defaults: UserDefaults
    private let clock: () -> Date

    private let lastSubmissionKey = "shenghai.feedback.lastSubmissionAt"
    private let iso8601Formatter = ISO8601DateFormatter()

    init(
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        clock: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.defaults = defaults
        self.clock = clock
    }

    func submit(
        category: FeedbackCategory,
        summary: String,
        details: String,
        replyEmail: String,
        currentSection: AppSection,
        selectedLanguage: AppLanguage
    ) async throws {
        guard let endpoint = FeedbackConfiguration.current.feedbackEndpointURL else {
            throw FeedbackSubmissionError.backendNotConfigured
        }

        let now = clock()
        if let lastSubmission = defaults.object(forKey: lastSubmissionKey) as? TimeInterval {
            let elapsed = now.timeIntervalSince1970 - lastSubmission
            if elapsed < 20 {
                throw FeedbackSubmissionError.cooldown(secondsRemaining: max(1, Int(ceil(20 - elapsed))))
            }
        }

        let payload = FeedbackSubmissionPayload(
            source: "shenghai-apple-app",
            appName: "Shenghai",
            appStage: "alpha",
            submittedAt: iso8601Formatter.string(from: now),
            category: category.rawValue,
            summary: summary.normalizedFeedbackField(maxLength: 160),
            details: details.normalizedFeedbackField(maxLength: 4000),
            replyEmail: replyEmail.normalizedOptionalEmail(),
            currentScreenKey: currentSection.rawValue,
            currentScreenTitle: currentSection.title,
            appVersion: AppBuildInfo.version,
            buildNumber: AppBuildInfo.build,
            platform: AppBuildInfo.platform,
            osVersion: AppBuildInfo.osVersion,
            displayLanguage: selectedLanguage.rawValue,
            website: ""
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(payload)

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedbackSubmissionError.networkFailure
        }

        guard let httpResponse = response as? HTTPURLResponse, 200 ..< 300 ~= httpResponse.statusCode else {
            throw FeedbackSubmissionError.networkFailure
        }

        guard let decoded = try? JSONDecoder().decode(FeedbackSubmissionResponse.self, from: data) else {
            throw FeedbackSubmissionError.invalidResponse
        }

        if decoded.ok == false {
            throw FeedbackSubmissionError.serverMessage(decoded.message ?? L10n.tr("support.feedback.server"))
        }

        defaults.set(now.timeIntervalSince1970, forKey: lastSubmissionKey)
    }
}

private enum AppBuildInfo {
    static var version: String {
        infoValue("CFBundleShortVersionString") ?? "dev"
    }

    static var build: String {
        infoValue("CFBundleVersion") ?? "dev"
    }

    static var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    static var platform: String {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
        #elseif os(macOS)
        return "macOS"
        #else
        return "Apple"
        #endif
    }

    private static func infoValue(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}

private extension String {
    func normalizedFeedbackField(maxLength: Int) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength {
            return trimmed
        }
        return String(trimmed.prefix(maxLength))
    }

    func normalizedOptionalEmail() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
