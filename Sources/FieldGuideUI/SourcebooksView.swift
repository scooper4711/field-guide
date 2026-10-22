import CreatureArt
import FieldGuideKit
import SourcebookLore
import SwiftUI
import UniformTypeIdentifiers

/// Where art and deity lore come from: the user's own Paizo PDFs, used where Scrollkeeper keeps them or copied
/// in. Lists the sourcebooks whose lore Field Guide reads, and the PDFs of art, with the ones that have gone missing.
struct SourcebooksView: View {
    @Environment(ArtModel.self) private var model
    @Environment(SourcebookModel.self) private var sourcebooks
    @Environment(CatalogStore.self) private var store
    @Environment(ScrollkeeperLink.self) private var scrollkeeper
    @Environment(\.dismiss) private var dismiss
    // One file importer serves both buttons: SwiftUI presents only one of several on the same view.
    @State private var isChoosing = false
    @State private var choice = ArtChoice.pdfs

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Deities' lore comes from your own Paizo sourcebooks, creature art from your pawn, token "
                         + "and Battle Cards PDFs, and item art from your item decks (Potions & Talismans, Guns, Deck "
                         + "of Endless Treasure, …). Field Guide uses the ones Scrollkeeper downloads where they are, "
                         + "without copying them.")
                        .font(.callout).foregroundStyle(.secondary)
                    importButtons
                    if let progress = sourcebooks.progress ?? model.progress ?? scrollkeeper.requested?.status {
                        HStack { ProgressView().controlSize(.small); Text(progress).font(.callout) }
                    } else {
                        ForEach([sourcebooks.message, model.message].compactMap { $0 }, id: \.self) { message in
                            Text(message).font(.callout)
                        }
                    }
                }
                sourcebooksSection
                if !model.catalog.missingSources.isEmpty { missingSection }
                if !model.catalog.watchedFolders.isEmpty { foldersSection }
                pdfsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Sourcebooks")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $isChoosing, allowedContentTypes: choice.contentTypes,
                          allowsMultipleSelection: choice == .pdfs) { result in
                if case .success(let urls) = result { chose(urls) }
            }
            .task {
                scrollkeeper.requestIndex()
                await model.refresh()
                await sourcebooks.refresh(names: store.deityNames())
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private var importButtons: some View {
        HStack {
            Button("Import from Scrollkeeper…", systemImage: "books.vertical", action: importFromScrollkeeper)
            Button("Add PDFs…", systemImage: "doc.badge.plus") { choose(.pdfs) }
            Spacer()
            Button("Check Again", systemImage: "arrow.clockwise") {
                Task {
                    await model.refresh(addingNew: true)
                    await sourcebooks.refresh(addingNew: true, names: store.deityNames())
                }
            }
        }
        .formRowButtonStyle()
        .disabled(model.progress != nil || sourcebooks.progress != nil)
    }

    /// On the Mac, Scrollkeeper's folder is used straight away when it's there; on the iPad, the user picks it
    /// in Files (On My iPad ▸ Scrollkeeper).
    private func importFromScrollkeeper() {
        #if os(macOS)
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Scrollkeeper/Files", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            importFolder(folder)
            return
        }
        #endif
        choose(.folder)
    }

    private func choose(_ choice: ArtChoice) {
        self.choice = choice
        isChoosing = true
    }

    private func chose(_ urls: [URL]) {
        switch choice {
        case .folder:
            guard let folder = urls.first else { return }
            importFolder(folder)
        case .pdfs:
            Task {
                await model.addFiles(urls)
                await sourcebooks.addFiles(urls, names: store.deityNames())
            }
        }
    }

    private func importFolder(_ folder: URL) {
        Task {
            await model.importFolder(folder)
            await sourcebooks.importFolder(folder, names: store.deityNames())
        }
    }

    private var sourcebooksSection: some View {
        Section {
            ForEach(sourcebooks.rows) { row in
                SourcebookRowView(row: row)
            }
        } header: {
            Text("Sourcebooks")
        } footer: {
            Text("Each deity's lore comes from one book for its edicts, anathema and other lines, and one for its "
                 + "write-up. The free Divine Mysteries Web Supplement gives nearly every deity's lines.")
        }
    }

    private var missingSection: some View {
        Section {
            ForEach(model.catalog.missingSources) { source in
                SourceRow(source: source)
            }
        } header: {
            Label("Missing PDFs", systemImage: "exclamationmark.triangle")
        } footer: {
            Text("Field Guide can't reach these PDFs, so their art can't be shown. If they're still there, choose "
                 + "Import from Scrollkeeper… and pick their folder again. If they were deleted or moved, download "
                 + "them again in Scrollkeeper and choose Check Again, or remove them.")
        }
    }

    private var foldersSection: some View {
        Section("Watched folders") {
            ForEach(model.catalog.watchedFolders, id: \.self) { folder in
                HStack {
                    let name = FolderName(path: folder)
                    VStack(alignment: .leading, spacing: 2) {
                        Label(name.title, systemImage: "folder")
                        Text(name.location).font(.caption).foregroundStyle(.secondary)
                            .lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    Button("Stop Watching") { Task { await model.stopWatching(folder) } }
                        .formRowButtonStyle()
                }
            }
        }
    }

    private var pdfsSection: some View {
        Section("PDFs of Art") {
            if model.catalog.sources.isEmpty {
                Text("No PDFs yet.").foregroundStyle(.secondary)
            }
            ForEach(model.catalog.sources.filter { !$0.isMissing }) { source in
                SourceRow(source: source)
            }
        }
    }
}

/// What the file importer is choosing: Scrollkeeper's folder, or PDFs to keep copies of.
private enum ArtChoice {
    case folder, pdfs

    var contentTypes: [UTType] { self == .folder ? [.folder] : [.pdf] }
}

/// A sourcebook, what it supplies, and whether Field Guide has read it. One not read yet can be downloaded through
/// Scrollkeeper when the user owns it there, or from Paizo when it's free; there is no link to buy one.
private struct SourcebookRowView: View {
    let row: SourcebookRow
    @Environment(ScrollkeeperLink.self) private var scrollkeeper

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.book.title)
                Text("Deity lore: \(row.deityCount) \(row.deityCount == 1 ? "deity" : "deities")")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if row.isRead {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel("Read")
            } else if let sku = row.book.sku, scrollkeeper.owns(sku: sku) {
                Button("Download") { scrollkeeper.open(sku: sku) }.formRowButtonStyle()
            } else if let url = row.book.downloadURL {
                Link("Get", destination: url).formRowButtonStyle()
            } else {
                Text("Not in your library").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// A PDF of creature art, with how much art it gives, and a way to remove it.
private struct SourceRow: View {
    let source: ArtSourceSummary
    @Environment(ArtModel.self) private var model

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                Text(FolderName.place(ofFile: source.place)).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            Text("\(source.artCount) art").font(.caption).foregroundStyle(.secondary)
            Button("Remove", systemImage: "trash", role: .destructive) {
                Task { await model.removeSource(id: source.id) }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }
}

private extension View {
    /// Text buttons in a Form row.
    @ViewBuilder
    func formRowButtonStyle() -> some View {
        #if os(macOS)
        // Push buttons, as in System Settings: borderless ones draw gray on the Mac and look disabled.
        buttonStyle(.bordered)
        #else
        // In a Form row a tap would trigger every button; borderless buttons each take only their own taps.
        buttonStyle(.borderless)
        #endif
    }
}
