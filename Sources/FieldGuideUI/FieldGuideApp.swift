import AppNotices
import BattleCards
import FieldGuideKit
import SwiftUI

/// The app, shared by the iPad and the Mac.
public struct FieldGuideApp: App {
    @State private var store: CatalogStore
    @State private var pdfArt: ArtModel
    @State private var sourcebooks = SourcebookModel.standard()
    @State private var scrollkeeper = ScrollkeeperLink.standard()
    @Environment(\.scenePhase) private var scenePhase

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
                .environment(sourcebooks)
                .environment(scrollkeeper)
                .task {
                    store.addedEntries = pdfArt.customCreatures
                    pdfArt.startFollowingSharedLibrary()
                    pdfArt.startCloudSync()
                    await pdfArt.refresh(addingNew: true)
                    await sourcebooks.refresh(addingNew: true, subjects: store.loreSubjects())
                    await sourcebooks.startSync()
                }
                .onChange(of: pdfArt.customCreatures) { _, custom in store.addedEntries = custom }
                .onOpenURL(perform: open)
                // What Scrollkeeper hands over goes to the open window rather than opening another.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .defaultSize(width: 1280, height: 820)
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { Task { await pdfArt.closeSharedLibrary() } }
            if phase == .active { pdfArt.resumeSharedLibrary() }
        }
        .handlesExternalEvents(matching: ["*"])
        .commands {
            FieldGuideCommands(store: store)
            AboutCommands(info: .fieldGuide)
        }
        #if os(iOS)
        AboutWindow(info: .fieldGuide)
        #endif
    }
}

extension FieldGuideApp {
    /// Takes what Scrollkeeper hands over: its list of the user's titles, the PDFs of a title the user asked for,
    /// which are read for art and lore, and links saying how a request is going.
    private func open(_ url: URL) {
        guard url.isFileURL else {
            scrollkeeper.receiveStatus(url)
            return
        }
        if url.pathExtension == ScrollkeeperLink.indexExtension {
            scrollkeeper.receiveIndex(url)
        } else if url.pathExtension.lowercased() == "pdf" {
            // Side by side, so a PDF that takes long to search for art doesn't hold up its lore.
            let subjects = store.loreSubjects()
            Task { await pdfArt.addFiles([url]) }
            Task { await sourcebooks.addFiles([url], subjects: subjects) }
        }
    }
}

/// Sidebar of categories under the system switch, the entry list, and the entry.
struct RootView: View {
    /// `FIELD_GUIDE_SELECT` opens an entry at launch, for trying pages out from a script.
    private static let launchSelection = ProcessInfo.processInfo.environment["FIELD_GUIDE_SELECT"]
    @Environment(CatalogStore.self) private var store
    @State private var navigator = EntryNavigator(selection: launchSelection)
    @State private var columns = ColumnChoice(selection: launchSelection)
    /// The one column an iPhone shows: the categories at launch, so a new user sees them all, or the entry that
    /// `FIELD_GUIDE_SELECT` opens.
    @State private var compactColumn: NavigationSplitViewColumn = launchSelection == nil ? .sidebar : .detail
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif
    @State private var isSearchingEverything = false
    /// Whether Search Everything brought the sidebar out, so opening a match puts it away again.
    @State private var searchShowedSidebar = false
    /// On an iPhone, which shows one column at a time, Search Everything is a sheet instead of the sidebar.
    @State private var isShowingSearchSheet = false

    var body: some View {
        @Bindable var navigator = navigator
        return NavigationSplitView(columnVisibility: $columns.visibility, preferredCompactColumn: $compactColumn) {
            SidebarView(selection: $navigator.selection, isSearching: $isSearchingEverything, opened: openedMatch,
                        showList: { compactColumn = .content })
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            EntryListView(selection: $navigator.selection)
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
                if let selection = navigator.selection {
                    EntryDetailView(rootID: selection, root: navigator.root, path: $navigator.path,
                                    back: navigator.history.isEmpty ? nil : { navigator.goBack(in: store) })
                        .id("\(selection) \(navigator.root.map { "\($0)" } ?? "")")
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
                ToolbarItem(placement: .status) {
                    ReadingStatus()
                }
            }
        }
        .reapplyingStartingVisibility($columns)
        // An entry opened from the search across every category stays open as its category shows.
        .onChange(of: store.category) {
            if !store.results.contains(where: { $0.id == navigator.selection }) { navigator.selection = nil }
        }
        .onChange(of: store.system) {
            navigator.selection = nil
            navigator.forget()
        }
        .onChange(of: navigator.selection) { columns.selectionChanged(to: navigator.selection) }
        .environment(\.openEntry, OpenEntryAction(open: open))
        // Only while there is a page to go back to, so the menu sees Back become available.
        .focusedSceneValue(\.goBack, navigator.canGoBack ? BackAction { navigator.goBack(in: store) } : nil)
        .focusedSceneValue(\.isSearchingEverything, Binding(get: { isSearchingEverything }, set: { isOn in
            if isOn { searchEverything() } else { isSearchingEverything = false }
        }))
        #if os(iOS)
        .sheet(isPresented: $isShowingSearchSheet) {
            SearchEverythingSheet(selection: $navigator.selection) { compactColumn = $0 }
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
        searchShowedSidebar = columns.visibility != .all
        isSearchingEverything = true
        // From the entry alone iOS goes one step, to the list and the entry, so the sidebar is asked for once that
        // step is done.
        guard columns.visibility == .detailOnly else {
            columns.visibility = .all
            return
        }
        columns.visibility = .doubleColumn
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            columns.visibility = .all
        }
    }

    /// Shows a linked entry as if chosen in the sidebar, at the tab or heading the link names.
    /// Shows a linked entry as if chosen in the sidebar (`EntryNavigator.open`).
    private func open(_ link: PageLink) -> Bool {
        guard navigator.open(link, in: store) else { return false }
        compactColumn = .detail
        return true
    }

    private func openedMatch() {
        compactColumn = .detail
        guard searchShowedSidebar else { return }
        columns.visibility = .automatic
        searchShowedSidebar = false
    }
}

extension EnvironmentValues {
    /// Whether the window shows one column at a time, as on an iPhone. A column's own size class can't tell: it is
    /// compact on the iPad too.
    @Entry var showsOneColumn = false
}
