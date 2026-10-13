import FieldGuideKit
import SwiftUI

/// The matches of the search across every category, grouped by category: a match opens its entry, Show All its
/// category's list searched the same way.
struct GlobalSearchResults: View {
    @Environment(CatalogStore.self) private var store
    @Binding var selection: String?
    let opened: () -> Void

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                Toggle("Search Text Too", isOn: $store.globalQuery.searchesText)
            }
            ForEach(store.globalResults) { group in
                Section(group.category.title) {
                    ForEach(group.entries) { entry in
                        Button { open(entry) } label: {
                            EntryRow(entry: entry, images: store.data.images)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if group.total > group.entries.count {
                        Button("Show All \(group.total.formatted())") { showAll(group.category) }
                    }
                }
            }
        }
        .overlay {
            if store.globalResults.isEmpty { ContentUnavailableView.search(text: store.globalQuery.text) }
        }
    }

    private func open(_ entry: EntrySummary) {
        store.category = entry.category
        selection = entry.id
        opened()
    }

    /// The category's list with the same search, and the sidebar back to the categories.
    private func showAll(_ category: EntryCategory) {
        let search = store.globalQuery
        store.category = category
        store.query = EntryQuery(text: search.text, searchesText: search.searchesText)
        store.globalQuery.text = ""
    }
}
