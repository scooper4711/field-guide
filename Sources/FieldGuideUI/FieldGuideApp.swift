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
    }
}

/// Sidebar of categories under the system switch, the entry list, and the entry.
struct RootView: View {
    @Environment(CatalogStore.self) private var store
    /// `FIELD_GUIDE_SELECT` opens an entry at launch, for trying pages out from a script.
    @State private var selection = ProcessInfo.processInfo.environment["FIELD_GUIDE_SELECT"]

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 220, ideal: 250)
        } content: {
            EntryListView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 280, ideal: 340)
        } detail: {
            if let selection {
                EntryDetailView(rootID: selection)
                    .id(selection)
            } else {
                ContentUnavailableView("Choose an Entry", systemImage: "book",
                                       description: Text(store.errorMessage ?? "Pick something from the list."))
            }
        }
        .onChange(of: store.category) { selection = nil }
        .onChange(of: store.system) { selection = nil }
    }
}

struct SidebarView: View {
    @Environment(CatalogStore.self) private var store
    @State private var isShowingPDFArt = false

    var body: some View {
        @Bindable var store = store
        List(selection: $store.category) {
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
        .navigationTitle("Field Guide")
        .toolbar {
            Button("Art from PDFs", systemImage: "photo.on.rectangle.angled") { isShowingPDFArt = true }
        }
        .sheet(isPresented: $isShowingPDFArt) { PDFArtView() }
    }
}
