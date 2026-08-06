import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(VocalDiveCore)
import VocalDiveCore
#endif

struct SupportView: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var category: FeedbackCategory = .bug
    @State private var summary = ""
    @State private var details = ""
    @State private var replyEmail = ""
    @State private var feedbackStatus: FeedbackSubmissionStatus = .idle
    @State private var isSubmitting = false
    @ObservedObject private var remoteOMR = RemoteOMRConfigurationStore.shared
    #if DEBUG
    @ObservedObject private var remoteOMRDiagnostics = RemoteOMRDiagnosticsStore.shared
    #endif
    @State private var remoteOMREndpoint = ""
    @State private var remoteOMREmail = ""
    @State private var remoteOMRStatus = ""
    @State private var isConnectingRemoteOMR = false
    @State private var remoteOMRBirthday = ""
    @State private var remoteOMRGoals = ""
    @State private var isSavingRemoteOMRProfile = false
    @State private var showRemoteOMRConsent = false
    @State private var showRemoteOMRDeleteConfirmation = false

    private let manualURL = URL(string: "https://chein-shawn.github.io/vocaldive/manual.html")
    private let changelogURL = URL(string: "https://chein-shawn.github.io/vocaldive/changelog.html")
    private let feedbackService = FeedbackSubmissionService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: L10n.tr("Settings"),
                    subtitle: L10n.tr("Language, usage, documentation, contact, and feedback"),
                    systemImage: "gearshape"
                )

                languageSettings
                syncSettings
                privateOMRSettings
                usageSection
                quickLinks
                contactSection
                feedbackForm
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
        .onAppear {
            remoteOMREndpoint = remoteOMR.endpointString
            loadRemoteOMRProfile()
            resumeRemoteOMREmailConnectionIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                resumeRemoteOMREmailConnectionIfNeeded()
            }
        }
        .alert(L10n.tr("settings.vocaldive_omr.consent_title"), isPresented: $showRemoteOMRConsent) {
            Button(L10n.tr("settings.vocaldive_omr.consent_cancel"), role: .cancel) {}
            Button(L10n.tr("settings.vocaldive_omr.consent_continue")) {
                connectRemoteOMRWithEmail()
            }
        } message: {
            Text(L10n.tr("settings.vocaldive_omr.consent_message"))
        }
        .confirmationDialog(
            L10n.tr("settings.vocaldive_omr.delete_account_title"),
            isPresented: $showRemoteOMRDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr("settings.vocaldive_omr.delete_account_confirm"), role: .destructive) {
                deleteRemoteOMRAccount()
            }
        } message: {
            Text(L10n.tr("settings.vocaldive_omr.delete_account_message"))
        }
    }

    private var privateOMRSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("settings.vocaldive_omr.section"))

            Text(L10n.tr("settings.vocaldive_omr.description"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let connectedEmail = remoteOMR.connectedEmail, remoteOMR.isConfigured {
                Label(L10n.tr("settings.vocaldive_omr.connected", connectedEmail), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                HStack(spacing: 10) {
                    Button(L10n.tr("settings.vocaldive_omr.reconnect")) {
                        remoteOMR.disconnect()
                        remoteOMRStatus = ""
                    }
                    .buttonStyle(.bordered)

                    Button(L10n.tr("settings.vocaldive_omr.disconnect"), role: .destructive) {
                        remoteOMR.disconnect()
                        remoteOMRStatus = ""
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                TextField(L10n.tr("settings.vocaldive_omr.birth_date"), text: $remoteOMRBirthday)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $remoteOMRGoals)
                    .frame(minHeight: 72)
                    .overlay(alignment: .topLeading) {
                        if remoteOMRGoals.isEmpty {
                            Text(L10n.tr("settings.vocaldive_omr.goals"))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 10) {
                    Button(L10n.tr("settings.vocaldive_omr.save_profile")) {
                        saveRemoteOMRProfile()
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingRemoteOMRProfile)

                    Button(L10n.tr("settings.vocaldive_omr.delete_account"), role: .destructive) {
                        showRemoteOMRDeleteConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingRemoteOMRProfile)
                }
            } else {
                TextField(L10n.tr("settings.vocaldive_omr.email"), text: $remoteOMREmail)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    #endif

                Button(L10n.tr("settings.vocaldive_omr.send_link")) {
                    beginRemoteOMREmailConnection()
                }
                .buttonStyle(.borderedProminent)
                .disabled(remoteOMREmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isConnectingRemoteOMR)
            }

            DisclosureGroup(L10n.tr("settings.vocaldive_omr.advanced")) {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(L10n.tr("settings.vocaldive_omr.server"), text: $remoteOMREndpoint)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()

                    Button(L10n.tr("settings.vocaldive_omr.save_server")) {
                        do {
                            try remoteOMR.updateEndpoint(remoteOMREndpoint)
                            remoteOMREndpoint = remoteOMR.endpointString
                            remoteOMRStatus = L10n.tr("settings.vocaldive_omr.updated")
                        } catch {
                            remoteOMRStatus = L10n.tr("settings.vocaldive_omr.failed", error.localizedDescription)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.top, 6)
            }

            if remoteOMRStatus.isEmpty == false {
                Text(remoteOMRStatus)
                    .font(.caption)
                    .foregroundStyle(remoteOMR.isConfigured ? Color.secondary : Color.red)
            }

            #if DEBUG
            remoteOMRDiagnosticsPanel
            #endif
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    #if DEBUG
    private var remoteOMRDiagnosticsPanel: some View {
        DisclosureGroup(L10n.tr("settings.vocaldive_omr.debug_diagnostics")) {
            if let status = remoteOMRDiagnostics.latestStatus {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.vocaldive_omr.debug_stage", status.engineStage ?? "-"))
                    Text(L10n.tr("settings.vocaldive_omr.debug_elapsed", elapsedText(status.elapsedSeconds)))
                    Text(L10n.tr("settings.vocaldive_omr.debug_heartbeat", status.heartbeatAt ?? "-"))
                    Text(L10n.tr("settings.vocaldive_omr.debug_gpu", gpuText(status.resourceSnapshot?.gpu)))
                    Text(L10n.tr("settings.vocaldive_omr.debug_process", processText(status.resourceSnapshot?.oemer)))
                    Text(L10n.tr("settings.vocaldive_omr.debug_error_code", status.errorCode ?? "-"))

                    Button(L10n.tr("settings.vocaldive_omr.debug_copy")) {
                        copyDiagnostics(status)
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .padding(.top, 6)
            } else {
                Text(L10n.tr("settings.vocaldive_omr.debug_no_job"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)
            }
        }
    }

    private func elapsedText(_ seconds: Int?) -> String {
        let value = max(0, seconds ?? 0)
        return String(format: "%d:%02d", value / 60, value % 60)
    }

    private func gpuText(_ gpu: RemoteOMRGPUResourceSnapshot?) -> String {
        guard let gpu else { return "-" }
        let used = gpu.memoryUsedMiB.map(String.init) ?? "-"
        let total = gpu.memoryTotalMiB.map(String.init) ?? "-"
        let utilization = gpu.utilizationPercent.map(String.init) ?? "-"
        return "\(utilization)% | \(used)/\(total) MiB"
    }

    private func processText(_ process: RemoteOMRProcessResourceSnapshot?) -> String {
        guard let process else { return "-" }
        let alive = process.alive == true ? "alive" : "stopped"
        let cpu = process.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "-"
        let memory = process.memoryRSSMiB.map { String(format: "%.1f MiB", $0) } ?? "-"
        return "\(alive) | \(cpu) | \(memory)"
    }

    private func copyDiagnostics(_ status: RemoteOMRJobStatus) {
        let report = [
            "state=\(status.state.rawValue)",
            "stage=\(status.engineStage ?? "-")",
            "elapsed=\(elapsedText(status.elapsedSeconds))",
            "heartbeat=\(status.heartbeatAt ?? "-")",
            "gpu=\(gpuText(status.resourceSnapshot?.gpu))",
            "process=\(processText(status.resourceSnapshot?.oemer))",
            "error_code=\(status.errorCode ?? "-")",
        ].joined(separator: "\n")
        #if os(iOS)
        UIPasteboard.general.string = report
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        #endif
    }
    #endif

    private func beginRemoteOMREmailConnection() {
        showRemoteOMRConsent = true
    }

    private func connectRemoteOMRWithEmail() {
        let email = remoteOMREmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        remoteOMREmail = email
        isConnectingRemoteOMR = true
        remoteOMRStatus = ""
        Task {
            do {
                let session = try await remoteOMR.requestEmailLink(email: email)
                isConnectingRemoteOMR = false
                beginRemoteOMREmailPolling(session)
            } catch {
                remoteOMRStatus = remoteOMRErrorMessage(error)
                isConnectingRemoteOMR = false
            }
        }
    }

    private func resumeRemoteOMREmailConnectionIfNeeded() {
        guard remoteOMR.isConfigured == false,
              isConnectingRemoteOMR == false,
              let session = remoteOMR.pendingEmailLoginSession() else {
            return
        }
        remoteOMREmail = session.email
        beginRemoteOMREmailPolling(session)
    }

    private func beginRemoteOMREmailPolling(_ session: RemoteOMREmailLoginSession) {
        guard isConnectingRemoteOMR == false else { return }
        isConnectingRemoteOMR = true
        remoteOMRStatus = L10n.tr("settings.vocaldive_omr.waiting", session.email)
        Task {
            do {
                try await remoteOMR.waitForEmailConnection(session)
                remoteOMRStatus = L10n.tr("settings.vocaldive_omr.connected", session.email)
                loadRemoteOMRProfile()
            } catch {
                remoteOMRStatus = remoteOMRErrorMessage(error)
            }
            isConnectingRemoteOMR = false
        }
    }

    private func loadRemoteOMRProfile() {
        guard remoteOMR.isConfigured else { return }
        Task {
            guard let profile = try? await remoteOMR.fetchProfile() else { return }
            remoteOMRBirthday = profile.birthDate ?? ""
            remoteOMRGoals = profile.goals.joined(separator: "\n")
        }
    }

    private func saveRemoteOMRProfile() {
        isSavingRemoteOMRProfile = true
        Task {
            do {
                let birthday = remoteOMRBirthday.trimmingCharacters(in: .whitespacesAndNewlines)
                let profile = try await remoteOMR.updateProfile(
                    birthDate: birthday.isEmpty ? nil : birthday,
                    goals: remoteOMRGoals.split(separator: "\n").map(String.init)
                )
                remoteOMRBirthday = profile.birthDate ?? ""
                remoteOMRGoals = profile.goals.joined(separator: "\n")
                remoteOMRStatus = L10n.tr("settings.vocaldive_omr.profile_saved")
            } catch {
                remoteOMRStatus = L10n.tr("settings.vocaldive_omr.failed", error.localizedDescription)
            }
            isSavingRemoteOMRProfile = false
        }
    }

    private func deleteRemoteOMRAccount() {
        isSavingRemoteOMRProfile = true
        Task {
            do {
                try await remoteOMR.deleteRemoteAccount()
                remoteOMRBirthday = ""
                remoteOMRGoals = ""
                remoteOMRStatus = L10n.tr("settings.vocaldive_omr.account_deleted")
            } catch {
                remoteOMRStatus = L10n.tr("settings.vocaldive_omr.failed", error.localizedDescription)
            }
            isSavingRemoteOMRProfile = false
        }
    }

    private func remoteOMRErrorMessage(_ error: Error) -> String {
        guard let remoteError = error as? RemoteOMRServiceError else {
            return L10n.tr("settings.vocaldive_omr.connection_failed")
        }
        switch remoteError {
        case let .emailLinkRateLimited(seconds):
            let duration = String(format: "%02d:%02d", seconds / 60, seconds % 60)
            return L10n.tr("settings.vocaldive_omr.rate_limited", duration)
        case .invalidEmailLinkResponse:
            return L10n.tr("settings.vocaldive_omr.link_response_invalid")
        case .invalidEmailPollResponse:
            return L10n.tr("settings.vocaldive_omr.poll_response_invalid")
        case .emailConnectionExpired:
            return L10n.tr("settings.vocaldive_omr.connection_expired")
        default:
            return L10n.tr("settings.vocaldive_omr.connection_failed")
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Documentation"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                SupportLinkTile(
                    title: L10n.tr("User Manual"),
                    subtitle: L10n.tr("Import scores, practice, annotate, and export."),
                    systemImage: "book"
                ) {
                    open(manualURL)
                }

                SupportLinkTile(
                    title: L10n.tr("Changelog"),
                    subtitle: L10n.tr("New features, fixes, and known issues."),
                    systemImage: "clock.arrow.circlepath"
                ) {
                    open(changelogURL)
                }
            }
        }
    }

    private var languageSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Language"))

            Picker(L10n.tr("Display Language"), selection: $appSettings.selectedLanguage) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeDisplayName).tag(language)
                }
            }
            .pickerStyle(.menu)

            Text(L10n.tr("Choose the interface language. The change applies immediately across the app."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var usageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Usage"))
            UsageStatsContent(usageTracking: workspace.usageTracking)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var syncSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("settings.sync.section"))

            Toggle(
                isOn: Binding(
                    get: { workspace.isSyncEnabled },
                    set: { workspace.setSyncEnabled($0) }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr("settings.sync.toggle"))
                        .font(.headline)
                    Text(L10n.tr("settings.sync.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!workspace.syncStatus.canEnable && !workspace.isSyncEnabled)

            VStack(alignment: .leading, spacing: 6) {
                labeledSyncRow(
                    title: L10n.tr("settings.sync.status_label"),
                    value: syncStateLabel(workspace.syncStatus)
                )
                labeledSyncRow(
                    title: L10n.tr("settings.sync.last_synced_label"),
                    value: formattedLastSync(workspace.syncStatus.lastSuccessfulSync)
                )
                if let reason = workspace.syncStatus.unavailableReason {
                    Text(syncUnavailableMessage(reason))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let lastErrorSummary = workspace.syncStatus.lastErrorSummary, !lastErrorSummary.isEmpty {
                    Text(L10n.tr("settings.sync.error_prefix", lastErrorSummary))
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var contactSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Contact"))

            SupportLinkTile(
                title: L10n.tr("Official Website"),
                subtitle: FeedbackConfiguration.current.officialWebsite,
                systemImage: "globe"
            ) {
                open(FeedbackConfiguration.current.officialWebsiteURL)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("Feel free to contact me"))
                    .font(.headline)
                Text(FeedbackConfiguration.current.supportEmail)
                    .foregroundStyle(.secondary)
                Text(FeedbackConfiguration.current.supportPhone)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.quaternary, lineWidth: 1)
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Feedback"))

            Picker(L10n.tr("Type"), selection: $category) {
                ForEach(FeedbackCategory.allCases) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)

            TextField(L10n.tr("Summary"), text: $summary)
                .textFieldStyle(.roundedBorder)

            replyEmailField

            Text(L10n.tr("support.feedback.details"))
                .font(.subheadline.weight(.semibold))

            TextEditor(text: $details)
                .frame(minHeight: 150)
                .padding(8)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.quaternary, lineWidth: 1)
                }

            HStack {
                Button {
                    Task {
                        await submitFeedback()
                    }
                } label: {
                    Label(
                        isSubmitting ? L10n.tr("support.feedback.sending") : L10n.tr("support.feedback.send"),
                        systemImage: "paperplane"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSubmitFeedback)

                Button {
                    open(FeedbackConfiguration.current.officialWebsiteURL)
                } label: {
                    Label(L10n.tr("Official Website"), systemImage: "globe")
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            if let statusText = feedbackStatus.text {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(feedbackStatus.color)
            }

            if FeedbackConfiguration.current.feedbackEndpointURL == nil {
                Text(L10n.tr("support.feedback.backend_not_configured"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(L10n.tr("support.feedback.privacy"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }

    private var canSubmitFeedback: Bool {
        !isSubmitting &&
        !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        FeedbackConfiguration.current.feedbackEndpointURL != nil
    }

    @ViewBuilder
    private var replyEmailField: some View {
        #if os(iOS)
        TextField(L10n.tr("support.feedback.reply_email"), text: $replyEmail)
            .textFieldStyle(.roundedBorder)
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
        #else
        TextField(L10n.tr("support.feedback.reply_email"), text: $replyEmail)
            .textFieldStyle(.roundedBorder)
        #endif
    }

    private func open(_ url: URL?) {
        guard let url else {
            return
        }
        openURL(url)
    }

    private func syncStateLabel(_ snapshot: SyncStatusSnapshot) -> String {
        switch snapshot.state {
        case .off:
            return L10n.tr("settings.sync.state.off")
        case .on:
            return L10n.tr("settings.sync.state.on")
        case .syncing:
            return L10n.tr("settings.sync.state.syncing")
        case .unavailable:
            return L10n.tr("settings.sync.state.unavailable")
        case .error:
            return L10n.tr("settings.sync.state.error")
        }
    }

    private func formattedLastSync(_ date: Date?) -> String {
        guard let date else {
            return L10n.tr("settings.sync.not_yet_synced")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: appSettings.selectedLanguage.localeIdentifier)
        return formatter.string(from: date)
    }

    private func syncUnavailableMessage(_ reason: SyncUnavailableReason) -> String {
        switch reason {
        case .cloudKitContainerUnavailable:
            return L10n.tr("settings.sync.unavailable.cloudkit")
        case .iCloudAccountUnavailable:
            return L10n.tr("settings.sync.unavailable.account")
        }
    }

    @ViewBuilder
    private func labeledSyncRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 108, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }

    @MainActor
    private func submitFeedback() async {
        guard canSubmitFeedback else {
            return
        }

        isSubmitting = true
        feedbackStatus = .sending

        do {
            try await feedbackService.submit(
                category: category,
                summary: summary,
                details: details,
                replyEmail: replyEmail,
                currentSection: workspace.selectedSection,
                selectedLanguage: appSettings.selectedLanguage
            )
            feedbackStatus = .sent
            summary = ""
            details = ""
            replyEmail = ""
            category = .bug
        } catch {
            feedbackStatus = .failed(error.localizedDescription)
        }

        isSubmitting = false
    }
}

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case usability
    case research

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug:
            return L10n.tr("Bug")
        case .feature:
            return L10n.tr("Feature")
        case .usability:
            return L10n.tr("Usability")
        case .research:
            return L10n.tr("Research")
        }
    }

    var systemImage: String {
        switch self {
        case .bug:
            return "exclamationmark.triangle"
        case .feature:
            return "sparkles"
        case .usability:
            return "hand.tap"
        case .research:
            return "book.pages"
        }
    }
}

private enum FeedbackSubmissionStatus {
    case idle
    case sending
    case sent
    case failed(String)

    var text: String? {
        switch self {
        case .idle:
            return nil
        case .sending:
            return L10n.tr("support.feedback.sending")
        case .sent:
            return L10n.tr("support.feedback.sent")
        case let .failed(message):
            return message
        }
    }

    var color: Color {
        switch self {
        case .idle:
            return .secondary
        case .sending:
            return .secondary
        case .sent:
            return .green
        case .failed:
            return .red
        }
    }
}

private struct SupportLinkTile: View {
    var title: String
    var subtitle: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

struct UsageStatsContent: View {
    @ObservedObject var usageTracking: UsageTrackingStore

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
            MetricTile(
                title: L10n.tr("Total Time"),
                value: DurationFormat.short(usageTracking.totalDuration),
                systemImage: "timer"
            )
            MetricTile(
                title: L10n.tr("Sessions"),
                value: "\(usageTracking.dailySummaries.count) days",
                systemImage: "calendar"
            )
            MetricTile(
                title: L10n.tr("Active"),
                value: usageTracking.activeFeature?.localizedDisplayName ?? L10n.tr("None"),
                systemImage: "dot.radiowaves.left.and.right"
            )
        }

        UsageFeatureBreakdown(durations: usageTracking.featureDurations)
        DailyUsageTrend(summaries: usageTracking.dailySummaries)
    }
}

struct UsageStatsView: View {
    @ObservedObject var usageTracking: UsageTrackingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: L10n.tr("Usage"),
                    subtitle: L10n.tr("Daily practice trend and feature time"),
                    systemImage: "chart.bar.xaxis"
                )
                UsageStatsContent(usageTracking: usageTracking)
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct UsageFeatureBreakdown: View {
    var durations: [UsageFeature: TimeInterval]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Feature Time"))
            let maxDuration = max(durations.values.max() ?? 1, 1)
            ForEach(UsageFeature.allCases, id: \.self) { feature in
                UsageBarRow(
                    title: feature.localizedDisplayName,
                    value: durations[feature, default: 0],
                    maxValue: maxDuration
                )
            }
        }
    }
}

private struct DailyUsageTrend: View {
    var summaries: [DailyUsageSummary]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(L10n.tr("Daily Trend"))
            if summaries.isEmpty {
                Text(L10n.tr("Usage appears after you switch between sections."))
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            } else {
                let maxDuration = max(summaries.map(\.totalDuration).max() ?? 1, 1)
                ForEach(summaries.suffix(14)) { summary in
                    UsageBarRow(title: summary.dayKey, value: summary.totalDuration, maxValue: maxDuration)
                }
            }
        }
    }
}

private struct UsageBarRow: View {
    var title: String
    var value: TimeInterval
    var maxValue: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline)
                .frame(width: 120, alignment: .leading)

            GeometryReader { proxy in
                let width = proxy.size.width * max(0.04, value / max(maxValue, 1))
                RoundedRectangle(cornerRadius: 4)
                    .fill(.tint.opacity(0.75))
                    .frame(width: width)
            }
            .frame(height: 12)

            Text(DurationFormat.short(value))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

private enum DurationFormat {
    static func short(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        if seconds < 60 {
            return "\(seconds)s"
        }

        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        return "\(hours)h \(remainder)m"
    }
}
