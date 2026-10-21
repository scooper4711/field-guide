import FieldGuideKit
import Foundation
import Testing
@testable import CompendiumImport

@Suite struct RulesDiagramTests {
    func page(_ name: String, category: EntryCategory = .gmScreen, html: String) -> JournalPage {
        JournalPage(system: .pathfinder, category: category, journalID: "j", pageID: "p", name: name,
                    section: "Playing the Game", html: html)
    }

    @Test func detectionFollowsTheTable() {
        let html = "<table><tr><td>Observed</td></tr></table><p><em>Section: Playing the Game</em></p>"
        let result = RulesDiagrams.adding(to: html, of: page("Detecting Creatures", html: html))
        #expect(result.hasPrefix("<table><tr><td>Observed</td></tr></table><figure class=\"rules-figure\">"
                                 + "<svg class=\"rules-diagram detection\""))
        #expect(result.hasSuffix("</ul></figure><p><em>Section: Playing the Game</em></p>"))
        #expect(result.components(separatedBy: "<li>").count - 1 == RulesDiagrams.detectionNotes.count)
    }

    @Test func counteractFollowsTheDegreesOfSuccess() {
        let html = "<p><strong>Critical Failure</strong> You fail to counteract the target.</p>"
            + "<h3>Counteract Table</h3>"
        let result = RulesDiagrams.adding(to: html, of: page("Counteracting", html: html))
        #expect(result.contains("the target.</p><figure class=\"rules-figure\">"
                                + "<svg class=\"rules-diagram counteract\""))
        #expect(result.hasSuffix("</svg></figure><h3>Counteract Table</h3>") && !result.contains("rules-notes"))
    }

    @Test func otherPagesAreUnchanged() {
        let table = "<table></table>"
        #expect(RulesDiagrams.adding(to: table, of: page("Senses", html: table)) == table)
        let journal = page("Detecting Creatures", category: .journals, html: table)
        #expect(RulesDiagrams.adding(to: table, of: journal) == table)
        #expect(RulesDiagrams.adding(to: "<p>Rewritten</p>", of: page("Counteracting", html: "")) == "<p>Rewritten</p>")
    }

    @Test(arguments: RulesDiagrams.placements.map(\.html))
    func diagramsAreWellFormed(html: String) {
        let parser = XMLParser(data: Data(html.utf8))
        #expect(parser.parse(), "\(parser.parserError.map(String.init(describing:)) ?? "")")
        #expect(!html.contains("<style") && html.contains("role=\"img\"") && html.contains("aria-label=\""))
    }
}
