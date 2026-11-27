import XCTest

/// The Organized Play guides from Lorespire: their list reads in guide order under each part, and their links open
/// other guide pages in the app. The guide's wording changes on Lorespire, so the tests rely only on its page names.
final class OrganizedPlayUITests: XCTestCase {
    private static let coreGuide = "lorespire.pf2e.pfs2guide"
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    func testTheListShowsTheGuideUnderItsPartsInLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "Only an iPad shows the list beside a page.")
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launch()
        openOrganizedPlay()
        // The list starts with the Introduction's pages, then the Core Guide's.
        let rules = app.staticTexts["Campaign Rules Outside the Guide"]
        XCTAssertTrue(rules.waitForExistence(timeout: 10), app.debugDescription)
        let welcome = app.staticTexts["Welcome to Pathfinder Society"]
        XCTAssertTrue(welcome.exists, app.debugDescription)
        XCTAssertLessThan(rules.frame.minY, welcome.frame.minY, "The guide's pages are out of order.")
    }

    func testTheListShowsTheGuideInPortrait() {
        XCUIDevice.shared.orientation = .portrait
        app.launch()
        openOrganizedPlay()
        XCTAssertTrue(app.staticTexts["Welcome to Pathfinder Society"].waitForExistence(timeout: 10),
                      app.debugDescription)
    }

    func testALinkOpensAnotherGuidePage() {
        XCUIDevice.shared.orientation = .landscapeLeft
        app.launchEnvironment["FIELD_GUIDE_SELECT"] = Self.coreGuide
        app.launch()
        let welcome = app.webViews.links["Welcome to Pathfinder Society"].firstMatch
        XCTAssertTrue(welcome.waitForExistence(timeout: 15), app.debugDescription)
        welcome.tap()
        // The Welcome page holds the link to its own first page.
        let organizedPlay = app.webViews.links["What is Paizo Organized Play?"].firstMatch
        XCTAssertTrue(organizedPlay.waitForExistence(timeout: 20), app.debugDescription)
    }

    /// Taps the category in the sidebar, which portrait shows first when nothing is chosen.
    private func openOrganizedPlay() {
        let category = app.staticTexts["Organized Play"].firstMatch
        XCTAssertTrue(category.waitForExistence(timeout: 15), app.debugDescription)
        category.tap()
    }
}
