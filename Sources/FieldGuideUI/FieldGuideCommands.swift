import FieldGuideKit
import SwiftUI

extension FocusedValues {
    /// The open entry's navigation path while a followed link can be gone back from.
    @Entry var entryPath: Binding<[PageLink]>?
    /// Whether Search Everything is focused; setting it shows the sidebar with the search ready to type in.
    @Entry var isSearchingEverything: Binding<Bool>?
    /// Whether Sourcebooks shows.
    @Entry var isShowingSourcebooks: Binding<Bool>?
}

/// The Mac's menu commands: Sourcebooks in File, and the Go menu.
struct FieldGuideCommands: Commands {
    // A literal URL that is known to parse.
    // swiftlint:disable:next force_unwrapping
    private static let privacyPolicy = URL(string: "https://github.com/scooper4711/field-guide/blob/main/PRIVACY.md")!

    let store: CatalogStore
    @FocusedValue(\.entryPath) private var entryPath
    @FocusedValue(\.isSearchingEverything) private var isSearchingEverything
    @FocusedValue(\.isShowingSourcebooks) private var isShowingSourcebooks

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Sourcebooks…") { isShowingSourcebooks?.wrappedValue = true }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(isShowingSourcebooks == nil)
        }
        CommandGroup(after: .help) {
            Link("Field Guide Privacy Policy", destination: Self.privacyPolicy)
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
