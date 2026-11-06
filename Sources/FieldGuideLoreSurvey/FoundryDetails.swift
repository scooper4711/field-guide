import FieldGuideKit
import Foundation
import PDFKit
import SourcebookLore

/// An ancestry's or class's Details page as Foundry's journals hold it, split where its rules begin.
struct FoundryDetails {
    var system: String
    var name: String
    /// The book Foundry credits the ancestry or class to.
    var credited: String
    /// The setting's prose before the rules, as plain text.
    var lore: String
}

/// Reads the Ancestries and Classes journals' pages that are an ancestry's or class's Details.
enum FoundryDetailsPages {
    static func read(repository: URL) throws -> [FoundryDetails] {
        try ["pf2e", "sf2e"].flatMap { system in
            try ["ancestries", "classes"].flatMap { kind in try read(kind, system: system, repository: repository) }
        }
    }

    private static func read(_ kind: String, system: String, repository: URL) throws -> [FoundryDetails] {
        let packs = repository.appending(path: "packs/\(system)")
        let credits = credited(in: packs.appending(path: kind))
        let journal = packs.appending(path: "journals/\(kind).json")
        guard let json = try JSONSerialization.jsonObject(with: Data(contentsOf: journal)) as? [String: Any],
              let pages = json["pages"] as? [[String: Any]] else { return [] }
        return pages.compactMap { page in
            guard let name = page["name"] as? String, let credited = credits[name],
                  let html = (page["text"] as? [String: Any])?["content"] as? String, !html.isEmpty else { return nil }
            return FoundryDetails(system: system, name: name, credited: credited,
                                  lore: FoundryCreatures.plainText(String(html[DetailsPage.loreRange(in: html)])))
        }
    }

    /// The book each ancestry or class is credited to, by name.
    private static func credited(in folder: URL) -> [String: String] {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "json" } ?? []
        var credits: [String: String] = [:]
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["name"] as? String,
                  let system = json["system"] as? [String: Any] else { continue }
            credits[name] = credits[name] ?? (system["publication"] as? [String: Any])?["title"] as? String ?? ""
        }
        return credits
    }
}

/// How well a book's Details, as `DetailsWriteups` reads them, match Foundry's prose.
struct DetailsCheck {
    let pages: [FoundryDetails]

    func check(book title: String, pdf: URL) -> String {
        let credited = pages.filter { $0.credited == title }
        guard let document = PDFDocument(url: pdf), !credited.isEmpty else { return "| \(title) | 0 | 0 | 0 |" }
        let found = DetailsWriteups(names: credited.map(\.name)).writeups(in: document)
        let quality = TextQuality(reference: credited.map(\.lore).joined(separator: " "))
        var matching = 0
        for page in credited {
            guard let lore = found[page.name] else {
                FileHandle.standardError.write(Data("MISSED \(page.name)\n".utf8))
                continue
            }
            let text = lore.sections.flatMap { [$0.heading] + $0.paragraphs.map { $0.label + " " + $0.text } }
                .joined(separator: " ")
            let score = LoreSourceChooser.similarity(text, page.lore)
            // A labeled paragraph ("Popular Anathema") or a bulleted item stands alone without ending a sentence.
            let splits = lore.sections.flatMap { section in
                TextQuality.splitParagraphs(section.paragraphs.map { $0.label.isEmpty ? $0.text : "\($0.text)." },
                                            continuing: section.paragraphs.map { $0.label.isEmpty })
            }
            for fault in quality.problems(in: text) + splits {
                FileHandle.standardError.write(Data("FAULT \(page.name): \(fault)\n".utf8))
            }
            if score >= CreatureCheck.matchThreshold { matching += 1 }
            FileHandle.standardError.write(Data(String(format: "%@ %.2f\n", page.name, score).utf8))
        }
        return "| \(title) | \(credited.count) | \(found.count) | \(matching) |"
    }
}
