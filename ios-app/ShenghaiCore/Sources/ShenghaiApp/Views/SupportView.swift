import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct SupportView: View {
    @Bindable var workspace: ShenghaiWorkspace
    @Environment(\.openURL) private var openURL
    @State private var category: FeedbackCategory = .bug
    @State private var summary = ""
    @State private var details = ""

    private let manualURL = URL(string: "https://chein-shawn.github.io/shenghai/manual.html")
    private let changelogURL = URL(string: "https://chein-shawn.github.io/shenghai/changelog.html")
    private let githubIssueURL = URL(string: "https://github.com/Chein-Shawn/shenghai/issues/new")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Support",
                    subtitle: "Manual, release notes, and tester feedback",
                    systemImage: "questionmark.bubble"
                )

                quickLinks
                feedbackForm
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Documentation")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                SupportLinkTile(
                    title: "User Manual",
                    subtitle: "Import scores, practice, annotate, and export.",
                    systemImage: "book"
                ) {
                    open(manualURL)
                }

                SupportLinkTile(
                    title: "Changelog",
                    subtitle: "New features, fixes, and known issues.",
                    systemImage: "clock.arrow.circlepath"
                ) {
                    open(changelogURL)
                }
            }
        }
    }

    private var feedbackForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Feedback")

            Picker("Type", selection: $category) {
                ForEach(FeedbackCategory.allCases) { category in
                    Label(category.title, systemImage: category.systemImage)
                        .tag(category)
                }
            }
            .pickerStyle(.segmented)

            TextField("Summary", text: $summary)
                .textFieldStyle(.roundedBorder)

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
                    open(issueURL)
                } label: {
                    Label("GitHub Issue", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.borderedProminent)
                .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button {
                    open(mailURL)
                } label: {
                    Label("Mail Draft", systemImage: "envelope")
                }
                .buttonStyle(.bordered)
                .disabled(summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }

            Text("Feedback sends only what you choose to include. For private repos, GitHub Issues are useful for invited internal testers; Mail Draft is the fallback.")
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

    private var issueURL: URL? {
        guard var components = URLComponents(url: githubIssueURL ?? URL(filePath: "/"), resolvingAgainstBaseURL: false) else {
            return nil
        }
        components.queryItems = [
            URLQueryItem(name: "title", value: "[\(category.title)] \(summary)"),
            URLQueryItem(name: "body", value: feedbackBody)
        ]
        return components.url
    }

    private var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "[Shenghai \(category.title)] \(summary)"),
            URLQueryItem(name: "body", value: feedbackBody)
        ]
        return components.url
    }

    private var feedbackBody: String {
        """
        Type: \(category.title)
        Screen: \(workspace.selectedSection.title)
        App stage: Alpha

        Details:
        \(details)
        """
    }

    private func open(_ url: URL?) {
        guard let url else {
            return
        }
        openURL(url)
    }
}

private enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug
    case feature
    case usability
    case research

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bug:
            return "Bug"
        case .feature:
            return "Feature"
        case .usability:
            return "Usability"
        case .research:
            return "Research"
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

struct UsageStatsView: View {
    @Bindable var usageTracking: UsageTrackingStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Usage",
                    subtitle: "Daily practice trend and feature time",
                    systemImage: "chart.bar.xaxis"
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricTile(
                        title: "Total Time",
                        value: DurationFormat.short(usageTracking.totalDuration),
                        systemImage: "timer"
                    )
                    MetricTile(
                        title: "Sessions",
                        value: "\(usageTracking.dailySummaries.count) days",
                        systemImage: "calendar"
                    )
                    MetricTile(
                        title: "Active",
                        value: usageTracking.activeFeature?.displayName ?? "None",
                        systemImage: "dot.radiowaves.left.and.right"
                    )
                }

                UsageFeatureBreakdown(durations: usageTracking.featureDurations)
                DailyUsageTrend(summaries: usageTracking.dailySummaries)
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
            SectionTitle("Feature Time")
            let maxDuration = max(durations.values.max() ?? 1, 1)
            ForEach(UsageFeature.allCases, id: \.self) { feature in
                UsageBarRow(
                    title: feature.displayName,
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
            SectionTitle("Daily Trend")
            if summaries.isEmpty {
                Text("Usage appears after you switch between sections.")
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
