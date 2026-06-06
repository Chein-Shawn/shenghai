import SwiftUI

struct DashboardView: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Alpha 0",
                    subtitle: "MusicXML practice pipeline",
                    systemImage: "music.quarternote.3"
                )

                StatusStrip(workspace: workspace)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricTile(title: "Parts", value: "\(workspace.scoreSummary.partCount)", systemImage: "person.2")
                    MetricTile(title: "Measures", value: "\(workspace.scoreSummary.measureCount)", systemImage: "rectangle.split.3x1")
                    MetricTile(title: "Playable Notes", value: "\(workspace.scoreSummary.playableNoteCount)", systemImage: "pianokeys")
                    MetricTile(title: "Timeline", value: "\(workspace.scoreSummary.durationTicks) ticks", systemImage: "timeline.selection")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("MVP Chain")
                    PipelineRow(title: "MusicXML import", state: .ready)
                    PipelineRow(title: "ScoreDocument wrapper", state: .ready)
                    PipelineRow(title: "MIDI event timeline", state: .ready)
                    PipelineRow(title: "MIDI playback/export", state: .ready)
                    PipelineRow(title: "PDF/image OMR", state: .blocked, detail: "Waiting for Audiveris release install or JDK 25.")
                    PipelineRow(title: "Real microphone pitch tracking", state: .planned, detail: "Core deviation model exists; live tracker is next.")
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
        .toolbar {
            Button {
                workspace.selectedSection = .scoreWorkspace
            } label: {
                Label("Open Score", systemImage: "music.note.list")
            }
        }
    }
}
