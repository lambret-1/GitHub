import XCTest

final class ProfileUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-authenticated",
            "-ui-testing-profile-fixtures"
        ]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
        let profileTab = app.tabBars.buttons["我的"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10))
        profileTab.tap()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }

    func testProfileDisplaysLocalFixtureWithoutNetwork() {
        XCTAssertTrue(app.staticTexts["profile.displayName"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["UI Test User"].exists)
        XCTAssertTrue(app.staticTexts["@ui-tester"].exists)
        XCTAssertTrue(app.staticTexts["本地 UI 自动化测试账号"].exists)
        XCTAssertTrue(app.staticTexts["34"].exists)
        XCTAssertTrue(app.staticTexts["12"].exists)
    }

    func testAboutNavigationAndBackToProfile() {
        let aboutButton = app.buttons["profile.aboutButton"]
        var aboutSwipeCount = 0
        while !aboutButton.exists && aboutSwipeCount < 5 {
            app.swipeUp()
            aboutSwipeCount += 1
        }
        XCTAssertTrue(aboutButton.waitForExistence(timeout: 10))
        aboutButton.tap()

        XCTAssertTrue(app.navigationBars["关于"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["版本信息"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@ui-tester"].exists)
    }

    func testLogoutCanBeCancelledWithoutLeavingProfile() {
        let logoutButton = app.buttons["profile.logoutButton"]
        var logoutSwipeCount = 0
        while !logoutButton.exists && logoutSwipeCount < 5 {
            app.swipeUp()
            logoutSwipeCount += 1
        }
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 10))
        logoutButton.tap()

        let cancelButton = app.alerts.buttons["取消"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3))
        cancelButton.tap()
        XCTAssertTrue(app.staticTexts["@ui-tester"].exists)
    }
}
