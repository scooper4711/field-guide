import FieldGuideKit

/// Where the pf2e and sf2e rules journals' pages go. Archetypes and Domains are categories of their own; the pages
/// of the Ancestries and Classes journals are their entries' Details, and the few that are no entry's (the guides)
/// are listed with the entries they are about. Hero Point Deck and Remaster Changes are not shown at all.
enum JournalPlacement {
    /// Journals Field Guide does not show.
    static let skippedFiles: Set<String> = ["remaster-changes.json", "hero-point-deck.json"]
    static let categories: [String: EntryCategory] = [
        GMScreen.gmScreenFile: .gmScreen, "archetypes.json": .archetypes, "domains.json": .domains
    ]
    static let details: [String: EntryCategory] = ["ancestries.json": .ancestries, "classes.json": .classes]

    /// A guide page's category, and the key its list sorts it by instead of its name.
    struct Guide {
        let category: EntryCategory
        let sortKey: String
    }

    /// The pages that are no entry's Details, by journal file and page name. A key that starts with a space sorts
    /// before every name, in the order of its digit; the Draconic pages are keyed to follow the Sorcerer.
    static let guides: [String: Guide] = [
        "ancestries.json|Index": Guide(category: .ancestries, sortKey: " 0 Index"),
        "ancestries.json|Standardized Ancestry Feats":
            Guide(category: .ancestries, sortKey: " 1 Standardized Ancestry Feats"),
        "ancestries.json|Versatile Heritages": Guide(category: .heritages, sortKey: " 0 Versatile Heritages"),
        "classes.json|Draconic Sorcerer Bloodlines":
            Guide(category: .classes, sortKey: "Sorcerer 1 Draconic Sorcerer Bloodlines"),
        "classes.json|Draconic Connections": Guide(category: .classes, sortKey: "Sorcerer 2 Draconic Connections")
    ]

    /// The category of a journal's pages, or nil for a journal no rule places: the import reports it instead of
    /// showing its pages anywhere.
    static func category(ofFile file: String) -> EntryCategory? {
        categories[file] ?? details[file]
    }

    static func guide(file: String, page: String) -> Guide? {
        guides["\(file)|\(page)"]
    }
}
