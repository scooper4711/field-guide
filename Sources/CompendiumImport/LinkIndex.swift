import FieldGuideKit
import Foundation

/// Every imported entry by the ways Foundry links to it: `Compendium.<system>.<pack>.<Item|Actor>.<id>`,
/// or with the document's name in place of its ID.
public struct LinkIndex: Sendable {
    /// `<system>.<pack link name>.<id or lowercased name>` → entry ID.
    private var targets: [String: String] = [:]
    private var names: [String: String] = [:]

    public init(documents: [SourceDocument] = []) {
        for document in documents { add(document) }
    }

    public mutating func add(_ document: SourceDocument) {
        let pack = "\(document.system.rawValue).\(document.pack.linkName)"
        targets["\(pack).\(document.json["_id"].string)"] = document.uuid
        let nameKey = "\(pack).\(document.name.lowercased())"
        if targets[nameKey] == nil { targets[nameKey] = document.uuid }
        names[document.uuid] = document.name
    }

    /// The entry a `Compendium.…` link leads to, or nil when it isn't imported.
    public func entryID(forLink link: String) -> String? {
        let parts = link.split(separator: ".", maxSplits: 4).map(String.init)
        guard parts.count == 5, parts[0] == "Compendium" else { return nil }
        return targets["\(parts[1]).\(parts[2]).\(parts[4])"]
            ?? targets["\(parts[1]).\(parts[2]).\(parts[4].lowercased())"]
    }

    public func name(of entryID: String) -> String? { names[entryID] }
}
