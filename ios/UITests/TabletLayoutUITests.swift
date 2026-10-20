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
}
