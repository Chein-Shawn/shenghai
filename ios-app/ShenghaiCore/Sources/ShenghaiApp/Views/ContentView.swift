import SwiftUI

struct ContentView: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $workspace.selectedSection)
        } detail: {
            detailView
                .navigationTitle(workspace.selectedSection.title)
        }
        .onAppear {
            if workspace.score == nil {
                workspace.loadDemoScore()
            }
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch workspace.selectedSection {
        case .dashboard:
            DashboardView(workspace: workspace)
        case .scoreWorkspace:
            ScoreWorkspaceView(workspace: workspace)
        case .practice:
            PracticeView(workspace: workspace)
        case .researchStatus:
            ResearchStatusView()
        }
    }
}

#Preview {
    ContentView(workspace: {
        let workspace = ShenghaiWorkspace()
        workspace.loadDemoScore()
        return workspace
    }())
}
