import XCTest

final class MainNavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-authenticated"]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }

    func testAuthenticatedLaunchShowsMainTabsAndOpensProfile() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

        let repositoriesTab = tabBar.buttons["仓库"]
        let profileTab = tabBar.buttons["我的"]
        XCTAssertTrue(repositoriesTab.exists)
        XCTAssertTrue(profileTab.exists)

        profileTab.tap()

        XCTAssertTrue(app.navigationBars["我的"].waitForExistence(timeout: 5))
        XCTAssertTrue(tabBar.exists)
        XCTAssertTrue(repositoriesTab.exists)
    }
}
