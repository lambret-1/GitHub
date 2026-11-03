import XCTest

final class RepoListInteractionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-authenticated", "-ui-testing-repository-fixtures"]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning { app.terminate() }
        app = nil
        try super.tearDownWithError()
    }

    func testSearchFiltersRepositoryNamesAndDescriptions() {
        let searchField = app.searchFields["repo.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["repo.row.swift-client"].exists)
        XCTAssertTrue(app.staticTexts["repo.row.python-tools"].exists)
        searchField.tap()
        searchField.typeText("design")
        XCTAssertTrue(app.staticTexts["repo.row.design-system"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["repo.row.swift-client"].exists)
        XCTAssertFalse(app.staticTexts["repo.row.python-tools"].exists)
    }

    func testVisibilityFiltersAndCombinedSearch() {
        let privateFilter = app.buttons["repo.filter.私有"]
        XCTAssertTrue(privateFilter.waitForExistence(timeout: 10))
        privateFilter.tap()
        XCTAssertTrue(app.staticTexts["repo.row.swift-client"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["repo.row.python-tools"].exists)
        XCTAssertFalse(app.staticTexts["repo.row.design-system"].exists)
        app.buttons["repo.filter.公开"].tap()
        XCTAssertTrue(app.staticTexts["repo.row.python-tools"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["repo.row.design-system"].exists)
        XCTAssertFalse(app.staticTexts["repo.row.swift-client"].exists)
        let searchField = app.searchFields["repo.searchField"]
        searchField.tap()
        searchField.typeText("design")
        XCTAssertTrue(app.staticTexts["repo.row.design-system"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["repo.row.python-tools"].exists)
    }

    func testSearchMatchesRepositoryDescription() {
        let searchField = app.searchFields["repo.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Command line")
        XCTAssertTrue(app.staticTexts["repo.row.python-tools"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["repo.row.swift-client"].exists)
        XCTAssertFalse(app.staticTexts["repo.row.design-system"].exists)
    }

    func testSearchWithNoMatchesShowsEmptyState() {
        let searchField = app.searchFields["repo.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("no-such-repository")
        XCTAssertTrue(app.staticTexts["没有找到仓库"].waitForExistence(timeout: 3))
    }
}
