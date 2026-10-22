import Testing
@testable import SourcebookLore

@Suite struct LoreSourceChooserTests {
    typealias Finding = LoreSourceChooser.Finding

    static let abadar = LoreSourceChooser.Deity(
        name: "Abadar", credited: "Divine Mysteries", edicts: "follow the rule of law",
        prose: "Abadar is worshipped among most as a god of commerce, civilization, and order.")

    static func writeup(_ book: String, edicts: String = "", prose: [String] = []) -> Finding {
        let lines = edicts.isEmpty ? [] : [StatLine(label: "Edicts", text: edicts)]
        return Finding(book: book, lore: DeityLore(statLines: lines, paragraphs: prose))
    }

    @Test func takesStatLinesFromATableFirst() {
        let findings = [Self.writeup("Divine Mysteries", edicts: "follow the rule of law", prose: ["Prose."]),
                        Finding(book: "Web Supplement", lore: DeityLore(statLines: [
                            StatLine(label: "Title", text: "Master of the First Vault")]), isTable: true)]
        #expect(LoreSourceChooser.sources(of: Self.abadar, findings: findings)
                == LoreSources(stats: "Web Supplement", prose: "Divine Mysteries"))
    }

    @Test func prefersTheTablesAskedFor() {
        let table = { (book: String) in
            Finding(book: book, lore: DeityLore(statLines: [StatLine(label: "Title", text: "T")]), isTable: true)
        }
        let findings = [table("Divine Mysteries"), table("Web Supplement")]
        #expect(LoreSourceChooser.statsSource(of: Self.abadar, findings: findings) == "Divine Mysteries")
        #expect(LoreSourceChooser.statsSource(of: Self.abadar, findings: findings, preferredTables: ["Web Supplement"])
                == "Web Supplement")
    }

    @Test func takesStatLinesFromTheCreditedBookThenFromTheClosestEdicts() {
        let credited = [Self.writeup("Gods & Magic", edicts: "follow the law"),
                        Self.writeup("Divine Mysteries", edicts: "work hard")]
        #expect(LoreSourceChooser.statsSource(of: Self.abadar, findings: credited) == "Divine Mysteries")
        let others = [Self.writeup("Player Core", edicts: "trade often"),
                      Self.writeup("Gods & Magic", edicts: "follow the rule of law always")]
        #expect(LoreSourceChooser.statsSource(of: Self.abadar, findings: others) == "Gods & Magic")
        #expect(LoreSourceChooser.statsSource(of: Self.abadar, findings: [Self.writeup("GM Core", prose: ["P."])])
                == nil)
    }

    @Test func takesProseFromTheCreditedBookThenFromTheOneThatOpensAsFoundrysDoes() {
        let credited = [Self.writeup("Gods & Magic", prose: ["Other."]),
                        Self.writeup("Divine Mysteries", prose: ["A."])]
        #expect(LoreSourceChooser.proseSource(of: Self.abadar, findings: credited) == "Divine Mysteries")
        let others = [Self.writeup("Player Core", prose: ["Abadar keeps vaults."]),
                      Self.writeup("Gods & Magic", prose: ["Abadar is worshipped among most as a god of commerce, "
                                                            + "civilization, and order. He values neutrality."])]
        #expect(LoreSourceChooser.proseSource(of: Self.abadar, findings: others) == "Gods & Magic")
        let silent = LoreSourceChooser.Deity(name: "Anubis", credited: "Divine Mysteries")
        #expect(LoreSourceChooser.proseSource(of: silent, findings: others) == nil)
    }

    @Test func measuresHowManyWordsTwoTextsShare() {
        #expect(LoreSourceChooser.similarity("follow the law", "follow the law") == 1)
        #expect(LoreSourceChooser.similarity("a b", "c d") == 0)
        #expect(LoreSourceChooser.similarity("", "") == 0)
    }
}
