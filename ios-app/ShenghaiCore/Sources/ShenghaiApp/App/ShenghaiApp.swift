import SwiftUI

@main
struct ShenghaiApp: App {
    @State private var workspace = ShenghaiWorkspace()

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Load Demo Score") {
                    workspace.loadDemoScore()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button("Export MIDI") {
                    workspace.exportMIDI()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(workspace.score == nil)
            }
        }
    }
}
