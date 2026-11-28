import AppNotices
import FieldGuideKit
import SwiftUI

/// The categories under the system switch, or, while searching everything, the matches.
struct SidebarView: View {
    @Environment(CatalogStore.self) private var store
    @Binding var selection: String?
    @Binding var isSearching: Bool
    /// Called when a match of the search is opened.
    let opened: () -> Void
    /// Called when a category's list is to be shown: on an iPhone, the next screen.
    let showList: () -> Void
    @Environment(\.showsOneColumn) private var showsOneColumn
    @State private var isShowingSourcebooks = false
    @State private var isShowingAbout = false

    var body: some View {
        @Bindable var store = store
        Group {
            if store.globalQuery.text.isEmpty {
                categories
            } else {
                GlobalSearchResults(selection: $selection, opened: opened, showedAll: showList)
            }
        }
        .searchable(text: $store.globalQuery.text, isPresented: $isSearching, placement: .sidebar,
                    prompt: "Search Everything")
        .navigationTitle("Field Guide")
        .toolbar {
            Button("Sourcebooks", systemImage: "books.vertical") { isShowingSourcebooks = true }
            // The Mac has About in the app menu.
            #if os(iOS)
            Button("About", systemImage: "info.circle") { isShowingAbout = true }
            #endif
        }
        .focusedSceneValue(\.isShowingSourcebooks, $isShowingSourcebooks)
        .sheet(isPresented: $isShowingSourcebooks) { SourcebooksView() }
        .sheet(isPresented: $isShowingAbout) { AboutSheet(info: .fieldGuide) }
    }

    private var categories: some View {
        @Bindable var store = store
        #if os(macOS)
        // Not a section header: on the Mac a sidebar's header makes room for its Hide button while the pointer is
        // over it, which resized the picker's segments.
        return List(selection: $store.category) { categoryRows }
            .safeAreaInset(edge: .top) {
                systemPicker
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        #else
        // On an iPhone a selected row would open its list by itself, also when switching systems chooses a
        // category, so the rows are buttons there.
        return List(selection: showsOneColumn ? nil : $store.category) {
            Section { categoryRows } header: { systemPicker.padding(.bottom, 8) }
        }
        #endif
    }

    private var categoryRows: some View {
        ForEach(store.categories) { category in
            if showsOneColumn {
                Button { open(category) } label: { CategoryButtonLabel(category: category) }
                    .tint(.primary)
            } else {
                Label(category.title, systemImage: category.symbol).tag(category)
            }
        }
    }

    private func open(_ category: EntryCategory) {
        store.category = category
        showList()
    }

    private var systemPicker: some View {
        @Bindable var store = store
        return Picker("System", selection: $store.system) {
            ForEach(GameSystem.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }
}

/// A category on an iPhone's categories screen, with the chevron of a row that opens the next screen.
private struct CategoryButtonLabel: View {
    let category: EntryCategory

    var body: some View {
        HStack {
            Label(category.title, systemImage: category.symbol)
            Spacer()
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
