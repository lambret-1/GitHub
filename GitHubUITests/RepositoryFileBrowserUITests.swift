import XCTest

final class RepositoryFileBrowserUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            "-ui-testing",
            "-ui-testing-authenticated",
            "-ui-testing-repository-fixtures",
            "-ui-testing-filebrowser-fixtures"
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

    func testRepositoryDetailLoadsLocalFilesWithoutNetwork() {
        let repository = app.staticTexts["repo.row.swift-client"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10))
        repository.tap()

        XCTAssertTrue(app.buttons["file.row.Sources"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["file.row.README.md"].exists)
        XCTAssertTrue(app.buttons["file.row.Package.swift"].exists)
    }

    func testNestedDirectoryNavigationAndBreadcrumbReturnToRoot() {
        let repository = app.staticTexts["repo.row.swift-client"]
        XCTAssertTrue(repository.waitForExistence(timeout: 10))
        repository.tap()

        let sources = app.buttons["file.row.Sources"]
        XCTAssertTrue(sources.waitForExistence(timeout: 10))
        sources.tap()

        XCTAssertTrue(app.buttons["file.row.App.swift"].waitForExistence(timeout: 5))
        let components = app.buttons["file.row.Components"]
        XCTAssertTrue(components.exists)
        components.tap()

        XCTAssertTrue(app.buttons["file.row.Button.swift"].waitForExistence(timeout: 5))
        let sourcesBreadcrumb = app.buttons["file.path.component.Sources"]
        XCTAssertTrue(sourcesBreadcrumb.exists)
        sourcesBreadcrumb.tap()

        XCTAssertTrue(app.buttons["file.row.App.swift"].waitForExistence(timeout: 5))
        app.buttons["file.path.root"].tap()
        XCTAssertTrue(app.buttons["file.row.Sources"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["file.row.README.md"].exists)
    }
}
