import SwiftUI
struct ContentView: View {
    @ObservedObject var workspace: ShenghaiWorkspace

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $workspace.selectedSection)
        } detail: {
            detailView
                .navigationTitle(workspace.selectedSection.title)
        }
        .onAppear {
            workspace.usageTracking.switchTo(workspace.selectedSection.usageFeature)
            if workspace.score == nil {
                workspace.loadDemoScore()
            }
        }
        .onDisappear {
            workspace.usageTracking.closeActiveSession()
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch workspace.selectedSection {
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
        case .researchStatus:
            ResearchStatusView()
        case .support:
            SupportView(workspace: workspace)
        case .usageStats:
            UsageStatsView(usageTracking: workspace.usageTracking)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(workspace: {
            let workspace = ShenghaiWorkspace()
            workspace.loadDemoScore()
            return workspace
        }())
    }
}
