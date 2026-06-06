import SwiftUI
import UniformTypeIdentifiers
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ScoreWorkspaceView: View {
    @Bindable var workspace: ShenghaiWorkspace

    private var musicXMLTypes: [UTType] {
        [.xml, UTType(filenameExtension: "musicxml")].compactMap { $0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreToolbar(workspace: workspace)
            Divider()

            if let score = workspace.score {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ScoreSummaryView(workspace: workspace)

                        if score.parts.count > 1 {
                            Picker("Part", selection: $workspace.selectedPartID) {
                                ForEach(score.parts) { part in
                                    Text(part.name).tag(Optional(part.id))
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if let part = workspace.selectedPart {
                            MeasuresView(score: score, part: part)
                        }
                    }
                    .padding()
                    .frame(maxWidth: 1080, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    "No Score Loaded",
                    systemImage: "music.note.list",
                    description: Text("Import a MusicXML file or load the built-in demo.")
                )
            }
        }
        .fileImporter(
            isPresented: $workspace.isImportingScore,
            allowedContentTypes: musicXMLTypes,
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else {
                return
            }
            workspace.importMusicXML(url: url)
        }
    }
}

private struct ScoreToolbar: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        HStack(spacing: 12) {
            Button {
                workspace.isImportingScore = true
            } label: {
                Label("Import", systemImage: "square.and.arrow.down")
            }

            Button {
                workspace.loadDemoScore()
            } label: {
                Label("Demo", systemImage: "sparkles")
            }

            Button {
                workspace.playOrStop()
            } label: {
                Label(workspace.isPlaying ? "Stop" : "Play", systemImage: workspace.isPlaying ? "stop.fill" : "play.fill")
            }
            .disabled(workspace.score == nil)

            Button {
                workspace.exportMIDI()
            } label: {
                Label("MIDI", systemImage: "square.and.arrow.up")
            }
            .disabled(workspace.score == nil)

            if let exportedMIDIURL = workspace.exportedMIDIURL {
                ShareLink(item: exportedMIDIURL) {
                    Label("Share", systemImage: "arrowshape.turn.up.right")
                }
            }

            Spacer()
        }
        .buttonStyle(.bordered)
        .padding()
    }
}

private struct ScoreSummaryView: View {
    @Bindable var workspace: ShenghaiWorkspace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(workspace.scoreSummary.title)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                MetricTile(title: "Measures", value: "\(workspace.scoreSummary.measureCount)", systemImage: "rectangle.split.3x1")
                MetricTile(title: "Notes", value: "\(workspace.scoreSummary.noteCount)", systemImage: "music.note")
                MetricTile(title: "Playable", value: "\(workspace.scoreSummary.playableNoteCount)", systemImage: "play.circle")
                MetricTile(title: "Ticks", value: "\(workspace.scoreSummary.durationTicks)", systemImage: "metronome")
            }
        }
    }
}

private struct MeasuresView: View {
    var score: ScoreDocument
    var part: ScorePart

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Measures")

            ForEach(part.measures) { measure in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Measure \(measure.number)")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(measure.notes) { note in
                            NoteToken(note: note, ticksPerQuarter: score.ticksPerQuarter)
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct NoteToken: View {
    var note: ScoreNote
    var ticksPerQuarter: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ScoreFormatting.noteName(note))
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(ScoreFormatting.durationLabel(ticks: note.durationTick, ticksPerQuarter: ticksPerQuarter))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}
