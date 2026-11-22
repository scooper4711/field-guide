import XCTest

/// The App Store's pictures of Valeros's battle card: tabletop-kit's `store-screenshots.sh`, with `STORE_DATA` naming
/// a copy of the app's data that has him in it and `STORE_ART` his Community Use art.
final class StoreScreenshots: XCTestCase {
    private static let valeros = "Compendium.pf2e.iconics.Actor.valeros"
    private var app: XCUIApplication!
    private var folder: URL!

    override func setUpWithError() throws {
        let environment = ProcessInfo.processInfo.environment
        let path = environment["SCREENSHOT_DIR"] ?? "", data = environment["STORE_DATA"] ?? ""
        try XCTSkipIf(path.isEmpty || data.isEmpty, "Set SCREENSHOT_DIR and STORE_DATA to make the store screenshots.")
        folder = URL(fileURLWithPath: path)
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchEnvironment["FIELD_GUIDE_DATA"] = data
        app.launchEnvironment["FIELD_GUIDE_STORE_ART"] = environment["STORE_ART"] ?? ""
        app.launchEnvironment["FIELD_GUIDE_SELECT"] = Self.valeros
        app.launchArguments = ["-creatureView", "card"]
    }

    func testValerosCard() throws {
        app.launch()
        let hitPoints = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "HP 47")).firstMatch
        XCTAssertTrue(hitPoints.waitForExistence(timeout: 30), app.debugDescription)
        let status = app.staticTexts["Looking for new sourcebooks…"]
        XCTAssertTrue(status.waitForNonExistence(timeout: 90), "The sourcebook check is still on screen")
        try save("0-valeros-card")
        hitPoints.tap()
        let turnOver = app.buttons["Flip Card"]
        XCTAssertTrue(turnOver.waitForExistence(timeout: 5), app.debugDescription)
        turnOver.tap()
        Thread.sleep(forTimeInterval: 2)
        try save("0-valeros-art")
    }

    private func save(_ name: String) throws {
        Thread.sleep(forTimeInterval: 1.5)
        let file = folder.appendingPathComponent("\(name).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: file)
    }
}
