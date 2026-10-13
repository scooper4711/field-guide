import XCTest

/// Ancestries and classes have their overview and, from the rules journals, their Details; links to a journal page
/// open its entry's Details.
final class EntryTabsUITests: XCTestCase {
    private static let fighter = "Compendium.pf2e.classes.Item.8zn3cD6GSmoo1LW4"
    private static let ancestryIndex =
        "Compendium.pf2e.journals.JournalEntry.45SK8rdbbxvEHfMn.JournalEntryPage.yqgXircyvQ2e56X5"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testClassShowsItsOverviewThenItsDetails() {
        launch(Self.fighter)
        // The overview lists the class features; the Details spell out the key attribute in capitals.
        XCTAssertTrue(webText(containing: "Battlefield Surveyor").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(webText(containing: "STRENGTH OR DEXTERITY").exists)
        app.segmentedControls.buttons["Details"].tap()
        XCTAssertTrue(webText(containing: "STRENGTH OR DEXTERITY").waitForExistence(timeout: 10), app.debugDescription)
    }

    func testLinkToAJournalPageOpensItsEntrysDetails() {
        launch(Self.ancestryIndex)
        let dwarf = app.webViews.links["Dwarf"].firstMatch
        XCTAssertTrue(dwarf.waitForExistence(timeout: 15), app.debugDescription)
        dwarf.tap()
        XCTAssertTrue(webText(containing: "well-earned reputation").waitForExistence(timeout: 10),
                      app.debugDescription)
        XCTAssertTrue(app.segmentedControls.buttons["Details"].isSelected)
    }

    private func launch(_ entry: String) {
        app.launchEnvironment["FIELD_GUIDE_SELECT"] = entry
        app.launch()
    }

    private func webText(containing fragment: String) -> XCUIElement {
        app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}
