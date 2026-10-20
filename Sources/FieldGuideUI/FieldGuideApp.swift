import AppNotices
import BattleCards
import FieldGuideKit
import SwiftUI

/// The app, shared by the iPad and the Mac.
public struct FieldGuideApp: App {
    @State private var store: CatalogStore
    @State private var pdfArt: ArtModel

    public init() {
        let store = CatalogStore()
        _store = State(initialValue: store)
        _pdfArt = State(initialValue: ArtModel.standard(data: store.data))
        Fonts.register(from: store.data.folder)
    }

    public var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(pdfArt)
                .task { await pdfArt.refresh(addingNew: true) }
        }
        .defaultSize(width: 1280, height: 820)
        .commands {
            FieldGuideCommands(store: store)
            #if os(macOS)
            AboutCommands(info: .fieldGuide)
            #endif
        }
    }
}

/// Sidebar of categories under the system switch, the entry list, and the entry.
struct RootView: View {
    @Environment(CatalogStore.self) private var store
    /// `FIELD_GUIDE_SELECT` opens an entry at launch, for trying pages out from a script.
    @State private var selection = ProcessInfo.processInfo.environment["FIELD_GUIDE_SELECT"]
    @State private var columns = NavigationSplitViewVisibility.automatic
    /// The one column an iPhone shows: the categories at launch, so a new user sees them all, or the entry that
    /// `FIELD_GUIDE_SELECT` opens.
    @State private var compactColumn: NavigationSplitViewColumn =
        ProcessInfo.processInfo.environment["FIELD_GUIDE_SELECT"] == nil ? .sidebar : .detail
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    /// The links followed from the chosen entry.
    @State private var path: [PageLink] = []
    @State private var isSearchingEverything = false
    /// Whether Search Everything brought the sidebar out, so opening a match puts it away again.
    @State private var searchShowedSidebar = false
    /// On an iPhone, which shows one column at a time, Search Everything is a sheet instead of the sidebar.
    @State private var isShowingSearchSheet = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            SidebarView(selection: $selection, isSearching: $isSearchingEverything, opened: openedMatch,
                        showList: { compactColumn = .content })
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            EntryListView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
                // The entry column with its button isn't on screen with the list on an iPhone.
                .toolbar {
                    if isCompact {
                        ToolbarItem {
                            Button("Search Everything", systemImage: "magnifyingglass", action: searchEverything)
                        }
                    }
                }
        } detail: {
            Group {
                if let selection {
                    EntryDetailView(rootID: selection, path: $path)
                        .id(selection)
                } else {
                    ContentUnavailableView("Choose an Entry", systemImage: "book",
                                           description: Text(store.errorMessage ?? "Pick something from the list."))
                }
            }
            // The entry's column always shows, whichever other columns are hidden.
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Search Everything", systemImage: "magnifyingglass", action: searchEverything)
                }
            }
        }
        // An entry opened from the search across every category stays open as its category shows.
        .onChange(of: store.category) {
            if !store.results.contains(where: { $0.id == selection }) { selection = nil }
        }
        .onChange(of: store.system) { selection = nil }
        .onChange(of: selection) { path = [] }
        // Only while there is a page to go back to, so the menu sees Back become available.
        .focusedSceneValue(\.entryPath, path.isEmpty ? nil : $path)
        .focusedSceneValue(\.isSearchingEverything, Binding(get: { isSearchingEverything }, set: { isOn in
            if isOn { searchEverything() } else { isSearchingEverything = false }
        }))
        #if os(iOS)
        .sheet(isPresented: $isShowingSearchSheet) {
            SearchEverythingSheet(selection: $selection) { compactColumn = $0 }
                .environment(store)
        }
        #endif
        // The columns get a compact width on the iPad too, so they learn from here whether this is an iPhone.
        .environment(\.showsOneColumn, isCompact)
        // On the Mac, battle cards shown full screen fill this window.
        .battleCardFullScreenHost()
    }

    private var isCompact: Bool {
        #if os(iOS)
        sizeClass == .compact
        #else
        false
        #endif
    }

    /// Shows the sidebar, wherever it was, with its search ready to type in; on an iPhone, the search sheet.
    private func searchEverything() {
        if isCompact {
            isShowingSearchSheet = true
            return
        }
        searchShowedSidebar = columns != .all
        isSearchingEverything = true
        // From the entry alone iOS goes one step, to the list and the entry, so the sidebar is asked for once that
        // step is done.
        guard columns == .detailOnly else {
            columns = .all
            return
        }
        columns = .doubleColumn
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            columns = .all
        }
    }

    private func openedMatch() {
        compactColumn = .detail
        guard searchShowedSidebar else { return }
        columns = .automatic
        searchShowedSidebar = false
    }
}

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
    @State private var isShowingPDFArt = false
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
            Button("Art from PDFs", systemImage: "photo.on.rectangle.angled") { isShowingPDFArt = true }
            // The Mac has About in the app menu.
            #if os(iOS)
            Button("About", systemImage: "info.circle") { isShowingAbout = true }
            #endif
        }
        .focusedSceneValue(\.isShowingArtFromPDFs, $isShowingPDFArt)
        .sheet(isPresented: $isShowingPDFArt) { PDFArtView() }
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

extension EnvironmentValues {
    /// Whether the window shows one column at a time, as on an iPhone. A column's own size class can't tell: it is
    /// compact on the iPad too.
    @Entry var showsOneColumn = false
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
