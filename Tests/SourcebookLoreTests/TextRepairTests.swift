import Testing
@testable import SourcebookLore

@Suite struct TextRepairTests {
    @Test func joinsAParagraphsLinesKeepingCompoundsWhole() {
        #expect(TextRepair.join(["Abadar’s worship is", "commonplace anywhere "])
                == "Abadar’s worship is commonplace anywhere")
        #expect(TextRepair.join(["mortals’ self-", "importance, and the"]) == "mortals’ self-importance, and the")
        #expect(TextRepair.join(["the god—", "or so they say"]) == "the god—or so they say")
        #expect(TextRepair.join(["prog\u{00AD}", "ress", ""]) == "progress")
    }

    @Test func repairsHeadingsSetInJoinedLetterGlyphs() {
        #expect(TextRepair.heading("The ShADow War") == "The Shadow War")
        #expect(TextRepair.heading("HeLLBound Honor Guard") == "Hellbound Honor Guard")
        #expect(TextRepair.heading("Abrogail Thrune ii") == "Abrogail Thrune II")
        #expect(TextRepair.heading("I Am") == "I Am")
    }

    @Test func spellsAHeadingThatNamesADeityAsTheCatalogDoes() {
        #expect(TextRepair.heading("MaMMon", names: ["Abadar", "Mammon"]) == "Mammon")
        #expect(TextRepair.heading("CASANDALEE", names: ["Casandalee"]) == "Casandalee")
    }

    @Test func titleCasesALineSetInCapitals() {
        #expect(TextRepair.titleCase("MASTER OF THE FIRST VAULT") == "Master of the First Vault")
        #expect(TextRepair.titleCase("THE ALL-SEEING EYE") == "The All-Seeing Eye")
        #expect(TextRepair.titleCase("HOST OF THE ELDER II") == "Host of the Elder II")
    }

    @Test func comparesNamesWithoutCaseAccentsOrMarks() {
        #expect(TextRepair.matchKey("Abadar†") == TextRepair.matchKey("ABADAR"))
        #expect(TextRepair.matchKey("Cyth-V’sug") == TextRepair.matchKey("Cyth-V'sug"))
        #expect(TextRepair.matchKey("Ketephys") != TextRepair.matchKey("Kelinahat"))
        #expect(TextRepair.matchKey("Ëlio") == "elio")
    }
}
