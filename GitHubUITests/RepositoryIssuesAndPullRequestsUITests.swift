import XCTest

final class RepositoryIssuesAndPullRequestsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-authenticated",
            "-ui-testing-repository-fixtures",
            "-ui-testing-filebrowser-fixtures",
            "-ui-testing-issues-fixtures",
            "-ui-testing-pull-request-fixtures"
        ]
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

    func testIssueStateFiltersUseLocalFixtures() {
        openRepository()
        app.buttons["repo.tab.Issues"].tap()

        XCTAssertTrue(app.staticTexts["issue.row.1"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["issue.row.2"].exists)

        let statePicker = app.segmentedControls["issues.statePicker"]
        XCTAssertTrue(statePicker.waitForExistence(timeout: 5))
        statePicker.buttons["已关闭"].tap()
        XCTAssertTrue(app.staticTexts["issue.row.2"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["issue.row.1"].exists)

        statePicker.buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts["issue.row.1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["issue.row.2"].exists)
    }

    func testPullRequestStateFiltersUseLocalFixtures() {
        openRepository()
        app.buttons["repo.tab.Pull Requests"].tap()

        XCTAssertTrue(app.staticTexts["pullRequest.row.11"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["pullRequest.row.12"].exists)

        let statePicker = app.segmentedControls["pullRequests.statePicker"]
        XCTAssertTrue(statePicker.waitForExistence(timeout: 5))
        statePicker.buttons["已关闭"].tap()
        XCTAssertTrue(app.staticTexts["pullRequest.row.12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["pullRequest.row.11"].exists)

        statePicker.buttons["全部"].tap()
        XCTAssertTrue(app.staticTexts["pullRequest.row.11"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["pullRequest.row.12"].exists)
    }

    func testIssueCreateSheetCanBeCancelledWithoutNetwork() {
        openRepository()
        app.buttons["repo.tab.Issues"].tap()
        app.buttons["issues.createButton"].tap()

        XCTAssertTrue(app.navigationBars["新建Issue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["创建"].isEnabled)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.segmentedControls["issues.statePicker"].waitForExistence(timeout: 5))
    }

    func testPullRequestCreateSheetCanBeCancelledWithoutNetwork() {
        openRepository()
        app.buttons["repo.tab.Pull Requests"].tap()
        app.buttons["pullRequests.createButton"].tap()

        XCTAssertTrue(app.navigationBars["新建Pull Request"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["创建"].isEnabled)
        app.buttons["取消"].tap()
        XCTAssertTrue(app.segmentedControls["pullRequests.statePicker"].waitForExistence(timeout: 5))
    }

    private func openRepository() {
        let repository = app.staticTexts["repo.row.swift-client"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10))
        repository.tap()
        XCTAssertTrue(app.buttons["repo.tab.Issues"].waitForExistence(timeout: 10))
    }
}
