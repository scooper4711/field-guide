import Foundation
import PDFKit

/// Works out which sourcebook a PDF is. The file's name may have been changed, so it tries, in order: the name of
/// the file or its folder (as Scrollkeeper and Paizo name them), a `PZO…` SKU in the file's name, and, when asked
/// to open the PDF, the product's own copyright line ("Pathfinder Lost Omens Divine Mysteries © 2024, Paizo Inc."),
/// the last one in its license notice, after the lines crediting other books.
public struct SourcebookIdentifier: Sendable {
    public let list: SourcebookList

    public init(list: SourcebookList) {
        self.list = list
    }

    /// The book the file's name, its folder's name or a SKU in it names, without opening the file.
    public func book(namedBy file: URL) -> Sourcebook? {
        let name = file.deletingPathExtension().lastPathComponent
        if let book = list.book(named: name) ?? list.book(named: file.deletingLastPathComponent().lastPathComponent) {
            return book
        }
        guard let range = name.range(of: #"PZO\w+"#, options: .regularExpression) else { return nil }
        let sku = String(name[range])
        return list.books.first { $0.sku == sku }
    }

    /// The book the file's name or, failing that, its copyright line names.
    public func book(of file: URL, document: PDFDocument) -> Sourcebook? {
        book(namedBy: file) ?? copyrightLine(of: document).flatMap(list.book(named:))
    }

    /// The product's name from the last copyright line in the document's closing pages.
    func copyrightLine(of document: PDFDocument) -> String? {
        let pages = max(0, document.pageCount - 8)..<document.pageCount
        let text = pages.compactMap { document.page(at: $0)?.string }.joined(separator: "\n")
        let pattern = #"([^\n©]+?)\s*©\s*\d{4},?\s*Paizo"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = expression.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let names = matches.compactMap { match in Range(match.range(at: 1), in: text).map { String(text[$0]) } }
        return names.last { list.book(named: $0) != nil }
    }
}
