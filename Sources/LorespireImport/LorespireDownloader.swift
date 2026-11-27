import Foundation

/// What a request to Lorespire answered.
public struct LorespireResponse: Sendable {
    public let data: Data
    public let contentType: String
    /// The name the server suggests for a download, from its `Content-Disposition`.
    public let suggestedFileName: String?

    public init(data: Data, contentType: String, suggestedFileName: String? = nil) {
        self.data = data
        self.contentType = contentType
        self.suggestedFileName = suggestedFileName
    }
}

public protocol LorespireFetching: Sendable {
    /// Fetches a URL, and throws ``LorespireError/httpStatus(url:status:)`` unless it answers 200.
    func fetch(_ url: URL) async throws -> LorespireResponse
}

/// `manifest.json`: the downloaded documents and their tables of contents.
public struct LorespireManifest: Codable, Sendable, Equatable {
    public struct Document: Codable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let system: LorespireDocument.System
        public let file: String
        public let source: String
        public let outline: [LorespireHeading]
    }

    public let source: String
    public let documents: [Document]
    /// The saved images and attachments, relative to the manifest.
    public let files: [String]
}

/// Downloads the guides into a folder: `<id>.html` for each document (its article, without the site around it),
/// `files/` for the images and attachments they use, and `manifest.json`.
///
/// Everything is fetched before anything is written, so a failed download leaves the folder as it was.
public struct LorespireDownloader: Sendable {
    let fetcher: any LorespireFetching
    let documents: [LorespireDocument]

    public init(fetcher: any LorespireFetching, documents: [LorespireDocument] = Lorespire.documents) {
        self.fetcher = fetcher
        self.documents = documents
    }

    @discardableResult
    public func download(to folder: URL) async throws -> LorespireManifest {
        var pages: [LorespirePage] = []
        for document in documents {
            let response = try await fetcher.fetch(document.url)
            let html = String(bytes: response.data, encoding: .utf8) ?? ""
            pages.append(try LorespirePage(html: html, page: document.page))
        }
        let files = try await fetchFiles(LorespireLinkRewriter.fileIDs(in: pages.map(\.content).joined()))
        let rewriter = LorespireLinkRewriter(
            documents: documents,
            anchors: LorespireHeadings.anchors(in: zip(documents, pages).map { ($0.id, $1.content) }),
            files: files.mapValues(\.path))
        let manifest = manifest(for: pages, files: files.values.map(\.path).sorted())
        let documents = zip(documents, pages).map { document, page in
            (document.fileName, rewriter.rewrite(page.content, in: document.id))
        }
        try write(Download(documents: documents, files: Array(files.values), manifest: manifest), to: folder)
        return manifest
    }

    private func fetchFiles(_ fileIDs: Set<Int>) async throws -> [Int: SavedFile] {
        var files: [Int: SavedFile] = [:]
        for fileID in fileIDs.sorted() {
            let response = try await fetcher.fetch(Lorespire.fileURL(fileID))
            files[fileID] = SavedFile(path: "files/" + SavedFile.name(fileID, response), data: response.data)
        }
        return files
    }

    private func manifest(for pages: [LorespirePage], files: [String]) -> LorespireManifest {
        LorespireManifest(source: Lorespire.host, documents: zip(documents, pages).map { document, page in
            LorespireManifest.Document(id: document.id, title: page.title, system: document.system,
                                       file: document.fileName, source: document.url.absoluteString,
                                       outline: LorespireHeadings.outline(of: page.content))
        }, files: files)
    }

    private func write(_ download: Download, to folder: URL) throws {
        let manager = FileManager.default
        try? manager.removeItem(at: folder)
        try manager.createDirectory(at: folder.appendingPathComponent("files"), withIntermediateDirectories: true)
        for (fileName, html) in download.documents {
            try Data(html.utf8).write(to: folder.appendingPathComponent(fileName))
        }
        for file in download.files { try file.data.write(to: folder.appendingPathComponent(file.path)) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(download.manifest).write(to: folder.appendingPathComponent("manifest.json"))
    }
}

/// Everything a download writes: each document's file name and HTML, the files, and the manifest.
private struct Download {
    let documents: [(String, String)]
    let files: [SavedFile]
    let manifest: LorespireManifest
}

/// An image or attachment, named `<file ID>-<the server's name for it>`.
struct SavedFile {
    let path: String
    let data: Data

    static func name(_ fileID: Int, _ response: LorespireResponse) -> String {
        let suggested = (response.suggestedFileName ?? "").lowercased()
            .replacing(/[^a-z0-9.]+/, with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        guard suggested.isEmpty else { return "\(fileID)-\(suggested)" }
        return "\(fileID).\(extensions[response.contentType] ?? "bin")"
    }

    private static let extensions = [
        "image/png": "png", "image/gif": "gif", "image/jpeg": "jpg", "image/webp": "webp", "image/svg+xml": "svg",
        "application/pdf": "pdf"
    ]
}
