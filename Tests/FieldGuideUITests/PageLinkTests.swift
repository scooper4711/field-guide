import FieldGuideKit
import Foundation
import SwiftUI
import Testing
@testable import FieldGuideUI

@Suite("Links from a page")
@MainActor
struct PageLinkTests {
    @Test("Entry links open the entry, Details links its Details, trait links the trait", arguments: [
        ("entry:Compendium.pf2e.classes.Item.fi1", PageLink.entry("Compendium.pf2e.classes.Item.fi1")),
        ("entry:Compendium.pf2e.classes.Item.fi1#details", .entry("Compendium.pf2e.classes.Item.fi1", .details)),
        ("trait:fire", .trait("fire", .pathfinder))
    ])
    func pageLinks(url: String, link: PageLink) throws {
        #expect(PageView.destination(for: try #require(URL(string: url)), system: .pathfinder) == .page(link))
    }

    @Test("Web and mail links open in the browser", arguments: [
        "https://paizo.com/community/communityuse", "http://example.com/page", "HTTPS://example.com",
        "mailto:someone@example.com"
    ])
    func browserLinks(url: String) throws {
        let link = try #require(URL(string: url))
        #expect(PageView.destination(for: link, system: .pathfinder) == .browser(link))
    }

    @Test("Other schemes are ignored", arguments: ["javascript:alert(1)", "file:///etc/hosts", "fieldguide:///x"])
    func ignoredLinks(url: String) throws {
        #expect(PageView.destination(for: try #require(URL(string: url)), system: .pathfinder) == .ignored)
    }

    @Test("The tabs read as Overview, Details and Lore")
    func tabTitles() {
        #expect(EntryTab.allCases.map(\.title) == ["Overview", "Details", "Lore"])
    }
}

@Suite("Fitting a battle card to its column")
@MainActor
struct FittedCardTests {
    @Test("The card grows to fill a wide column and shrinks to fit a narrow one", arguments: [
        (CGFloat(880), CGFloat(2)), (440, 1), (220, 0.5), (0, 1)
    ])
    func scale(width: CGFloat, scale: CGFloat) {
        #expect(FittedCard<EmptyView>.scale(toFit: width) == scale)
    }
}
