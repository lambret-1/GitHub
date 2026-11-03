import XCTest
@testable import GitHub

final class RepositoryPermissionTests: XCTestCase {
    func testAdminPermissionTakesPrecedence() {
        let permissions = RepoPermissions(
            admin: true,
            maintain: true,
            push: true,
            triage: true,
            pull: true
        )

        XCTAssertEqual(permissions.权限级别, .admin)
        XCTAssertTrue(permissions.权限级别.可写)
        XCTAssertTrue(permissions.权限级别.是管理员)
    }

    func testWritePermissionIsRecognized() {
        let permissions = RepoPermissions(
            admin: false,
            maintain: nil,
            push: true,
            triage: nil,
            pull: true
        )

        XCTAssertEqual(permissions.权限级别, .write)
        XCTAssertTrue(permissions.权限级别.可写)
        XCTAssertFalse(permissions.权限级别.是管理员)
    }

    func testReadOnlyPermissionIsNotWritable() {
        let permissions = RepoPermissions(
            admin: false,
            maintain: nil,
            push: false,
            triage: nil,
            pull: true
        )

        XCTAssertEqual(permissions.权限级别, .read)
        XCTAssertFalse(permissions.权限级别.可写)
    }

    func testWorkflowStateAndFileNamePresentation() {
        let workflow = Workflow(
            id: 42,
            name: "CI",
            path: ".github/workflows/ci.yml",
            state: "disabled_manually",
            createdAt: "2026-01-01T00:00:00Z",
            updatedAt: "2026-01-02T00:00:00Z",
            htmlUrl: "https://github.com/example/repo/actions",
            badgeUrl: "https://github.com/example/repo/workflows/ci.yml/badge.svg"
        )

        XCTAssertEqual(workflow.stateDisplay, "手动禁用")
        XCTAssertEqual(workflow.fileName, "ci.yml")
    }

    func testISO8601DateParserAcceptsWholeSecondsAndFractionalSeconds() {
        XCTAssertNotNil(parseDate("2026-01-02T03:04:05Z"))
        XCTAssertNotNil(parseDate("2026-01-02T03:04:05.123Z"))
        XCTAssertNil(parseDate("not-a-date"))
    }
}
