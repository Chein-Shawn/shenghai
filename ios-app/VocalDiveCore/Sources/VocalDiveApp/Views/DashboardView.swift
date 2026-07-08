import SwiftUI

struct DashboardView: View {
    @ObservedObject var workspace: VocalDiveWorkspace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: L10n.tr("Alpha 0"),
                    subtitle: L10n.tr("Scan, correct, and practice from editable MusicXML"),
                    systemImage: "music.quarternote.3"
                )

                StatusStrip(workspace: workspace)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    MetricTile(title: L10n.tr("Parts"), value: "\(workspace.scoreSummary.partCount)", systemImage: "person.2")
                    MetricTile(title: L10n.tr("Measures"), value: "\(workspace.scoreSummary.measureCount)", systemImage: "rectangle.split.3x1")
                    MetricTile(title: L10n.tr("Playable Notes"), value: "\(workspace.scoreSummary.playableNoteCount)", systemImage: "pianokeys")
                    MetricTile(title: L10n.tr("Timeline"), value: L10n.tr("%d ticks", workspace.scoreSummary.durationTicks), systemImage: "timeline.selection")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(L10n.tr("Feature Overview"))
                    PipelineRow(title: L10n.tr("MusicXML composer"), state: .ready)
                    PipelineRow(title: L10n.tr("MusicXML import"), state: .ready)
                    PipelineRow(title: L10n.tr("PDF/image -> editable MusicXML review"), state: .ready, detail: L10n.tr("Main workflow gate: check scanned notes, lyrics, directions, repeats, and layout before practice."))
                    PipelineRow(title: L10n.tr("ScoreDocument wrapper"), state: .ready)
                    PipelineRow(title: L10n.tr("MIDI event timeline"), state: .ready)
                    PipelineRow(title: L10n.tr("MIDI playback/export"), state: .ready)
                    PipelineRow(title: L10n.tr("Experimental Sing-to-Dismiss Alarm"), state: .planned, detail: L10n.tr("Full-song in-app challenge model exists; OS-level alarm behavior depends on platform APIs."))
                    PipelineRow(title: L10n.tr("Experimental Text Rhythm Speech Lab"), state: .planned, detail: L10n.tr("Paragraph rhythm guide and speech-practice scoring model exists."))
                    PipelineRow(title: L10n.tr("External OMR engine execution"), state: .planned, detail: L10n.tr("homr/oemer/Audiveris execution still runs outside the Apple app, then imports MusicXML."))
                    PipelineRow(title: L10n.tr("Real microphone pitch tracking"), state: .planned, detail: L10n.tr("Core deviation model exists; live tracker is next."))
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
        .toolbar {
            Button {
                workspace.selectedSection = .scoreComposer
            } label: {
                Label(L10n.tr("Compose"), systemImage: "square.and.pencil")
            }

            Button {
                workspace.selectedSection = .scoreWorkspace
            } label: {
                Label(L10n.tr("Open Score"), systemImage: "music.note.list")
            }
        }
    }
}
