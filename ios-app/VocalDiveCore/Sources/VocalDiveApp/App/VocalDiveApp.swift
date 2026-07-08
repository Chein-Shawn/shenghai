import SwiftUI

@main
struct VocalDiveApp: App {
    @StateObject private var workspace = VocalDiveWorkspace()
    @StateObject private var appSettings = AppSettingsStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView(workspace: workspace)
                .environmentObject(appSettings)
                .environment(\.layoutDirection, appSettings.selectedLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
                .id(appSettings.selectedLanguage.rawValue)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button(L10n.tr("Load Demo Score")) {
                    workspace.loadDemoScore()
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])

                Button(L10n.tr("Export MIDI")) {
                    workspace.exportMIDI()
                }
                .keyboardShortcut("e", modifiers: [.command])
                .disabled(workspace.score == nil)
            }
        }
    }
}
