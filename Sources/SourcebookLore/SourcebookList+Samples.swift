import Foundation

/// The sample sourcebooks (`SampleSourcebook`), one for each game: placeholder text under real creatures', deities',
/// ancestries' and classes' names, for App Review and anyone without Paizo's books to try reading lore. A sample's
/// lore goes only to its own game's entries, and comes after any real book's.
extension SourcebookList {
    public static let pathfinderSample = sampleBook(title: "Field Guide Sample Monster Core")
    public static let starfinderSample = sampleBook(title: "Field Guide Sample Alien Core")
    public static let samples = [pathfinderSample, starfinderSample]

    /// The game, as entry IDs name it ("Compendium.pf2e.…"), whose entries each sample gives lore to, by title.
    private static let sampleGames = [pathfinderSample.title: "pf2e", starfinderSample.title: "sf2e"]

    public static func isSample(_ title: String) -> Bool {
        sampleGames[title] != nil
    }

    /// The sample for the game of the entry `id` names; nil for an ID that names no game a sample covers.
    public static func sample(forEntry id: String) -> Sourcebook? {
        guard let game = game(ofEntry: id) else { return nil }
        return samples.first { sampleGames[$0.title] == game }
    }

    /// Whether the sample `title` gives lore to the entry `id`: only to its own game's entries.
    public static func sample(_ title: String, covers id: String) -> Bool {
        sample(forEntry: id)?.title == title
    }

    /// The game an entry ID names, such as "sf2e" for "Compendium.sf2e.deities.Item.d56paSkcwvll2OhR".
    static func game(ofEntry id: String) -> String? {
        let parts = id.split(separator: ".", maxSplits: 2)
        guard parts.count > 2, parts[0] == "Compendium" else { return nil }
        return String(parts[1])
    }

    private static func sampleBook(title: String) -> Sourcebook {
        let file = (title + ".pdf").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        return Sourcebook(
            title: title,
            downloadURL: URL(string: "https://github.com/scooper4711/field-guide/raw/main/Resources/Review/" + file),
            supplies: [.deityLore, .creatureLore, .detailsLore])
    }
}
