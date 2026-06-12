import SwiftUI

struct ResearchStatusView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: L10n.tr("Research Map"),
                    subtitle: L10n.tr("Algorithm decisions feeding the MVP"),
                    systemImage: "book.pages"
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(L10n.tr("Product Algorithms"))
                    ResearchRow(topic: "OMR", decision: L10n.tr("Let users choose homr or oemer as external MusicXML-producing providers; keep Audiveris as a benchmark path."))
                    ResearchRow(topic: "OMR Pipeline", decision: L10n.tr("Track capture, preprocessing, recognition, MusicXML export, correction, and playback validation as explicit stages."))
                    ResearchRow(topic: L10n.tr("Internal Format"), decision: L10n.tr("Wrap imported scores in Shenghai ScoreDocument for corrections, repeats, sync points, and practice logs."))
                    ResearchRow(topic: L10n.tr("Pitch Feedback"), decision: L10n.tr("Use a YIN baseline for live monophonic pitch, smooth contours, and keep CREPE/pYIN as replaceable higher-accuracy trackers."))
                    ResearchRow(topic: L10n.tr("Playback"), decision: L10n.tr("Generate MIDI events first; move to AVAudioEngine sampler when richer practice controls are needed."))
                    ResearchRow(topic: L10n.tr("Source Separation"), decision: L10n.tr("Treat Moises-like stem controls as post-MVP research unless a simple API/prototype is available."))
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle(L10n.tr("Current Blockers"))
                    PipelineRow(title: L10n.tr("External OMR provider execution"), state: .planned, detail: L10n.tr("homr/oemer are selected in-app but run in a reviewed external environment for now."))
                    PipelineRow(title: L10n.tr("Audiveris app install"), state: .blocked, detail: L10n.tr("Install official macOS release or use JDK 25 for source build."))
                    PipelineRow(title: L10n.tr("TestFlight signing"), state: .blocked, detail: L10n.tr("Needs Apple Developer Program and App Store Connect setup."))
                    PipelineRow(title: L10n.tr("Live pitch capture"), state: .planned, detail: L10n.tr("Requires microphone permission and input calibration."))
                }
            }
            .padding()
            .frame(maxWidth: 980, alignment: .leading)
        }
    }
}

private struct ResearchRow: View {
    var topic: String
    var decision: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(topic)
                .font(.headline)
                .frame(width: 140, alignment: .leading)
            Text(decision)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(12)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}
