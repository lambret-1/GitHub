import XCTest

final class StarredReposUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-ui-testing-authenticated", "-ui-testing-starred-fixtures"]
        app.launchEnvironment["UI_TESTING"] = "1"
        app.launch()
        let repositoriesTab = app.tabBars.buttons["仓库"]
        XCTAssertTrue(repositoriesTab.waitForExistence(timeout: 10))
        repositoriesTab.tap()
        let starredButton = app.buttons["repo.starredButton"]
        XCTAssertTrue(starredButton.waitForExistence(timeout: 5))
        starredButton.tap()
    }

    override func tearDownWithError() throws {
        if let app = app, app.state != .notRunning {
            app.terminate()
        }
        app = nil
        try super.tearDownWithError()
    }

    func testStarredListLoadsLocalFixturesWithoutNetwork() {
        XCTAssertTrue(app.staticTexts["starred.row.swift-foundation"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["starred.row.python-cli"].exists)
        XCTAssertTrue(app.staticTexts["starred.row.design-system"].exists)
    }

    func testOwnAndOthersFilters() {
        let ownFilter = app.buttons["starred.filter.自己的"]
        XCTAssertTrue(ownFilter.waitForExistence(timeout: 10))
        ownFilter.tap()
        XCTAssertTrue(app.staticTexts["starred.row.swift-foundation"].exists)
        XCTAssertFalse(app.staticTexts["starred.row.python-cli"].exists)
        XCTAssertFalse(app.staticTexts["starred.row.design-system"].exists)

        app.buttons["starred.filter.别人的"].tap()
        XCTAssertTrue(app.staticTexts["starred.row.python-cli"].exists)
        XCTAssertTrue(app.staticTexts["starred.row.design-system"].exists)
        XCTAssertFalse(app.staticTexts["starred.row.swift-foundation"].exists)
    }

    func testSearchMatchesRepositoryDescription() {
        let searchField = app.textFields["starred.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("Command line")
        XCTAssertTrue(app.staticTexts["starred.row.python-cli"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["starred.row.swift-foundation"].exists)
        XCTAssertFalse(app.staticTexts["starred.row.design-system"].exists)
    }

    func testSearchWithNoMatchesShowsEmptyState() {
        let searchField = app.textFields["starred.searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 10))
        searchField.tap()
        searchField.typeText("not-a-starred-repository")
        XCTAssertTrue(app.staticTexts["没有找到匹配的仓库"].waitForExistence(timeout: 3))
    }
}
