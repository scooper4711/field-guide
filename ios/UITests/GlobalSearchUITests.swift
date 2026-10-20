import XCTest

/// The sidebar's search across every category: matches grouped by category open their entry, and Show All opens
/// the category's list searched the same way.
final class GlobalSearchUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testAMatchOpensItsEntry() {
        search("fireball")
        let fireball = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Fireball")).firstMatch
        XCTAssertTrue(fireball.waitForExistence(timeout: 10), app.debugDescription)
        fireball.tap()
        XCTAssertTrue(app.navigationBars["Fireball"].waitForExistence(timeout: 10), app.debugDescription)
    }

    func testShowAllOpensTheCategorySearchedTheSameWay() {
        search("fire")
        let showAll = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Show All")).firstMatch
        // On an iPhone the first group's matches fill the screen above the keyboard.
        for _ in 0..<5 where !showAll.waitForExistence(timeout: 2) {
            scrollAboveTheKeyboard()
        }
        XCTAssertTrue(showAll.waitForExistence(timeout: 10), app.debugDescription)
        showAll.tap()
        XCTAssertTrue(app.searchFields["Search names"].waitForExistence(timeout: 10), app.debugDescription)
        XCTAssertEqual(app.searchFields["Search names"].value as? String, "fire")
    }

    /// Drags the matches up from just above the middle of the screen, where the keyboard isn't.
    private func scrollAboveTheKeyboard() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
    }

    /// From the list's Search Everything button, which shows the sidebar's search wherever the sidebar was; an
    /// iPhone starts on the categories screen, which has the search field itself.
    private func search(_ text: String) {
        let field = app.searchFields["Search Everything"]
        if !field.waitForExistence(timeout: 5) {
            let button = app.buttons["Search Everything"]
            XCTAssertTrue(button.waitForExistence(timeout: 15), app.debugDescription)
            button.tap()
        }
        field.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10), app.debugDescription)
        field.typeText(text)
    }
}
