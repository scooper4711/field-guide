import Foundation

/// The two Foundry systems the catalog holds, by their system IDs.
public enum GameSystem: String, CaseIterable, Codable, Sendable, Identifiable {
    case pathfinder = "pf2e"
    case starfinder = "sf2e"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pathfinder: "Pathfinder"
        case .starfinder: "Starfinder"
        }
    }
}
