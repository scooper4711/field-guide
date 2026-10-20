import XCTest

/// On an iPhone, one screen at a time: the app starts on the categories, switching the system stays there, and a
/// category opens its list, whose Search Everything button opens the search sheet.
final class PhoneNavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "Only an iPhone shows one screen at a time.")
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testStartsOnTheCategoriesAndStaysThereWhenSwitchingSystems() {
        let spells = app.buttons["Spells"]
        XCTAssertTrue(spells.waitForExistence(timeout: 15), app.debugDescription)

        app.buttons["Starfinder"].tap()
        XCTAssertTrue(app.navigationBars["Field Guide"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Pathfinder"].tap()
        XCTAssertTrue(app.navigationBars["Field Guide"].waitForExistence(timeout: 5), app.debugDescription)

        spells.tap()
        XCTAssertTrue(app.navigationBars["Spells"].waitForExistence(timeout: 10), app.debugDescription)
    }

    func testTheListsSearchEverythingOpensTheSheet() {
        let spells = app.buttons["Spells"]
        XCTAssertTrue(spells.waitForExistence(timeout: 15), app.debugDescription)
        spells.tap()
        app.buttons["Search Everything"].tap()
        let field = app.searchFields["Search Everything"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), app.debugDescription)
        field.typeText("fireball")
        let fireball = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Fireball")).firstMatch
        XCTAssertTrue(fireball.waitForExistence(timeout: 10), app.debugDescription)
        fireball.tap()
        XCTAssertTrue(app.navigationBars["Fireball"].waitForExistence(timeout: 10), app.debugDescription)
    }
}
