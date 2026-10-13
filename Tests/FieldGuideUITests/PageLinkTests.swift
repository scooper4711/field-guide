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

    @Test("The tabs read as Overview and Details")
    func tabTitles() {
        #expect(EntryTab.allCases.map(\.title) == ["Overview", "Details"])
    }
}
