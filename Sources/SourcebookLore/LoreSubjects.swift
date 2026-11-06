import Foundation

/// An entry in the catalog whose lore the user's books may give: a creature, an ancestry or a class.
public struct EntryReference: Equatable, Hashable, Sendable {
    public var id: String
    public var name: String
    /// The book Foundry credits, such as "Pathfinder Bestiary".
    public var credited: String

    public init(id: String, name: String, credited: String) {
        self.id = id
        self.name = name
        self.credited = credited
    }
}

/// The entries whose lore Field Guide reads from the user's books.
public struct LoreSubjects: Sendable {
    /// Each deity's name by entry ID.
    public var deityNames: [String: String]
    public var creatures: [EntryReference]
    /// The ancestries and classes, whose Details hold lore.
    public var details: [EntryReference]

    public init(deityNames: [String: String] = [:], creatures: [EntryReference] = [],
                details: [EntryReference] = []) {
        self.deityNames = deityNames
        self.creatures = creatures
        self.details = details
    }
}
