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
    func testHomeMenuOpensSidebarAndNavigatesToArchive() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_VISUAL_SCENARIO"] = "home"
        app.launch()

        let menu = app.buttons["app.menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(menu.frame.width, 44)
        XCTAssertGreaterThanOrEqual(menu.frame.height, 44)
        menu.tap()

        XCTAssertTrue(element("screen.menu", in: app).waitForExistence(timeout: 5))
        app.buttons["menu.archive"].tap()
        XCTAssertTrue(element("screen.archive", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(element("screen.menu", in: app).exists)
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
    func testRecordCategoryVisualScenarioOpensReviewedStepDirectly() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_VISUAL_SCENARIO"] = "record-category"
        app.launch()

        XCTAssertTrue(element("screen.record.category", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["record.category.food"].isHittable)
    }

    @MainActor
    func testRecordAmountVisualScenarioOpensReviewedDraftDirectly() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_VISUAL_SCENARIO"] = "record-amount"
        app.launch()

        XCTAssertTrue(element("screen.record.amount", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["record.amount"].label, "금액 ₩18,900")
        for identifier in ["record.back", "record.delete", "record.digit.0", "record.submit"] {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(button.frame.width, 44)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44)
            XCTAssertTrue(button.isHittable)
        }
    }

    @MainActor
    func testRecordFeatureFlowFromCenterAddReturnsToHomeOnce() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_FEATURE_SCENARIO"] = "record"
        app.launch()

        let homeRecord = app.buttons["home.record"]
        XCTAssertTrue(homeRecord.waitForExistence(timeout: 5))
        homeRecord.tap()
        XCTAssertTrue(element("screen.record.category", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("record.category.prompt", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["record.category.food"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tab.home"].isSelected)
        XCTAssertTrue(
            occupiesLargeSheet(identifier: "screen.record.category", in: app),
            "category and amount capture should fill most of the screen"
        )

        app.buttons["record.category.food"].tap()
        XCTAssertFalse(element("record.category.prompt", in: app).exists)
        XCTAssertTrue(app.buttons["record.digit.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["record.clear"].waitForExistence(timeout: 5))
        for digit in ["1", "8", "9", "0", "0"] {
            app.buttons["record.digit.\(digit)"].tap()
        }
        let submit = app.buttons["record.submit"]
        XCTAssertEqual(submit.label, "저장하기")
        XCTAssertNotEqual(submit.label, "저장 중")
        submit.tap()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.total"].label, "₩62,100")
        XCTAssertTrue(element("home.placeholder.featured.22222222-2222-4222-8222-222222222222", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("home.placeholder.recent.22222222-2222-4222-8222-222222222222", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["screen.record"].exists)
        let add = app.buttons["tab.add"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(add.frame.width, 44)
        XCTAssertGreaterThanOrEqual(add.frame.height, 44)
    }

    @MainActor
    func testUnknownFeatureScenarioFailsClosed() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_FEATURE_SCENARIO"] = "unknown"
        app.launch()

        XCTAssertTrue(element("screen.visual-launch-failure", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tab.home"].exists)
    }

    @MainActor
    func testRecordRetryKeepsActionsReachableAtAccessibilityExtraExtraExtraLarge() {
        let app = XCUIApplication()
        app.launchEnvironment["MONEYSNAP_FEATURE_SCENARIO"] = "record-retry"
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        ]
        app.launch()

        let homeRecord = app.buttons["home.record"]
        XCTAssertTrue(homeRecord.waitForExistence(timeout: 5))
        XCTAssertEqual(homeRecord.label, "기록하기")
        XCTAssertTrue(homeRecord.isHittable)
        homeRecord.tap()

        let lastCategory = app.buttons["record.category.other"]
        XCTAssertTrue(lastCategory.waitForExistence(timeout: 5))
        XCTAssertTrue(makeHittable(lastCategory, in: app))

        let category = app.buttons["record.category.food"]
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        XCTAssertEqual(category.label, "식비")
        XCTAssertTrue(makeHittable(category, in: app, towardBottom: false))
        category.tap()

        for digit in ["1", "8", "9", "0", "0"] {
            let button = app.buttons["record.digit.\(digit)"]
            XCTAssertTrue(makeHittable(button, in: app))
            XCTAssertEqual(button.label, digit)
            button.tap()
        }

        let submit = app.buttons["record.submit"]
        XCTAssertTrue(makeHittable(submit, in: app))
        XCTAssertEqual(submit.label, "저장하기")
        submit.tap()

        let abandon = app.buttons["record.abandon"]
        let retry = app.buttons["record.retry"]
        XCTAssertTrue(abandon.waitForExistence(timeout: 5))
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertEqual(abandon.label, "기록 포기")
        XCTAssertEqual(retry.label, "같은 기록 다시 확인")
        XCTAssertTrue(makeHittable(abandon, in: app, towardBottom: false))
        XCTAssertTrue(makeHittable(retry, in: app))
        retry.tap()

        XCTAssertTrue(element("screen.home", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["home.total"].label, "₩62,100")
    }

    @MainActor
    private func makeHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        towardBottom: Bool = true
    ) -> Bool {
        guard element.waitForExistence(timeout: 5) else { return false }
        for _ in 0..<5 where !element.isHittable {
            if towardBottom {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
        }
        return element.isHittable
    }

    @MainActor
    private func occupiesLargeSheet(identifier: String, in app: XCUIApplication) -> Bool {
        let window = app.windows.firstMatch.frame
        let matches = app.descendants(matching: .any).matching(identifier: identifier)
        guard matches.firstMatch.waitForExistence(timeout: 5) else { return false }
        return (0..<matches.count).contains { index in
            let frame = matches.element(boundBy: index).frame
            return frame.height >= window.height * 0.72
                && frame.width >= window.width * 0.9
        }
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
