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
        #if os(macOS)
        .commands { AboutCommands(info: .fieldGuide) }
        #endif
    }
}

/// Sidebar of categories under the system switch, the entry list, and the entry.
struct RootView: View {
    @Environment(CatalogStore.self) private var store
    /// `FIELD_GUIDE_SELECT` opens an entry at launch, for trying pages out from a script.
    @State private var selection = ProcessInfo.processInfo.environment["FIELD_GUIDE_SELECT"]
    @State private var columns = NavigationSplitViewVisibility.automatic
    @State private var isSearchingEverything = false
    /// Whether Search Everything brought the sidebar out, so opening a match puts it away again.
    @State private var searchShowedSidebar = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView(selection: $selection, isSearching: $isSearchingEverything, opened: openedMatch)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            EntryListView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            Group {
                if let selection {
                    EntryDetailView(rootID: selection)
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
        // On the Mac, battle cards shown full screen fill this window.
        .battleCardFullScreenHost()
    }

    /// Shows the sidebar, wherever it was, with its search ready to type in.
    private func searchEverything() {
        searchShowedSidebar = columns != .all
        columns = .all
        isSearchingEverything = true
    }

    private func openedMatch() {
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
    @State private var isShowingPDFArt = false
    @State private var isShowingAbout = false

    var body: some View {
        @Bindable var store = store
        Group {
            if store.globalQuery.text.isEmpty {
                categories
            } else {
                GlobalSearchResults(selection: $selection, opened: opened)
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
        .sheet(isPresented: $isShowingPDFArt) { PDFArtView() }
        .sheet(isPresented: $isShowingAbout) { AboutSheet(info: .fieldGuide) }
    }

    private var categories: some View {
        @Bindable var store = store
        return List(selection: $store.category) {
            Section {
                ForEach(store.categories) { category in
                    Label(category.title, systemImage: category.symbol).tag(category)
                }
            } header: {
                Picker("System", selection: $store.system) {
                    ForEach(GameSystem.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.bottom, 8)
            }
        }
    }
}
