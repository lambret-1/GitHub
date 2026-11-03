import XCTest

final class LoginFlowUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
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

    func testLoginScreenShowsRequiredControls() {
        XCTAssertTrue(app.staticTexts["login.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.textFields["login.tokenField"].exists)
        XCTAssertTrue(app.buttons["login.tokenHelpButton"].exists)
        XCTAssertTrue(app.buttons["login.submitButton"].exists)
        XCTAssertFalse(app.buttons["login.submitButton"].isEnabled)
    }

    func testEnteringTokenEnablesLoginAndClearButtonResetsIt() {
        let tokenField = app.textFields["login.tokenField"]
        XCTAssertTrue(tokenField.waitForExistence(timeout: 10))
        tokenField.tap()
        tokenField.typeText("ghp_test_token")

        let loginButton = app.buttons["login.submitButton"]
        XCTAssertTrue(loginButton.isEnabled)
        XCTAssertTrue(app.buttons["login.clearToken"].exists)

        app.buttons["login.clearToken"].tap()

        XCTAssertFalse(loginButton.isEnabled)
        XCTAssertEqual(tokenField.value as? String, "请输入 GitHub 个人访问令牌")
    }

    func testTokenHelpCanExpandAndCollapse() {
        let helpButton = app.buttons["login.tokenHelpButton"]
        XCTAssertTrue(helpButton.waitForExistence(timeout: 10))

        helpButton.tap()
        XCTAssertTrue(app.staticTexts["login.tokenHelpContent"].waitForExistence(timeout: 3))

        helpButton.tap()
        XCTAssertFalse(app.staticTexts["login.tokenHelpContent"].exists)
    }
}
