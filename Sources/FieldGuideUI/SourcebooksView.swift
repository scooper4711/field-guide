import CreatureArt
import FieldGuideKit
import SourcebookLore
import SwiftUI
import TablesideShared
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
    @AppStorage("sourcebookFilter") private var filter = SourcebookFilter.all

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Deities' and creatures' lore comes from your own Paizo sourcebooks, creature art from your "
                         + "pawn, token and Battle Cards PDFs, and item art from your item decks (Potions & Talismans, "
                         + "Guns, Deck of Endless Treasure, …). Field Guide uses the ones Scrollkeeper downloads where "
                         + "they are, without copying them.")
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
                await sourcebooks.refresh(subjects: store.loreSubjects())
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
                    await sourcebooks.refresh(addingNew: true, subjects: store.loreSubjects())
                }
            }
        }
        .formRowButtonStyle()
        .disabled(model.progress != nil || sourcebooks.progress != nil)
    }

    /// Scrollkeeper's downloads are used straight away when they're there (the shared App Group folder first);
    /// otherwise the user picks the folder.
    private func importFromScrollkeeper() {
        if let folder = ScrollkeeperDownloads.standard.folder {
            importFolder(folder)
            return
        }
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
                await sourcebooks.addFiles(urls, subjects: store.loreSubjects())
            }
        }
    }

    private func importFolder(_ folder: URL) {
        Task {
            await model.importFolder(folder)
            await sourcebooks.importFolder(folder, subjects: store.loreSubjects())
        }
    }

    private var sourcebooksSection: some View {
        Section {
            let rows = filter.rows(sourcebooks.rows)
            if rows.isEmpty {
                Text(filter.emptyMessage).foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                SourcebookRowView(row: row)
            }
        } header: {
            HStack {
                Text("Sourcebooks")
                Spacer()
                Picker("Show", selection: $filter) {
                    ForEach(SourcebookFilter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                .textCase(nil)
            }
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let sync = sourcebooks.syncStatus.text { Text(sync) }
                Text("Each deity's lore comes from one book for its edicts, anathema and other lines, and one for its "
                     + "write-up. The free Divine Mysteries Web Supplement gives nearly every deity's lines. A "
                     + "creature from a Bestiary takes its lore from Monster Core or Monster Core 2 when you have "
                     + "them.")
            }
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
                Text(row.supplies)
                    .font(.caption).foregroundStyle(.secondary)
                if row.isReadElsewhere {
                    Text("Processed on another device").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if row.isRead {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel("Processed")
            } else if let sku = row.book.sku, scrollkeeper.owns(sku: sku) {
                Button("Download") { scrollkeeper.open(sku: sku) }.formRowButtonStyle()
            } else if let url = row.book.downloadURL {
                Link("Get", destination: url).formRowButtonStyle()
            } else if scrollkeeper.lacks(sku: row.book.sku) {
                Text("Not in your library").font(.caption).foregroundStyle(.secondary)
            } else {
                // Without Scrollkeeper's list, or a SKU to look the book up by, whether the user owns it is unknown.
                Text("Use Add PDFs… to process it").font(.caption).foregroundStyle(.secondary)
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
