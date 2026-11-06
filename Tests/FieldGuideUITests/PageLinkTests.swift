import FieldGuideKit
import Foundation
import SwiftUI
import Testing
@testable import FieldGuideUI

@Suite("Links from a page")
@MainActor
struct PageLinkTests {
    @Test("Entry links open the entry, Details links its Details, trait links the trait", arguments: [
        ("entry:Compendium.pf2e.classes.Item.fi1", PageLink?.some(.entry("Compendium.pf2e.classes.Item.fi1"))),
        ("entry:Compendium.pf2e.classes.Item.fi1#details", .entry("Compendium.pf2e.classes.Item.fi1", .details)),
        ("trait:fire", .trait("fire", .pathfinder)), ("https://example.com", nil)
    ])
    func links(url: String, link: PageLink?) throws {
        #expect(PageView.link(for: try #require(URL(string: url)), system: .pathfinder) == link)
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
