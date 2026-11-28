import FieldGuideKit
import Testing
@testable import FieldGuideUI

@Suite("Back, like a browser's")
@MainActor
struct EntryNavigatorTests {
    @Test("Open shows the entry in its category at its heading, and Back returns to the entry and pages left")
    func openAndBack() throws {
        let store = try CatalogStoreTests.store()
        store.addedEntries = [CatalogStoreTests.custom("Spike Pit", .hazards)]
        store.category = .hazards
        let navigator = EntryNavigator(selection: "custom.Spike Pit")
        navigator.path = [.trait("fire", .pathfinder)]
        let link = PageLink.entry("Ogre", anchor: "Tactics")
        #expect(navigator.open(link, in: store))
        #expect(store.category == .bestiary && navigator.selection == "Ogre" && navigator.root == link)
        #expect(navigator.path.isEmpty && navigator.canGoBack)
        navigator.goBack(in: store)
        #expect(store.category == .hazards && navigator.selection == "custom.Spike Pit")
        #expect(navigator.path == [.trait("fire", .pathfinder)] && navigator.root == nil)
        navigator.goBack(in: store)
        #expect(navigator.path.isEmpty && !navigator.canGoBack)
        navigator.goBack(in: store)
        #expect(navigator.selection == "custom.Spike Pit")
    }

    @Test("Choosing in the list is history too; a trait's link and an unknown entry don't open")
    func choosing() throws {
        let store = try CatalogStoreTests.store()
        store.category = .bestiary
        let navigator = EntryNavigator(selection: nil)
        navigator.selection = "Goblin"
        #expect(!navigator.canGoBack)
        navigator.selection = "Ogre"
        #expect(!navigator.open(.trait("fire", .pathfinder), in: store) && !navigator.open(.entry("Nobody"), in: store))
        #expect(navigator.history.map(\.id) == ["Goblin"])
        navigator.goBack(in: store)
        #expect(navigator.selection == "Goblin" && navigator.history.isEmpty)
        navigator.selection = "Ogre"
        navigator.forget()
        #expect(!navigator.canGoBack)
    }

    @Test("An entry left at a heading comes back at it")
    func keepsTheHeading() throws {
        let store = try CatalogStoreTests.store()
        let navigator = EntryNavigator(selection: "Goblin")
        let link = PageLink.entry("Ogre", .overview, anchor: "Tactics")
        #expect(navigator.open(link, in: store))
        navigator.selection = "Goblin"
        navigator.goBack(in: store)
        #expect(navigator.selection == "Ogre" && navigator.root == link)
    }
}
