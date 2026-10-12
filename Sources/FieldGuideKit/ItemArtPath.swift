import Foundation

/// An item's image: its art from the user's item decks, read on the device, else its icon from the import.
/// Written as `item/<system>/<name>?fallback=<icon path>`.
public struct ItemArtPath: Equatable, Sendable {
    public static let prefix = "item/"
    private static let fallbackMarker = "?fallback="

    public var system: GameSystem
    public var name: String
    /// The stored icon shown when there is no art; empty for none.
    public var fallback: String

    public init(system: GameSystem, name: String, fallback: String) {
        self.system = system
        self.name = name
        self.fallback = fallback
    }

    /// The path an image path names, or nil when it isn't an item's.
    public init?(path: String) {
        guard path.hasPrefix(Self.prefix) else { return nil }
        let rest = path.dropFirst(Self.prefix.count)
        let parts = rest.components(separatedBy: Self.fallbackMarker)
        let systemAndName = parts[0].split(separator: "/", maxSplits: 1).map(String.init)
        guard systemAndName.count == 2, let system = GameSystem(rawValue: systemAndName[0]) else { return nil }
        self.init(system: system, name: systemAndName[1], fallback: parts.count > 1 ? parts[1] : "")
    }

    public var path: String {
        "\(Self.prefix)\(system.rawValue)/\(name)\(Self.fallbackMarker)\(fallback)"
    }
}
