import SwiftUI
struct ContentView: View {
    @ObservedObject var workspace: VocalDiveWorkspace
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var usesCompactNavigation: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    var body: some View {
        Group {
            if usesCompactNavigation {
                iPhoneTabShell
            } else {
                NavigationSplitView {
                    SidebarView(selection: $workspace.selectedSection)
                } detail: {
                    detailView(for: workspace.selectedSection)
                        .navigationTitle(workspace.selectedSection.title)
                }
            }
        }
        .onAppear {
            workspace.usageTracking.switchTo(workspace.selectedSection.usageFeature)
        }
        .onDisappear {
            workspace.usageTracking.closeActiveSession()
        }
        .task {
            await Task.yield()
            workspace.bootstrapIfNeeded()
        }
        .alert(L10n.tr("settings.sync.first_run.title"), isPresented: $workspace.shouldPromptForSyncChoice) {
            Button(L10n.tr("settings.sync.enable")) {
                workspace.completeFirstRunSyncChoice(enableSync: true)
            }
            Button(L10n.tr("settings.sync.not_now"), role: .cancel) {
                workspace.completeFirstRunSyncChoice(enableSync: false)
            }
        } message: {
            Text(L10n.tr("settings.sync.first_run.message"))
        }
    }

    private var iPhoneTabShell: some View {
        TabView(selection: $workspace.selectedSection) {
            NavigationStack {
                detailView(for: .dashboard)
                    .navigationTitle(AppSection.dashboard.title)
            }
            .tabItem {
                Label(AppSection.dashboard.title, systemImage: AppSection.dashboard.systemImage)
            }
            .tag(AppSection.dashboard)

            NavigationStack {
                CompactScoreHubView(workspace: workspace)
                    .navigationTitle(AppSection.scoreWorkspace.title)
            }
            .tabItem {
                Label(AppSection.scoreWorkspace.title, systemImage: AppSection.scoreWorkspace.systemImage)
            }
            .tag(AppSection.scoreWorkspace)

            NavigationStack {
                detailView(for: .practice)
                    .navigationTitle(AppSection.practice.title)
            }
            .tabItem {
                Label(AppSection.practice.title, systemImage: AppSection.practice.systemImage)
            }
            .tag(AppSection.practice)

            NavigationStack {
                detailView(for: .experimentalFeatures)
                    .navigationTitle(AppSection.experimentalFeatures.title)
            }
            .tabItem {
                Label(AppSection.experimentalFeatures.title, systemImage: AppSection.experimentalFeatures.systemImage)
            }
            .tag(AppSection.experimentalFeatures)

            NavigationStack {
                detailView(for: .settings)
                    .navigationTitle(AppSection.settings.title)
            }
            .tabItem {
                Label(AppSection.settings.title, systemImage: AppSection.settings.systemImage)
            }
            .tag(AppSection.settings)
        }
    }

    @ViewBuilder
    private func detailView(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardView(workspace: workspace)
        case .scoreComposer:
            ScoreComposerView(workspace: workspace)
        case .scoreWorkspace:
            ScoreWorkspaceView(workspace: workspace)
        case .practice:
            PracticeView(workspace: workspace)
        case .experimentalFeatures:
            ExperimentalFeaturesView()
        case .settings:
            SupportView(workspace: workspace)
        }
    }
}

private struct CompactScoreHubView: View {
    @ObservedObject var workspace: VocalDiveWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(L10n.tr("Score Mode"), selection: $workspace.compactScoreMode) {
                ForEach(ScoreHubMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            Group {
                switch workspace.compactScoreMode {
                case .editor:
                    ScoreWorkspaceView(workspace: workspace)
                        .onAppear {
                            workspace.scoreLandingMode = .editor
                        }
                case .scan:
                    ScoreWorkspaceView(workspace: workspace)
                        .onAppear {
                            workspace.scoreLandingMode = .scan
                        }
                case .compose:
                    ScoreComposerView(workspace: workspace)
                }
            }
        }
        .onAppear {
            workspace.usageTracking.switchTo(
                workspace.compactScoreMode == .compose ? .scoreComposer : .scoreWorkspace
            )
        }
        .onChange(of: workspace.compactScoreMode) { _, newMode in
            workspace.usageTracking.switchTo(newMode == .compose ? .scoreComposer : .scoreWorkspace)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(workspace: {
            let workspace = VocalDiveWorkspace()
            workspace.loadDemoScore()
            return workspace
        }())
    }
}
