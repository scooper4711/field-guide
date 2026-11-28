import XCTest

/// A link to another entry opens it in a popover beside the link; the popover's Open shows the entry as if chosen in
/// the sidebar, and Back returns to the page the link was on.
final class LinkPopoverUITests: XCTestCase {
    /// The Fear spell, whose outcomes link to the Frightened and Fleeing conditions.
    private static let fear = "Compendium.pf2e.spells-srd.Item.4koZzrnMXhhosn0D"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["FIELD_GUIDE_SELECT"] = Self.fear
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testOpenAndBackInLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        openFrightenedAndGoBack()
    }

    func testOpenAndBackInPortrait() {
        XCUIDevice.shared.orientation = .portrait
        openFrightenedAndGoBack()
    }

    private func openFrightenedAndGoBack() {
        app.launch()
        let link = app.webViews.links["Frightened 1"].firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 15), app.debugDescription)
        link.tap()
        let open = app.buttons["Open"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10), app.debugDescription)
        sleep(2)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "DEBUGSHOT"
        shot.lifetime = .keepAlways
        add(shot)
        // The spell's page stays under the popover.
        XCTAssertTrue(app.webViews.links["Fleeing"].firstMatch.exists, app.debugDescription)
        open.tap()
        XCTAssertTrue(open.waitForNonExistence(timeout: 10), app.debugDescription)
        XCTAssertFalse(app.webViews.links["Fleeing"].firstMatch.waitForExistence(timeout: 3), app.debugDescription)
        let back = app.buttons["Back"].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), app.debugDescription)
        back.tap()
        XCTAssertTrue(app.webViews.links["Fleeing"].firstMatch.waitForExistence(timeout: 15), app.debugDescription)
    }
}
