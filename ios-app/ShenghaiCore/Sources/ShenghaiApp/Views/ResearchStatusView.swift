import SwiftUI

struct ResearchStatusView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HeaderBand(
                    title: "Research Map",
                    subtitle: "Algorithm decisions feeding the MVP",
                    systemImage: "book.pages"
                )

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Product Algorithms")
                    ResearchRow(topic: "OMR", decision: "Use Audiveris and MusicXML as the baseline path.")
                    ResearchRow(topic: "OMR Pipeline", decision: "Track capture, preprocessing, recognition, MusicXML export, correction, and playback validation as explicit stages.")
                    ResearchRow(topic: "Internal Format", decision: "Wrap imported scores in Shenghai ScoreDocument for corrections, repeats, sync points, and practice logs.")
                    ResearchRow(topic: "Pitch Feedback", decision: "Use a YIN baseline for live monophonic pitch, smooth contours, and keep CREPE/pYIN as replaceable higher-accuracy trackers.")
                    ResearchRow(topic: "Playback", decision: "Generate MIDI events first; move to AVAudioEngine sampler when richer practice controls are needed.")
                    ResearchRow(topic: "Source Separation", decision: "Treat Moises-like stem controls as post-MVP research unless a simple API/prototype is available.")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Current Blockers")
                    PipelineRow(title: "Audiveris app install", state: .blocked, detail: "Install official macOS release or use JDK 25 for source build.")
                    PipelineRow(title: "TestFlight signing", state: .blocked, detail: "Needs Apple Developer Program and App Store Connect setup.")
                    PipelineRow(title: "Live pitch capture", state: .planned, detail: "Requires microphone permission and input calibration.")
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
