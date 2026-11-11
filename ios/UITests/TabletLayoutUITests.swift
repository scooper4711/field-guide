import XCTest

/// On an iPad the columns get a compact width of their own, yet the app keeps its iPad layout: in landscape, where
/// the list shows from the start, it has the system switch.
final class TabletLayoutUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Only an iPad shows several columns.")
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTheListHasTheSystemSwitch() {
        let system = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "System")).firstMatch
        XCTAssertTrue(system.waitForExistence(timeout: 15), app.debugDescription)
    }

    /// In portrait the side columns are hidden by default, which with nothing chosen left only an empty page (#42).
    func testPortraitWithNothingChosenShowsTheCategories() {
        app.terminate()
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        // On the iPad the categories are rows of text in the sidebar.
        let bestiary = app.staticTexts["Bestiary"]
        XCTAssertTrue(bestiary.waitForExistence(timeout: 15), app.debugDescription)
        XCTAssertTrue(bestiary.isHittable, "The categories are there but covered or off screen.")
    }
}
