import XCTest

/// A creature's page: its interactive battle card, whose linked words and traits open glossary popovers, and its
/// lore on a tab of its own.
final class BattleCardUITests: XCTestCase {
    private static let granitescale = "Compendium.pf2e.pathfinder-monster-core.Actor.MXSKccQqbQqQ77Ii"
    /// A creature with a battle card but no lore.
    private static let luckyLanks = "Compendium.pf2e.outlaws-of-alkenstar-bestiary.Actor.eBM6yUAHDyEp8Ewi"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testLinkedWordOpensItsGlossaryEntry() {
        launch(Self.granitescale)
        // Links inside a line aren't elements of their own, so this taps "longspear", the line's last word.
        let items = text(containing: "Items javelin")
        XCTAssertTrue(items.waitForExistence(timeout: 15), app.debugDescription)
        items.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        XCTAssertTrue(text(containing: "thrusting rather than throwing").waitForExistence(timeout: 10),
                      app.debugDescription)
    }

    func testTraitOpensItsGlossaryEntry() {
        launch(Self.granitescale)
        let humanoid = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "humanoid")).firstMatch
        XCTAssertTrue(humanoid.waitForExistence(timeout: 15), app.debugDescription)
        humanoid.tap()
        XCTAssertTrue(text(containing: "reason and act much like humans").waitForExistence(timeout: 10),
                      app.debugDescription)
    }

    func testTapShowsIconsThatFlipTheCardAndShowItFullScreen() {
        launch(Self.granitescale)
        XCTAssertFalse(app.buttons["Flip Card"].exists)
        tapEmptyCardArea()
        XCTAssertTrue(app.buttons["Flip Card"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Flip Card"].tap()
        XCTAssertTrue(app.buttons["Show Stat Block"].waitForExistence(timeout: 5), app.debugDescription)

        app.buttons["Full Screen"].tap()
        // Full screen opens with its icons hidden; a tap shows the one that closes it.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["Exit Full Screen"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Exit Full Screen"].tap()
        XCTAssertTrue(app.segmentedControls.buttons["Lore"].waitForExistence(timeout: 5), app.debugDescription)
    }

    func testLoreTabShowsTheLoreWithoutTheStatBlock() {
        launch(Self.granitescale, view: "lore")
        let lore = app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "shed scales"))
        XCTAssertTrue(lore.firstMatch.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.webViews.staticTexts["Perception"].exists)
        XCTAssertTrue(app.segmentedControls.buttons["Battle Card"].exists)
    }

    func testCreatureWithoutLoreShowsOnlyItsCard() {
        launch(Self.luckyLanks, view: "lore")
        XCTAssertTrue(text(containing: "LUCKY").waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertFalse(app.segmentedControls.buttons["Lore"].exists)
    }

    private func launch(_ entry: String, view: String = "card") {
        app.launchEnvironment["FIELD_GUIDE_SELECT"] = entry
        app.launchArguments = ["-creatureView", view]
        app.launch()
    }

    /// On card text that isn't linked, which a tap passes through to the card.
    private func tapEmptyCardArea() {
        let hitPoints = text(containing: "HP 120")
        XCTAssertTrue(hitPoints.waitForExistence(timeout: 15), app.debugDescription)
        hitPoints.tap()
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }
}
