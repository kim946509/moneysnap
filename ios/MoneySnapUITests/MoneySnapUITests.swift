import XCTest

final class MoneySnapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeScenarioShowsReviewedTotalAndNavigatesToMy() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_VISUAL_SCENARIO"] = "home"
        app.launch()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        let total = app.staticTexts["home.total"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "₩43,200")

        let profileTab = app.buttons["tab.profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 5))
        profileTab.tap()

        XCTAssertTrue(element("screen.my", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testUnknownScenarioFailsClosed() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_VISUAL_SCENARIO"] = "unknown"
        app.launch()

        XCTAssertTrue(element("screen.visual-launch-failure", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.home"].exists)
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
