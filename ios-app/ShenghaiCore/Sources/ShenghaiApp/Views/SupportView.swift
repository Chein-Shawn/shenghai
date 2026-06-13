import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct SupportView: View {
    @ObservedObject var workspace: ShenghaiWorkspace
    @EnvironmentObject private var appSettings: AppSettingsStore
    @Environment(\.openURL) private var openURL
    @State private var category: FeedbackCategory = .bug
    @State private var summary = ""
    @State private var details = ""
    @State private var replyEmail = ""
    @State private var feedbackStatus: FeedbackSubmissionStatus = .idle
    @State private var isSubmitting = false

    private let manualURL = URL(string: "https://chein-shawn.github.io/shenghai/manual.html")
    private let changelogURL = URL(string: "https://chein-shawn.github.io/shenghai/changelog.html")
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
                usageSection
                quickLinks
                contactSection
                feedbackForm
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
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
