import XCTest

final class AccountManagerUITests: XCTestCase {
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

        let accountManagerButton = app.buttons["profile.accountManagerButton"]
        XCTAssertTrue(accountManagerButton.waitForExistence(timeout: 10))
        accountManagerButton.tap()
        XCTAssertTrue(app.navigationBars["账号管理"].waitForExistence(timeout: 5))
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }

    func testAccountManagerDisplaysLocalFixtures() {
        XCTAssertTrue(app.staticTexts["@ui-tester"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@octo-community"].exists)
        XCTAssertTrue(app.staticTexts["@swift-labs"].exists)
        XCTAssertTrue(app.buttons["account.switch.octo-community"].exists)
        XCTAssertTrue(app.buttons["account.switch.swift-labs"].exists)
    }

    func testSwitchAccountUpdatesCurrentAccountInMemory() {
        let switchButton = app.buttons["account.switch.swift-labs"]
        XCTAssertTrue(switchButton.waitForExistence(timeout: 5))
        switchButton.tap()

        XCTAssertFalse(app.buttons["account.switch.swift-labs"].exists)
        XCTAssertTrue(app.staticTexts["@swift-labs"].exists)
        XCTAssertTrue(app.buttons["account.switch.ui-tester"].exists)
    }

    func testAddAccountUsesLocalFixtureWithoutNetwork() {
        let addButton = app.buttons["account.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let tokenField = app.secureTextFields["account.tokenField"]
        XCTAssertTrue(tokenField.waitForExistence(timeout: 5))
        tokenField.tap()
        tokenField.typeText("test-token")

        let createButton = app.buttons["验证并添加"]
        XCTAssertTrue(createButton.exists)
        createButton.tap()

        XCTAssertTrue(app.navigationBars["账号管理"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@ui-added"].waitForExistence(timeout: 5))
    }

    func testAddAccountSheetCanBeCancelledWithoutNetwork() {
        let addButton = app.buttons["account.addButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        XCTAssertTrue(app.staticTexts["添加 GitHub 账号"].waitForExistence(timeout: 5))
        let tokenField = app.secureTextFields["account.tokenField"]
        XCTAssertTrue(tokenField.exists)
        let cancelButton = app.buttons["account.cancelAddButton"]
        XCTAssertTrue(cancelButton.exists)
        cancelButton.tap()

        XCTAssertTrue(app.navigationBars["账号管理"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@ui-tester"].exists)
    }

    func testDeleteNonCurrentAccountFromContextMenu() {
        let accountName = app.staticTexts["@octo-community"]
        XCTAssertTrue(accountName.waitForExistence(timeout: 5))
        accountName.press(forDuration: 1.0)

        let deleteButton = app.buttons["account.delete.octo-community"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5))
        deleteButton.tap()

        XCTAssertFalse(app.staticTexts["@octo-community"].exists)
        XCTAssertTrue(app.staticTexts["@ui-tester"].exists)
    }
}
