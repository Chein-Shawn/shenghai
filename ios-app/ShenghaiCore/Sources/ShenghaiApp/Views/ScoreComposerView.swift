import SwiftUI
#if canImport(ShenghaiCore)
import ShenghaiCore
#endif

struct ScoreComposerView: View {
    @Bindable var workspace: ShenghaiWorkspace
    @State private var draft = ComposedScore()
    @State private var selectedStep: ComposedPitchStep = .C
    @State private var selectedAlter = 0
    @State private var selectedOctave = 4
    @State private var selectedValue: ComposedNoteValue = .quarter
    @State private var addRest = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 96), spacing: 8)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HeaderBand(
                    title: "Compose",
                    subtitle: "Create a simple MusicXML score, then load it into practice.",
                    systemImage: "square.and.pencil"
                )

                StatusStrip(workspace: workspace)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 14)], spacing: 14) {
                    scoreSettingsPanel
                    noteInputPanel
                }

                sequencePanel
            }
            .padding(20)
        }
    }

    private var scoreSettingsPanel: some View {
        StudioPanel(title: "Score Settings", systemImage: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $draft.title)
                    .textFieldStyle(.roundedBorder)

                TextField("Part name", text: $draft.partName)
                    .textFieldStyle(.roundedBorder)

                Stepper(value: $draft.tempoBPM, in: 40...220, step: 1) {
                    Label("\(draft.tempoBPM) BPM", systemImage: "metronome")
                }

                HStack(spacing: 10) {
                    Picker("Beats", selection: $draft.beats) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                        Text("6").tag(6)
                    }
                    .pickerStyle(.segmented)

                    Picker("Beat Type", selection: $draft.beatType) {
                        Text("4").tag(4)
                        Text("8").tag(8)
                    }
                    .pickerStyle(.segmented)
                }

                actionRow
            }
        }
    }

    private var noteInputPanel: some View {
        StudioPanel(title: "Note Entry", systemImage: "music.quarternote.3") {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: $addRest) {
                    Label("Rest", systemImage: "pause")
                }
                .toggleStyle(.switch)

                Picker("Pitch", selection: $selectedStep) {
                    ForEach(ComposedPitchStep.allCases, id: \.self) { step in
                        Text(step.rawValue).tag(step)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(addRest)

                Picker("Accidental", selection: $selectedAlter) {
                    Text("b").tag(-1)
                    Text("natural").tag(0)
                    Text("#").tag(1)
                }
                .pickerStyle(.segmented)
                .disabled(addRest)

                Stepper(value: $selectedOctave, in: 2...6, step: 1) {
                    Label("Octave \(selectedOctave)", systemImage: "arrow.up.and.down")
                }
                .disabled(addRest)

                Picker("Value", selection: $selectedValue) {
                    ForEach(ComposedNoteValue.allCases) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .pickerStyle(.segmented)

                Button {
                    appendSelectedNote()
                } label: {
                    Label(addRest ? "Add Rest" : "Add Note", systemImage: addRest ? "plus.circle" : "music.note")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var sequencePanel: some View {
        StudioPanel(title: "Score Sequence", systemImage: "rectangle.stack") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    ValuePill(title: "Events", value: "\(draft.notes.count)", systemImage: "number")
                    ValuePill(title: "Measures", value: "\(estimatedMeasureCount)", systemImage: "music.note.list")
                    ValuePill(title: "Duration", value: durationLabel, systemImage: "timer")
                    Spacer()
                }

                if draft.notes.isEmpty {
                    ContentUnavailableView(
                        "No notes yet",
                        systemImage: "music.note",
                        description: Text("Use Note Entry to create the first MusicXML draft.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                } else {
                    LazyVGrid(columns: gridColumns, alignment: .leading, spacing: 8) {
                        ForEach(Array(draft.notes.enumerated()), id: \.element.id) { index, note in
                            NoteToken(index: index + 1, note: note)
                        }
                    }
                }
            }
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            ToolIconButton(title: "Undo", systemImage: "arrow.uturn.backward") {
                if !draft.notes.isEmpty {
                    draft.notes.removeLast()
                    workspace.statusMessage = "Removed last composed event."
                }
            }
            .disabled(draft.notes.isEmpty)

            ToolIconButton(title: "Clear", systemImage: "trash") {
                draft.notes.removeAll()
                workspace.statusMessage = "Cleared composition draft."
            }
            .disabled(draft.notes.isEmpty)

            ToolIconButton(title: "Load Score", systemImage: "square.and.arrow.down", isProminent: true) {
                workspace.loadComposedScore(draft)
            }
            .disabled(draft.notes.isEmpty)

            ToolIconButton(title: "Export MusicXML", systemImage: "square.and.arrow.up") {
                workspace.exportMusicXML(draft)
            }
            .disabled(draft.notes.isEmpty)

            if let exportedMusicXMLURL = workspace.exportedMusicXMLURL {
                ShareLink(item: exportedMusicXMLURL) {
                    Label("Share MusicXML", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .help("Share MusicXML")
            }
        }
    }

    private var estimatedMeasureCount: Int {
        let capacity = max(1, draft.beats * MusicXMLComposer.divisions * 4 / max(draft.beatType, 1))
        let totalUnits = draft.notes.reduce(0) { $0 + $1.value.durationUnits }
        return max(1, Int(ceil(Double(totalUnits) / Double(capacity))))
    }

    private var durationLabel: String {
        let quarterUnits = Double(draft.notes.reduce(0) { $0 + $1.value.durationUnits }) / Double(MusicXMLComposer.divisions)
        let seconds = quarterUnits * 60.0 / Double(max(draft.tempoBPM, 1))
        return String(format: "%.1fs", seconds)
    }

    private func appendSelectedNote() {
        let pitch = addRest ? nil : ComposedPitch(
            step: selectedStep,
            alter: selectedAlter,
            octave: selectedOctave
        )
        draft.notes.append(ComposedScoreNote(pitch: pitch, value: selectedValue))
        workspace.statusMessage = addRest ? "Added rest." : "Added \(pitch?.displayName ?? "note")."
        workspace.errorMessage = nil
    }
}

private struct NoteToken: View {
    var index: Int
    var note: ComposedScoreNote

    var body: some View {
        HStack(spacing: 8) {
            Text("\(index)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.quaternary.opacity(0.4), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(note.isRest ? "Rest" : note.pitch?.displayName ?? "Note")
                    .font(.headline)
                    .lineLimit(1)
                Text(note.value.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .frame(minHeight: 54)
        .padding(.horizontal, 10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    ScoreComposerView(workspace: {
        let workspace = ShenghaiWorkspace()
        workspace.loadDemoScore()
        return workspace
    }())
}
