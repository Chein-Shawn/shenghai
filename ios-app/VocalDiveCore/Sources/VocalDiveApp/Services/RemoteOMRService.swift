import Foundation
import Security
import CryptoKit
import OSLog
#if os(iOS)
import UIKit
#endif
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

enum RemoteOMRJobState: String, Codable, Equatable {
    case uploading
    case queued
    case rasterizing
    case recognizing
    case assembling
    case ready
    case failed
    case cancelled
}

struct RemoteOMRJobStatus: Codable, Equatable {
    var jobID: String
    var state: RemoteOMRJobState
    var sourceName: String
    var totalPages: Int
    var completedPages: Int
    var detail: String?
    var error: String?
    var errorCode: String?
    var queuePosition: Int?
    var currentPage: Int?
    var engineStage: String?
    var elapsedSeconds: Int?
    var heartbeatAt: String?
    var attentionNeeded: Bool?
    var resourceSnapshot: RemoteOMRResourceSnapshot?

    private enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case state
        case sourceName = "source_name"
        case totalPages = "total_pages"
        case completedPages = "completed_pages"
        case detail
        case error
        case errorCode = "error_code"
        case queuePosition = "queue_position"
        case currentPage = "current_page"
        case engineStage = "engine_stage"
        case elapsedSeconds = "elapsed_seconds"
        case heartbeatAt = "heartbeat_at"
        case attentionNeeded = "attention_needed"
        case resourceSnapshot = "resource_snapshot"
    }
}

struct RemoteOMRResourceSnapshot: Codable, Equatable {
    var gpu: RemoteOMRGPUResourceSnapshot?
    var oemer: RemoteOMRProcessResourceSnapshot?
}

struct RemoteOMRGPUResourceSnapshot: Codable, Equatable {
    var utilizationPercent: Int?
    var memoryUsedMiB: Int?
    var memoryTotalMiB: Int?

    private enum CodingKeys: String, CodingKey {
        case utilizationPercent = "utilization_percent"
        case memoryUsedMiB = "memory_used_mib"
        case memoryTotalMiB = "memory_total_mib"
    }
}

struct RemoteOMRProcessResourceSnapshot: Codable, Equatable {
    var alive: Bool?
    var cpuPercent: Double?
    var memoryRSSMiB: Double?

    private enum CodingKeys: String, CodingKey {
        case alive
        case cpuPercent = "cpu_percent"
        case memoryRSSMiB = "memory_rss_mib"
    }
}

@MainActor
final class RemoteOMRDiagnosticsStore: ObservableObject {
    static let shared = RemoteOMRDiagnosticsStore()

    @Published private(set) var latestStatus: RemoteOMRJobStatus?

    func record(_ status: RemoteOMRJobStatus) {
        latestStatus = status
    }

    func clear() {
        latestStatus = nil
    }
}

private struct RemoteOMRCreateJobResponse: Decodable {
    var jobID: String
    var state: RemoteOMRJobState
    var totalPages: Int

    private enum CodingKeys: String, CodingKey {
        case jobID = "job_id"
        case state
        case totalPages = "total_pages"
    }
}

private struct RemoteOMRAuthLinkRequest: Encodable {
    var email: String
    var deviceLabel: String
    var installationID: String
    var consentVersion: String

    private enum CodingKeys: String, CodingKey {
        case email
        case deviceLabel = "device_label"
        case installationID = "installation_id"
        case consentVersion = "consent_version"
    }
}

private struct RemoteOMRAuthLinkResponse: Decodable {
    var loginID: String
    var pollSecret: String
    var expiresAt: String

    private enum CodingKeys: String, CodingKey {
        case loginID = "login_id"
        case pollSecret = "poll_secret"
        case expiresAt = "expires_at"
    }
}

private struct RemoteOMRAuthPollRequest: Encodable {
    var loginID: String
    var pollSecret: String

    private enum CodingKeys: String, CodingKey {
        case loginID = "login_id"
        case pollSecret = "poll_secret"
    }
}

private struct RemoteOMRAuthPollResponse: Decodable {
    enum State: String, Decodable {
        case pending
        case connected
        case expired
    }

    var state: State
    var deviceToken: String?

    private enum CodingKeys: String, CodingKey {
        case state
        case deviceToken = "device_token"
    }
}

struct RemoteOMREmailLoginSession: Equatable {
    var loginID: String
    var pollSecret: String
    var email: String
    var expiresAt: Date
}

private struct PendingRemoteOMREmailLoginMetadata: Codable, Equatable {
    var loginID: String
    var email: String
    var expiresAt: Date
}

struct RemoteOMRCompletedSession {
    var sourceName: String
    var inputKind: OMRInputKind
    var renderedPages: [NativeOMRRenderedPage]
    var generatedMusicXML: String
    var serverJobID: String
}

struct RemoteOMRCorrectionContext: Codable, Equatable {
    var serverJobID: String
    var sourceName: String
    var candidateMusicXML: String
    var localScoreItemID: String?
    var trainingRecordID: String?
}

struct RemoteOMRAccountProfile: Codable, Equatable {
    var email: String?
    var birthDate: String?
    var goals: [String]

    private enum CodingKeys: String, CodingKey {
        case email
        case birthDate = "birth_date"
        case goals
    }
}

private struct RemoteOMRAccountProfileRequest: Encodable {
    var birthDate: String?
    var goals: [String]

    private enum CodingKeys: String, CodingKey {
        case birthDate = "birth_date"
        case goals
    }
}

private struct RemoteOMRCorrectionSubmissionRequest: Encodable {
    var correctedMusicXML: String
    var correctionMetadata: [String: String]

    private enum CodingKeys: String, CodingKey {
        case correctedMusicXML = "corrected_musicxml"
        case correctionMetadata = "correction_metadata"
    }
}

private struct RemoteOMRCorrectionSubmissionResponse: Decodable {
    var trainingRecordID: String

    private enum CodingKeys: String, CodingKey {
        case trainingRecordID = "training_record_id"
    }
}

enum RemoteOMRServiceError: LocalizedError {
    case notConfigured
    case invalidServerURL
    case tooManyImages
    case tooManyPDFPages
    case fileTooLarge
    case mixedInputTypes
    case invalidResponse
    case invalidEmailLinkResponse
    case invalidEmailPollResponse
    case server(String)
    case missingResult
    case emailConnectionExpired
    case emailLinkRateLimited(Int)
    case sourceNoLongerRetained
    case engineUnavailable
    case processingUnavailable

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "VocalDive OMR is not connected."
        case .invalidServerURL:
            return "The VocalDive OMR server address is invalid."
        case .tooManyImages:
            return "A beta scan can contain up to 30 images."
        case .tooManyPDFPages:
            return "A beta PDF can contain up to 30 pages."
        case .fileTooLarge:
            return "A beta scan can be up to 50 MB."
        case .mixedInputTypes:
            return "Upload one PDF or a batch of images, not both together."
        case .invalidResponse:
            return "VocalDive OMR returned an invalid response."
        case .invalidEmailLinkResponse:
            return "VocalDive could not start email verification."
        case .invalidEmailPollResponse:
            return "VocalDive could not finish connecting this device."
        case .server(let message):
            return message
        case .missingResult:
            return "VocalDive OMR no longer has this result. Scan the source again."
        case .emailConnectionExpired:
            return "This email connection link expired. Request a new link and try again."
        case .emailLinkRateLimited:
            return "Too many verification-link requests."
        case .sourceNoLongerRetained:
            return "The original score is no longer retained on VocalDive OMR. Upload it again before completing correction."
        case .engineUnavailable:
            return "Recognition is temporarily unavailable. Please try again shortly."
        case .processingUnavailable:
            return "Recognition is temporarily unavailable. Please try again shortly."
        }
    }
}

@MainActor
final class RemoteOMRConfigurationStore: ObservableObject {
    static let shared = RemoteOMRConfigurationStore()
    static let defaultEndpointString = "https://omr.vocaldive.com"

    @Published private(set) var endpointString: String
    @Published private(set) var isConfigured: Bool
    @Published private(set) var connectedEmail: String?

    private let defaults: UserDefaults
    private static let endpointKey = "vocaldive.privateOMR.endpoint"
    private static let connectedEmailKey = "vocaldive.privateOMR.connected-email"
    private static let keychainService = "com.vocaldive.private-omr"
    private static let keychainAccount = "device-token"
    private static let installationKeychainAccount = "installation-id"
    private static let pendingPollSecretKeychainAccount = "pending-email-poll-secret"
    private static let pendingEmailLoginKey = "vocaldive.privateOMR.pending-email-login"
    private static let authLogger = Logger(subsystem: "com.vocaldive.app", category: "RemoteOMRAuth")
    static let consentVersion = "714-beta-data-v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let savedEndpoint = defaults.string(forKey: Self.endpointKey) ?? Self.defaultEndpointString
        endpointString = savedEndpoint
        let savedEmail = defaults.string(forKey: Self.connectedEmailKey)
        connectedEmail = savedEmail
        isConfigured = (try? Self.readToken())?.isEmpty == false && URL(string: savedEndpoint) != nil && savedEmail != nil
    }

    func currentConfiguration() throws -> (endpoint: URL, token: String) {
        guard let endpoint = URL(string: endpointString), endpoint.scheme == "https" else {
            throw RemoteOMRServiceError.notConfigured
        }
        let token = try Self.readToken()
        guard !token.isEmpty else {
            throw RemoteOMRServiceError.notConfigured
        }
        return (endpoint, token)
    }

    func updateEndpoint(_ endpointString: String) throws {
        let normalized = endpointString.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let endpoint = URL(string: normalized), endpoint.scheme == "https", endpoint.host != nil else {
            throw RemoteOMRServiceError.invalidServerURL
        }
        let changed = endpoint.absoluteString != self.endpointString
        defaults.set(endpoint.absoluteString, forKey: Self.endpointKey)
        self.endpointString = endpoint.absoluteString
        if changed {
            disconnect()
        }
    }

    func disconnect() {
        Self.deleteToken()
        clearPendingEmailLogin()
        defaults.removeObject(forKey: Self.connectedEmailKey)
        connectedEmail = nil
        isConfigured = false
    }

    func requestEmailLink(email: String) async throws -> RemoteOMREmailLoginSession {
        guard let endpoint = URL(string: endpointString), endpoint.scheme == "https" else {
            throw RemoteOMRServiceError.invalidServerURL
        }
        var request = URLRequest(url: endpoint.appending(path: "v1/auth/request-link"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        request.httpBody = try JSONEncoder().encode(
            RemoteOMRAuthLinkRequest(
                email: normalizedEmail,
                deviceLabel: Self.defaultDeviceLabel,
                installationID: try Self.installationID(),
                consentVersion: Self.consentVersion
            )
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data, operation: "auth_request")
        let result: RemoteOMRAuthLinkResponse
        do {
            result = try JSONDecoder().decode(RemoteOMRAuthLinkResponse.self, from: data)
        } catch {
            Self.logAuthEvent("invalid_link_response")
            throw RemoteOMRServiceError.invalidEmailLinkResponse
        }
        guard let expiresAt = RFC3339TimestampParser.date(from: result.expiresAt) else {
            Self.logAuthEvent("invalid_link_expiry")
            throw RemoteOMRServiceError.invalidEmailLinkResponse
        }
        let session = RemoteOMREmailLoginSession(
            loginID: result.loginID,
            pollSecret: result.pollSecret,
            email: normalizedEmail,
            expiresAt: expiresAt
        )
        try persistPendingEmailLogin(session)
        Self.logAuthEvent("link_requested")
        return session
    }

    func pendingEmailLoginSession() -> RemoteOMREmailLoginSession? {
        guard let data = defaults.data(forKey: Self.pendingEmailLoginKey),
              let metadata = try? JSONDecoder().decode(PendingRemoteOMREmailLoginMetadata.self, from: data),
              metadata.expiresAt > Date(),
              let pollSecret = try? Self.readKeychainValue(account: Self.pendingPollSecretKeychainAccount),
              pollSecret.isEmpty == false else {
            clearPendingEmailLogin()
            return nil
        }
        return RemoteOMREmailLoginSession(
            loginID: metadata.loginID,
            pollSecret: pollSecret,
            email: metadata.email,
            expiresAt: metadata.expiresAt
        )
    }

    func waitForEmailConnection(_ session: RemoteOMREmailLoginSession) async throws {
        guard let endpoint = URL(string: endpointString), endpoint.scheme == "https" else {
            throw RemoteOMRServiceError.invalidServerURL
        }
        while Date() < session.expiresAt {
            var request = URLRequest(url: endpoint.appending(path: "v1/auth/poll"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(
                RemoteOMRAuthPollRequest(loginID: session.loginID, pollSecret: session.pollSecret)
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            try Self.validate(response: response, data: data, operation: "auth_poll")
            let result: RemoteOMRAuthPollResponse
            do {
                result = try JSONDecoder().decode(RemoteOMRAuthPollResponse.self, from: data)
            } catch {
                Self.logAuthEvent("invalid_poll_response")
                throw RemoteOMRServiceError.invalidEmailPollResponse
            }
            switch result.state {
            case .pending:
                try await Task.sleep(for: .seconds(2))
            case .expired:
                clearPendingEmailLogin()
                throw RemoteOMRServiceError.emailConnectionExpired
            case .connected:
                guard let token = result.deviceToken, token.isEmpty == false else {
                    Self.logAuthEvent("missing_device_credential")
                    throw RemoteOMRServiceError.invalidEmailPollResponse
                }
                try Self.storeToken(token)
                defaults.set(session.email, forKey: Self.connectedEmailKey)
                clearPendingEmailLogin()
                connectedEmail = session.email
                isConfigured = true
                Self.logAuthEvent("device_connected")
                return
            }
        }
        clearPendingEmailLogin()
        throw RemoteOMRServiceError.emailConnectionExpired
    }

    func fetchProfile() async throws -> RemoteOMRAccountProfile {
        let configuration = try currentConfiguration()
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/account"))
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(RemoteOMRAccountProfile.self, from: data)
    }

    func updateProfile(birthDate: String?, goals: [String]) async throws -> RemoteOMRAccountProfile {
        let configuration = try currentConfiguration()
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/account"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RemoteOMRAccountProfileRequest(birthDate: birthDate, goals: goals)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: data)
        return try JSONDecoder().decode(RemoteOMRAccountProfile.self, from: data)
    }

    func deleteRemoteAccount() async throws {
        let configuration = try currentConfiguration()
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        try Self.validate(response: response, data: Data())
        disconnect()
    }

    private static func readToken() throws -> String {
        try readKeychainValue(account: keychainAccount)
    }

    private static func readKeychainValue(account: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return ""
        }
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            throw RemoteOMRServiceError.notConfigured
        }
        return token
    }

    private static func storeToken(_ token: String) throws {
        try storeKeychainValue(token, account: keychainAccount)
    }

    private static func storeKeychainValue(_ value: String, account: String) throws {
        deleteKeychainValue(account: account)
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account,
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
            throw RemoteOMRServiceError.notConfigured
        }
    }

    private static func deleteToken() {
        deleteKeychainValue(account: keychainAccount)
    }

    private static func deleteKeychainValue(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: keychainService,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func installationID() throws -> String {
        let existing = try readKeychainValue(account: installationKeychainAccount)
        if existing.isEmpty == false {
            return existing
        }
        let created = UUID().uuidString.lowercased()
        try storeKeychainValue(created, account: installationKeychainAccount)
        return created
    }

    private static var defaultDeviceLabel: String {
        #if os(macOS)
        return "VocalDive Mac"
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? "VocalDive iPad" : "VocalDive iPhone"
        #else
        return "VocalDive device"
        #endif
    }

    private func persistPendingEmailLogin(_ session: RemoteOMREmailLoginSession) throws {
        try Self.storeKeychainValue(session.pollSecret, account: Self.pendingPollSecretKeychainAccount)
        let metadata = PendingRemoteOMREmailLoginMetadata(
            loginID: session.loginID,
            email: session.email,
            expiresAt: session.expiresAt
        )
        do {
            defaults.set(try JSONEncoder().encode(metadata), forKey: Self.pendingEmailLoginKey)
        } catch {
            Self.deleteKeychainValue(account: Self.pendingPollSecretKeychainAccount)
            throw error
        }
    }

    private func clearPendingEmailLogin() {
        Self.deleteKeychainValue(account: Self.pendingPollSecretKeychainAccount)
        defaults.removeObject(forKey: Self.pendingEmailLoginKey)
    }

    private static func logAuthEvent(_ event: String, status: Int? = nil) {
        authLogger.debug("event=\(event, privacy: .public) status=\(status ?? 0, privacy: .public)")
    }

    private static func validate(response: URLResponse, data: Data, operation: String = "request") throws {
        guard let http = response as? HTTPURLResponse else {
            logAuthEvent("non_http_\(operation)")
            throw RemoteOMRServiceError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            logAuthEvent("http_\(operation)", status: http.statusCode)
            let detail = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            if http.statusCode == 429,
               let rateLimit = detail?["detail"] as? [String: Any],
               rateLimit["code"] as? String == "email_link_rate_limited" {
                let retryAfter = (rateLimit["retry_after_seconds"] as? Int)
                    ?? Int(http.value(forHTTPHeaderField: "Retry-After") ?? "")
                    ?? 0
                throw RemoteOMRServiceError.emailLinkRateLimited(max(retryAfter, 1))
            }
            throw RemoteOMRServiceError.server(detail?["detail"] as? String ?? "VocalDive OMR could not complete that request.")
        }
    }
}

private struct PendingRemoteOMRJob: Codable, Equatable {
    var clientJobID: String
    var serverJobID: String?
    var sourceName: String
    var inputKindRawValue: String
    var stagedPaths: [String]
    var createdAt: Date

    var inputKind: OMRInputKind? {
        OMRInputKind(rawValue: inputKindRawValue)
    }
}

/// Keeps a small, private recovery queue. The original security-scoped upload URL
/// can disappear after the picker closes, so only copied files are retried.
@MainActor
private final class PendingRemoteOMRJobStore {
    private let fileManager: FileManager
    private let root: URL
    private let indexURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        root = applicationSupport.appending(path: "VocalDive/remote-omr-queue", directoryHint: .isDirectory)
        indexURL = root.appending(path: "jobs.json")
    }

    func stage(sourceURLs: [URL], sourceName: String, inputKind: OMRInputKind) throws -> PendingRemoteOMRJob {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let clientJobID = UUID().uuidString
        let jobDirectory = root.appending(path: clientJobID, directoryHint: .isDirectory)
        try fileManager.createDirectory(at: jobDirectory, withIntermediateDirectories: true)

        var stagedPaths: [String] = []
        do {
            for (index, sourceURL) in sourceURLs.enumerated() {
                let name = "\(String(format: "%02d", index + 1))-\(sourceURL.lastPathComponent)"
                let destination = jobDirectory.appending(path: name)
                try fileManager.copyItem(at: sourceURL, to: destination)
                stagedPaths.append(destination.path)
            }
            let job = PendingRemoteOMRJob(
                clientJobID: clientJobID,
                serverJobID: nil,
                sourceName: sourceName,
                inputKindRawValue: inputKind.rawValue,
                stagedPaths: stagedPaths,
                createdAt: Date()
            )
            var jobs = load()
            jobs.append(job)
            try save(jobs)
            return job
        } catch {
            try? fileManager.removeItem(at: jobDirectory)
            throw error
        }
    }

    func update(_ job: PendingRemoteOMRJob) throws {
        var jobs = load()
        guard let index = jobs.firstIndex(where: { $0.clientJobID == job.clientJobID }) else { return }
        jobs[index] = job
        try save(jobs)
    }

    func pending() -> [PendingRemoteOMRJob] {
        load().filter { $0.inputKind != nil && $0.stagedPaths.allSatisfy { fileManager.fileExists(atPath: $0) } }
    }

    func remove(_ job: PendingRemoteOMRJob) {
        var jobs = load()
        jobs.removeAll { $0.clientJobID == job.clientJobID }
        try? save(jobs)
        if let path = job.stagedPaths.first {
            try? fileManager.removeItem(at: URL(fileURLWithPath: path).deletingLastPathComponent())
        }
    }

    private func load() -> [PendingRemoteOMRJob] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([PendingRemoteOMRJob].self, from: data)) ?? []
    }

    private func save(_ jobs: [PendingRemoteOMRJob]) throws {
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(jobs)
        try data.write(to: indexURL, options: .atomic)
    }
}

/// On iOS this uses a background URLSession so an upload can continue while
/// VocalDive is suspended. The persisted job remains the recovery source when
/// the system terminates the app before the response is delivered.
private final class RemoteOMRUploadCoordinator: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = RemoteOMRUploadCoordinator()
    static let sessionIdentifier = "com.vocaldive.private-omr-upload"

    private let lock = NSLock()
    private var responseData: [Int: Data] = [:]
    private var completions: [Int: (Result<(Data, URLResponse), Error>) -> Void] = [:]
    private var backgroundCompletionHandler: (() -> Void)?

    private lazy var session: URLSession = {
        let configuration: URLSessionConfiguration
        #if os(iOS)
        configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.isDiscretionary = false
        #else
        configuration = URLSessionConfiguration.default
        #endif
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 60
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    func upload(request: URLRequest, bodyFile: URL) async throws -> (Data, URLResponse) {
        let task = session.uploadTask(with: request, fromFile: bodyFile)
        return try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            completions[task.taskIdentifier] = { result in
                continuation.resume(with: result)
            }
            lock.unlock()
            task.resume()
        }
    }

    func registerBackgroundCompletionHandler(_ handler: @escaping () -> Void) {
        lock.lock()
        backgroundCompletionHandler = handler
        lock.unlock()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        responseData[dataTask.taskIdentifier, default: Data()].append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        let data = responseData.removeValue(forKey: task.taskIdentifier) ?? Data()
        let completion = completions.removeValue(forKey: task.taskIdentifier)
        lock.unlock()

        guard let completion else { return }
        if let error {
            completion(.failure(error))
        } else if let response = task.response {
            completion(.success((data, response)))
        } else {
            completion(.failure(RemoteOMRServiceError.invalidResponse))
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        lock.lock()
        let handler = backgroundCompletionHandler
        backgroundCompletionHandler = nil
        lock.unlock()
        handler?()
    }
}

/// Rasterization and multipart construction can be expensive for a multi-page PDF.
/// Keep those synchronous Core Graphics and file operations off the Score workspace's main actor.
private enum RemoteOMRSourcePreparer {
    static func renderedPages(from sourceURLs: [URL]) async throws -> [NativeOMRRenderedPage] {
        try await Task.detached(priority: .userInitiated) {
            let renderer = NativeOMRPrototypeService()
            var pages: [NativeOMRRenderedPage] = []
            for sourceURL in sourceURLs {
                for renderedPage in try renderer.renderedPages(from: sourceURL) {
                    pages.append(
                        NativeOMRRenderedPage(
                            pageIndex: pages.count,
                            pixelWidth: renderedPage.pixelWidth,
                            pixelHeight: renderedPage.pixelHeight,
                            imageData: renderedPage.imageData
                        )
                    )
                }
            }
            return pages
        }.value
    }

    static func multipartBodyFile(sourceURLs: [URL], clientJobID: String) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            guard let firstSource = sourceURLs.first else {
                throw RemoteOMRServiceError.mixedInputTypes
            }
            let boundary = "VocalDive-\(clientJobID)"
            var data = Data()
            for url in sourceURLs {
                let filename = url.lastPathComponent.replacingOccurrences(of: "\"", with: "")
                let mimeType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/*"
                data.append("--\(boundary)\r\n".data(using: .utf8)!)
                data.append("Content-Disposition: form-data; name=\"files\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
                data.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
                data.append(try Data(contentsOf: url))
                data.append("\r\n".data(using: .utf8)!)
            }
            data.append("--\(boundary)--\r\n".data(using: .utf8)!)

            let file = firstSource.deletingLastPathComponent().appending(path: "upload-\(clientJobID).multipart")
            try data.write(to: file, options: .atomic)
            return file
        }.value
    }
}

enum RemoteOMRBackgroundTransfer {
    static func handleEvents(identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == RemoteOMRUploadCoordinator.sessionIdentifier else {
            completionHandler()
            return
        }
        RemoteOMRUploadCoordinator.shared.registerBackgroundCompletionHandler(completionHandler)
    }
}

@MainActor
final class RemoteOMRService {
    typealias ProgressHandler = (NativeOMRScanProgress, String) -> Void

    private let configurationStore: RemoteOMRConfigurationStore
    private let renderer: NativeOMRPrototypeService
    private let session: URLSession
    private let fileManager: FileManager
    private let pendingJobs: PendingRemoteOMRJobStore
    private let uploader: RemoteOMRUploadCoordinator

    init(
        configurationStore: RemoteOMRConfigurationStore = .shared,
        renderer: NativeOMRPrototypeService = NativeOMRPrototypeService(),
        session: URLSession? = nil,
        fileManager: FileManager = .default
    ) {
        self.configurationStore = configurationStore
        self.renderer = renderer
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.waitsForConnectivity = true
            configuration.timeoutIntervalForRequest = 60
            configuration.timeoutIntervalForResource = 60 * 60
            self.session = URLSession(configuration: configuration)
        }
        self.fileManager = fileManager
        self.pendingJobs = PendingRemoteOMRJobStore(fileManager: fileManager)
        self.uploader = .shared
    }

    func makeSession(from sourceURLs: [URL], progress: ProgressHandler? = nil) async throws -> RemoteOMRCompletedSession {
        let inputKind = try validate(sourceURLs: sourceURLs)
        let sourceName = sourceURLs.count == 1 ? sourceURLs[0].deletingPathExtension().lastPathComponent : "\(sourceURLs.count) score images"
        let pendingJob = try pendingJobs.stage(sourceURLs: sourceURLs, sourceName: sourceName, inputKind: inputKind)
        return try await complete(pendingJob, progress: progress)
    }

    func resumePending(progress: ProgressHandler? = nil) async -> [RemoteOMRCompletedSession] {
        var completed: [RemoteOMRCompletedSession] = []
        for job in pendingJobs.pending() {
            do {
                completed.append(try await complete(job, progress: progress))
            } catch {
                continue
            }
        }
        return completed
    }

    func submitCorrection(
        jobID: String,
        correctedMusicXML: String,
        correctionMetadata: [String: String]
    ) async throws -> String {
        let configuration = try configurationStore.currentConfiguration()
        let checksum = Self.sha256Hex("\(jobID):\(correctedMusicXML)")
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/jobs/\(jobID)/corrections"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue(checksum, forHTTPHeaderField: "Idempotency-Key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            RemoteOMRCorrectionSubmissionRequest(
                correctedMusicXML: correctedMusicXML,
                correctionMetadata: correctionMetadata
            )
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 410 {
            throw RemoteOMRServiceError.sourceNoLongerRetained
        }
        try validate(response: response, data: data)
        return try JSONDecoder().decode(RemoteOMRCorrectionSubmissionResponse.self, from: data).trainingRecordID
    }

    private func complete(_ initialJob: PendingRemoteOMRJob, progress: ProgressHandler?) async throws -> RemoteOMRCompletedSession {
        let configuration = try configurationStore.currentConfiguration()
        guard let inputKind = initialJob.inputKind else { throw RemoteOMRServiceError.mixedInputTypes }
        var job = initialJob
        let sourceURLs = job.stagedPaths.map(URL.init(fileURLWithPath:))
        let renderedPages = try await RemoteOMRSourcePreparer.renderedPages(from: sourceURLs)
        let serverJobID: String
        if let existing = job.serverJobID {
            serverJobID = existing
        } else {
            progress?(.make(.connectingToServer, fraction: 0.03), "")
            let request = try makeUploadRequest(configuration: configuration, sourceURLs: sourceURLs, clientJobID: job.clientJobID)
            let bodyFile = try await RemoteOMRSourcePreparer.multipartBodyFile(
                sourceURLs: sourceURLs,
                clientJobID: job.clientJobID
            )
            defer { try? fileManager.removeItem(at: bodyFile) }
            progress?(.make(.uploadingToServer, fraction: 0.15, totalPages: renderedPages.count), "")
            let (data, response) = try await uploader.upload(request: request, bodyFile: bodyFile)
            try validate(response: response, data: data)
            let created = try JSONDecoder().decode(RemoteOMRCreateJobResponse.self, from: data)
            serverJobID = created.jobID
            job.serverJobID = serverJobID
            try pendingJobs.update(job)
        }

        var status = RemoteOMRJobStatus(
            jobID: serverJobID,
            state: .queued,
            sourceName: job.sourceName,
            totalPages: renderedPages.count,
            completedPages: 0
        )
        while status.state != .ready {
            if status.state == .failed || status.state == .cancelled {
                if status.errorCode == "engine_unavailable" {
                    throw RemoteOMRServiceError.engineUnavailable
                }
                if [
                    "source_processing_failed", "recognition_failed", "result_assembly_failed", "worker_failed",
                    "recognition_timeout", "recognition_process_failed", "no_musicxml_output",
                    "musicxml_invalid", "musicxml_merge_incompatible",
                ].contains(status.errorCode) {
                    throw RemoteOMRServiceError.processingUnavailable
                }
                throw RemoteOMRServiceError.server(status.error ?? status.detail ?? "VocalDive OMR did not finish.")
            }
            let queueDetail = status.queuePosition.map { L10n.tr("score.scan.queue_position", $0) } ?? ""
            progress?(progressValue(for: status), queueDetail)
            try await Task.sleep(for: .seconds(2))
            status = try await fetchStatus(jobID: status.jobID, configuration: configuration)
            #if DEBUG
            await MainActor.run {
                RemoteOMRDiagnosticsStore.shared.record(status)
            }
            #endif
        }

        progress?(.make(.downloadingResult, fraction: 0.94, completedPages: status.totalPages, totalPages: status.totalPages), "")
        let xmlData = try await downloadResult(jobID: status.jobID, configuration: configuration)
        guard let musicXML = String(data: xmlData, encoding: .utf8), !musicXML.isEmpty else {
            throw RemoteOMRServiceError.invalidResponse
        }
        progress?(.make(.openingEditor, fraction: 0.98, completedPages: status.totalPages, totalPages: status.totalPages), "")
        let result = RemoteOMRCompletedSession(
            sourceName: job.sourceName,
            inputKind: inputKind,
            renderedPages: renderedPages,
            generatedMusicXML: musicXML,
            serverJobID: status.jobID
        )
        pendingJobs.remove(job)
        return result
    }

    private func validate(sourceURLs: [URL]) throws -> OMRInputKind {
        guard !sourceURLs.isEmpty else { throw RemoteOMRServiceError.mixedInputTypes }
        let totalBytes = try sourceURLs.reduce(0) { partial, url in
            partial + Int(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
        guard totalBytes <= 50 * 1024 * 1024 else { throw RemoteOMRServiceError.fileTooLarge }
        let extensions = Set(sourceURLs.map { $0.pathExtension.lowercased() })
        if extensions == Set(["pdf"]) {
            guard sourceURLs.count == 1 else { throw RemoteOMRServiceError.mixedInputTypes }
            guard renderer.pageCount(for: sourceURLs[0]) <= 30 else { throw RemoteOMRServiceError.tooManyPDFPages }
            return .pdf
        }
        guard sourceURLs.count <= 30 else { throw RemoteOMRServiceError.tooManyImages }
        guard sourceURLs.allSatisfy({ $0.isSupportedScoreImage }) else { throw RemoteOMRServiceError.mixedInputTypes }
        return .image
    }

    private func makeUploadRequest(
        configuration: (endpoint: URL, token: String),
        sourceURLs: [URL],
        clientJobID: String
    ) throws -> URLRequest {
        let boundary = "VocalDive-\(clientJobID)"
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/jobs"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        request.setValue(clientJobID, forHTTPHeaderField: "Idempotency-Key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func fetchStatus(jobID: String, configuration: (endpoint: URL, token: String)) async throws -> RemoteOMRJobStatus {
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/jobs/\(jobID)"))
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(RemoteOMRJobStatus.self, from: data)
    }

    private func downloadResult(jobID: String, configuration: (endpoint: URL, token: String)) async throws -> Data {
        var request = URLRequest(url: configuration.endpoint.appending(path: "v1/jobs/\(jobID)/result"))
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 {
            throw RemoteOMRServiceError.missingResult
        }
        try validate(response: response, data: data)
        return data
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw RemoteOMRServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            let detail = payload?["detail"]
            if let detail = detail as? [String: Any], detail["code"] as? String == "engine_unavailable" {
                throw RemoteOMRServiceError.engineUnavailable
            }
            let message = detail as? String
            throw RemoteOMRServiceError.server(message ?? "VocalDive OMR returned HTTP \(http.statusCode).")
        }
    }

    private static func sha256Hex(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func progressValue(for status: RemoteOMRJobStatus) -> NativeOMRScanProgress {
        switch status.state {
        case .uploading: return .make(.uploadingToServer, fraction: 0.15)
        case .queued: return .make(.waitingForServer, fraction: 0.25, totalPages: status.totalPages)
        case .rasterizing: return .make(.rasterizingPages, fraction: 0.35, totalPages: status.totalPages)
        case .recognizing:
            let pageFraction = Double(status.completedPages) / Double(max(status.totalPages, 1))
            let displayedPage = min(
                status.totalPages,
                max(status.completedPages, status.currentPage ?? status.completedPages)
            )
            let phase: NativeOMRScanProgressPhase
            if status.attentionNeeded == true {
                phase = .takingLonger
            } else {
                switch status.engineStage {
                case "noteheads":
                    phase = .readingNoteheads
                case "rhythm", "building_musicxml":
                    phase = .buildingEditableScore
                default:
                    phase = .analyzingNotation
                }
            }
            return .make(
                phase,
                fraction: 0.38 + pageFraction * 0.48,
                completedPages: displayedPage,
                totalPages: status.totalPages,
                elapsedSeconds: status.elapsedSeconds ?? 0
            )
        case .assembling: return .make(.generatingMusicXML, fraction: 0.89, completedPages: status.totalPages, totalPages: status.totalPages)
        case .ready: return .make(.downloadingResult, fraction: 0.94, completedPages: status.totalPages, totalPages: status.totalPages)
        case .failed, .cancelled: return .make(.finished, fraction: 1)
        }
    }
}

private extension URL {
    var isSupportedScoreImage: Bool {
        ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp"].contains(pathExtension.lowercased())
    }
}
