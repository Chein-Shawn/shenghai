import SwiftUI

struct DashboardView: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Alpha 0",
                    subtitle: "Scan, correct, and practice from editable MusicXML",
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
                    PipelineRow(title: "MusicXML composer", state: .ready)
                    PipelineRow(title: "MusicXML import", state: .ready)
                    PipelineRow(title: "PDF/image -> editable MusicXML review", state: .ready, detail: "Main workflow gate: check scanned notes, lyrics, directions, repeats, and layout before practice.")
                    PipelineRow(title: "ScoreDocument wrapper", state: .ready)
                    PipelineRow(title: "MIDI event timeline", state: .ready)
                    PipelineRow(title: "MIDI playback/export", state: .ready)
                    PipelineRow(title: "Experimental Singing Support Lab", state: .ready, detail: "Non-medical research prototype with safety guardrails.")
                    PipelineRow(title: "Experimental Sing-to-Dismiss Alarm", state: .planned, detail: "Full-song in-app challenge model exists; OS-level alarm behavior depends on platform APIs.")
                    PipelineRow(title: "Experimental Text Rhythm Speech Lab", state: .planned, detail: "Paragraph rhythm guide and speech-practice scoring model exists.")
                    PipelineRow(title: "External OMR engine execution", state: .planned, detail: "homr/oemer/Audiveris execution still runs outside the Apple app, then imports MusicXML.")
                    PipelineRow(title: "Real microphone pitch tracking", state: .planned, detail: "Core deviation model exists; live tracker is next.")
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
        .toolbar {
            Button {
                workspace.selectedSection = .scoreComposer
            } label: {
                Label("Compose", systemImage: "square.and.pencil")
            }

            Button {
                workspace.selectedSection = .scoreWorkspace
            } label: {
                Label("Open Score", systemImage: "music.note.list")
            }
        }
    }
}
