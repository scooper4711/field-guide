import FieldGuideKit
import SwiftUI

/// The current category's entries: search, filters, sort and the matching count.
struct EntryListView: View {
    @Environment(CatalogStore.self) private var store
    @Binding var selection: String?
    @State private var showsFilters = false

    var body: some View {
        @Bindable var store = store
        List(store.results, selection: $selection) { entry in
            EntryRow(entry: entry, images: store.data.images).tag(entry.id)
        }
        .listStyle(.plain)
        .searchable(text: $store.query.text, prompt: store.query.searchesText ? "Search text" : "Search names")
        .navigationTitle(store.category?.title ?? "")
        .toolbar { toolbar }
        .safeAreaInset(edge: .bottom) { countBar }
        .sheet(isPresented: $showsFilters) {
            FilterView()
                .environment(store)
        }
        .overlay {
            if store.results.isEmpty, !store.entries.isEmpty {
                ContentUnavailableView.search
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var store = store
        ToolbarItem(placement: .navigation) {
            // The sidebar is hidden in portrait, so the system switch is here too.
            Picker("System", selection: $store.system) {
                ForEach(GameSystem.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.menu)
        }
        ToolbarItemGroup {
            Menu {
                Toggle("Search Text Too", isOn: $store.query.searchesText)
                if store.category?.hasLevels == true {
                    Picker("Sort", selection: $store.query.sort) {
                        Text("By Name").tag(EntryQuery.Sort.name)
                        Text("By Level").tag(EntryQuery.Sort.level)
                    }
                }
            } label: {
                Label("Options", systemImage: "arrow.up.arrow.down")
            }
            Button {
                showsFilters = true
            } label: {
                Label("Filters", systemImage: store.query.isFiltered
                      ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var countBar: some View {
        HStack {
            Text("\(store.results.count.formatted()) of \(store.entries.count.formatted())")
            Spacer()
            if store.query.isFiltered {
                Button("Clear Filters") { store.query = EntryQuery() }
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

/// One entry in the list: its image, name and subtitle.
struct EntryRow: View {
    let entry: EntrySummary
    let images: URL

    var body: some View {
        HStack(spacing: 10) {
            Thumbnail(path: entry.image, images: images, placeholder: entry.category.symbol)
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name).font(.body)
                Text(entry.subtitle).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// A stored image, or a symbol when there is none.
struct Thumbnail: View {
    let path: String
    let images: URL
    let placeholder: String

    var body: some View {
        if let image = ImageCache.shared.image(at: images.appendingPathComponent(path), isEmpty: path.isEmpty) {
            image.resizable().scaledToFit()
        } else {
            Image(systemName: placeholder)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
