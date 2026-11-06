import Foundation

/// A creature whose lore Foundry's packs hold, and so the import leaves out.
struct FoundryCreature {
    /// The catalog's entry ID, such as "Compendium.pf2e.pathfinder-monster-core.Actor.<id>".
    var id: String
    var system: String
    var name: String
    /// The book Foundry credits.
    var credited: String
    /// Foundry's paragraphs about the creature, as plain text.
    var prose: String
    /// Foundry's paragraphs about the creature's family (after its `<hr>`), as plain text.
    var familyProse: String
}

/// Reads the creatures with lore from a pf2e repository's packs, leaving out those the Paizo Blog published, whose
/// lore the import keeps.
enum FoundryCreatures {
    static let communityUseSources = ["Paizo Blog", "Pathfinder Blog"]

    static func read(repository: URL) throws -> [FoundryCreature] {
        try ["pf2e", "sf2e"].flatMap { system in
            let packs = repository.appending(path: "packs/\(system)")
            let folders = try FileManager.default.contentsOfDirectory(at: packs, includingPropertiesForKeys: nil)
            return folders.flatMap { folder in
                files(in: folder).compactMap { creature(at: $0, system: system, pack: folder.lastPathComponent) }
            }
        }
    }

    private static func files(in folder: URL) -> [URL] {
        let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)
        return (enumerator?.compactMap { $0 as? URL } ?? []).filter { $0.pathExtension == "json" }
    }

    private static func creature(at file: URL, system: String, pack: String) -> FoundryCreature? {
        guard let data = try? Data(contentsOf: file),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["type"] as? String == "npc", let id = json["_id"] as? String, let name = json["name"] as? String,
              let details = (json["system"] as? [String: Any])?["details"] as? [String: Any] else { return nil }
        let notes = (details["publicNotes"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let credited = (details["publication"] as? [String: Any])?["title"] as? String ?? ""
        guard !notes.isEmpty, !communityUseSources.contains(where: credited.hasPrefix) else { return nil }
        let parts = notes.components(separatedBy: "<hr")
        let family = parts.dropFirst().joined(separator: " ").replacingOccurrences(of: "^[^>]*>", with: "",
                                                                                     options: .regularExpression)
        return FoundryCreature(id: "Compendium.\(system).\(pack).Actor.\(id)", system: system, name: name,
                               credited: credited, prose: plainText(parts[0]), familyProse: plainText(family))
    }

    static func plainText(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "@\\w+\\[[^\\]]*\\](\\{([^}]*)\\})?", with: "$2", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
