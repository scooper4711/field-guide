import FieldGuideKit
import SwiftUI

extension FocusedValues {
    /// The open entry's navigation path while a followed link can be gone back from.
    @Entry var entryPath: Binding<[PageLink]>?
    /// Whether Search Everything is focused; setting it shows the sidebar with the search ready to type in.
    @Entry var isSearchingEverything: Binding<Bool>?
    /// Whether Art from PDFs shows.
    @Entry var isShowingArtFromPDFs: Binding<Bool>?
}

/// The Mac's menu commands: Art from PDFs in File, and the Go menu.
struct FieldGuideCommands: Commands {
    let store: CatalogStore
    @FocusedValue(\.entryPath) private var entryPath
    @FocusedValue(\.isSearchingEverything) private var isSearchingEverything
    @FocusedValue(\.isShowingArtFromPDFs) private var isShowingArtFromPDFs

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Art from PDFs…") { isShowingArtFromPDFs?.wrappedValue = true }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(isShowingArtFromPDFs == nil)
        }
        CommandMenu("Go") {
            Button("Search Everything") { isSearchingEverything?.wrappedValue = true }
                .keyboardShortcut("f")
                .disabled(isSearchingEverything == nil)
            Button("Back") { entryPath?.wrappedValue.removeLast() }
                .keyboardShortcut("[")
                .disabled(entryPath == nil)
            Divider()
            systemButton(.pathfinder, key: "1")
            systemButton(.starfinder, key: "2")
        }
    }

    private func systemButton(_ system: GameSystem, key: KeyEquivalent) -> some View {
        Toggle(system.title, isOn: Binding(get: { store.system == system }, set: { _ in store.system = system }))
            .keyboardShortcut(key)
    }
}
