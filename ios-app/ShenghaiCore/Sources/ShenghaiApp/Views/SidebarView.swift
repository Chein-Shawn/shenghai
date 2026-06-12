import SwiftUI

struct SidebarView: View {
    @Binding var selection: AppSection

    var body: some View {
        #if os(macOS)
        List(AppSection.allCases, selection: $selection) { section in
            Label(section.title, systemImage: section.systemImage)
                .tag(section)
        }
        .navigationTitle(L10n.tr("Shenghai"))
        .listStyle(.sidebar)
        #else
        List(AppSection.allCases) { section in
            Button {
                selection = section
            } label: {
                Label(section.title, systemImage: section.systemImage)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .foregroundStyle(selection == section ? Color.accentColor : Color.primary)
        }
        .navigationTitle(L10n.tr("Shenghai"))
        #endif
    }
}
