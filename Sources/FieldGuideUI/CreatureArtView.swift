import CreatureArt
import SwiftUI
import UniformTypeIdentifiers

/// Where creature art comes from: the user's own Paizo PDFs, used where Scrollkeeper keeps them or copied
/// in, with the ones that have gone missing.
struct CreatureArtView: View {
    @Environment(CreatureArtModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isChoosingFolder = false
    @State private var isChoosingFiles = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Creature art comes from your own Paizo pawn, token and Battle Cards PDFs. Field Guide "
                         + "uses the ones Scrollkeeper downloads where they are, without copying them.")
                        .font(.callout).foregroundStyle(.secondary)
                    importButtons
                    if let progress = model.progress {
                        HStack { ProgressView().controlSize(.small); Text(progress).font(.callout) }
                    } else if let message = model.message {
                        Text(message).font(.callout)
                    }
                }
                if !model.catalog.missingSources.isEmpty { missingSection }
                if !model.catalog.watchedFolders.isEmpty { foldersSection }
                pdfsSection
            }
            .formStyle(.grouped)
            .navigationTitle("Creature Art")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let folder) = result { Task { await model.importFolder(folder) } }
            }
            .fileImporter(isPresented: $isChoosingFiles, allowedContentTypes: [.pdf],
                          allowsMultipleSelection: true) { result in
                if case .success(let files) = result { Task { await model.addFiles(files) } }
            }
            .task { await model.refresh() }
        }
        .frame(minWidth: 520, minHeight: 560)
    }

    private var importButtons: some View {
        HStack {
            Button("Import from Scrollkeeper…", systemImage: "books.vertical", action: importFromScrollkeeper)
            Button("Add PDFs…", systemImage: "doc.badge.plus") { isChoosingFiles = true }
            Spacer()
            Button("Check Again", systemImage: "arrow.clockwise") {
                Task { await model.refresh(addingNew: true) }
            }
        }
        .disabled(model.progress != nil)
    }

    /// On the Mac, Scrollkeeper's folder is used straight away when it's there; on the iPad, the user picks it
    /// in Files (On My iPad ▸ Scrollkeeper).
    private func importFromScrollkeeper() {
        #if os(macOS)
        let folder = URL.applicationSupportDirectory.appendingPathComponent("Scrollkeeper/Files", isDirectory: true)
        if FileManager.default.fileExists(atPath: folder.path) {
            Task { await model.importFolder(folder) }
            return
        }
        #endif
        isChoosingFolder = true
    }

    private var missingSection: some View {
        Section {
            ForEach(model.catalog.missingSources) { source in
                SourceRow(source: source)
            }
        } header: {
            Label("Missing PDFs", systemImage: "exclamationmark.triangle")
        } footer: {
            Text("These PDFs were deleted or moved, so their art can't be shown. Download them again in Scrollkeeper "
                 + "and choose Check Again, or remove them.")
        }
    }

    private var foldersSection: some View {
        Section("Watched folders") {
            ForEach(model.catalog.watchedFolders, id: \.self) { folder in
                HStack {
                    Text(folder).font(.callout).lineLimit(2).truncationMode(.middle)
                    Spacer()
                    Button("Stop Watching") { Task { await model.stopWatching(folder) } }
                }
            }
        }
    }

    private var pdfsSection: some View {
        Section("PDFs") {
            if model.catalog.sources.isEmpty {
                Text("No PDFs yet.").foregroundStyle(.secondary)
            }
            ForEach(model.catalog.sources.filter { !$0.isMissing }) { source in
                SourceRow(source: source)
            }
        }
    }
}

/// A PDF of creature art, with how much art it gives, and a way to remove it.
private struct SourceRow: View {
    let source: ArtSourceSummary
    @Environment(CreatureArtModel.self) private var model

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(source.title)
                Text(source.place).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
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
