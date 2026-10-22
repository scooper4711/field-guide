import Foundation
import SourcebookLore

/// A deity as Foundry's packs describe it.
struct FoundryDeity {
    /// The catalog's entry ID, such as "Compendium.pf2e.deities.Item.<id>".
    var id: String
    var system: String
    var facts: LoreSourceChooser.Deity
}

/// Reads the deities of both systems from a pf2e repository's packs.
enum FoundryDeities {
    static func read(repository: URL) throws -> [FoundryDeity] {
        try ["pf2e", "sf2e"].flatMap { system in
            try files(in: repository.appending(path: "packs/\(system)/deities")).compactMap { file in
                try deity(at: file, system: system)
            }
        }
    }

    private static func files(in folder: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil) else {
            return []
        }
        return enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "json" }
    }

    private static func deity(at file: URL, system: String) throws -> FoundryDeity? {
        guard let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any],
              json["type"] as? String == "deity", let id = json["_id"] as? String, let name = json["name"] as? String,
              let data = json["system"] as? [String: Any] else { return nil }
        let description = (data["description"] as? [String: Any])?["value"] as? String ?? ""
        let credited = (data["publication"] as? [String: Any])?["title"] as? String ?? ""
        return FoundryDeity(id: "Compendium.\(system).deities.Item.\(id)", system: system, facts: .init(
            name: name, credited: credited, edicts: field("Edicts", in: description), prose: prose(of: description)))
    }

    /// The text after a bold label: `<p><strong>Edicts</strong> …</p>`.
    static func field(_ label: String, in html: String) -> String {
        let pattern = "<strong>\(label)</strong>(.*?)</p>"
        guard let range = html.range(of: pattern, options: .regularExpression) else { return "" }
        return plainText(String(html[range]).replacingOccurrences(of: "<strong>\(label)</strong>", with: ""))
    }

    /// The paragraphs that aren't stat lines, as plain text.
    static func prose(of html: String) -> String {
        let paragraphs = html.components(separatedBy: "</p>").filter { !$0.contains("<strong>") }
        return plainText(paragraphs.joined(separator: " "))
    }

    private static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: #"\s+"#, with: " ",
                                                                             options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
