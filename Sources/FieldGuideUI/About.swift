import AppNotices
import Foundation

extension AboutInfo {
    /// Field Guide's About screen. The credits match the README's Paizo notices.
    static let fieldGuide = AboutInfo(
        appName: "Field Guide",
        tagline: "An unofficial, free, offline compendium browser for Pathfinder and Starfinder.",
        credits: [
            "Compendium text comes from the pf2e system for Foundry VTT and is used under the ORC License and the "
                + "Open Game License 1.0a.",
            "The deities' religious symbols are from Paizo's Community Use Package, used under the Community Use "
                + "Policy.",
            "Item and spell icons and the battle cards' parchment, frames and panels are Rexard game dev assets, "
                + "used under license.",
            "The action icons are Paizo's Pathfinder-Icons font, used unaltered under the Paizo Compatibility "
                + "License."
        ],
        // A literal URL that is known to parse. The repository is private, so this is the author's profile.
        // swiftlint:disable:next force_unwrapping
        contactURL: URL(string: "https://github.com/scooper4711")!
    )
}
