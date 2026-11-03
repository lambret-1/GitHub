import XCTest
@testable import GitHub

final class ModelDecodingTests: XCTestCase {
    func testRepositoryDecodesGitHubSnakeCaseFields() throws {
        let json = Data("""
        {
          "id": 42,
          "name": "sample",
          "full_name": "octocat/sample",
          "private": true,
          "html_url": "https://github.com/octocat/sample",
          "default_branch": "main",
          "stargazers_count": 12,
          "forks_count": 3,
          "owner": {
            "login": "octocat",
            "id": 7,
            "avatar_url": "https://example.com/avatar.png"
          },
          "permissions": {
            "admin": false,
            "push": true,
            "pull": true
          },
          "fork": true
        }
        """.utf8)

        let repository = try JSONDecoder().decode(Repository.self, from: json)

        XCTAssertEqual(repository.id, 42)
        XCTAssertEqual(repository.fullName, "octocat/sample")
        XCTAssertTrue(repository.isPrivate)
        XCTAssertEqual(repository.defaultBranch, "main")
        XCTAssertEqual(repository.ownerName, "octocat")
        XCTAssertEqual(repository.当前权限, .write)
        XCTAssertTrue(repository.可写)
        XCTAssertTrue(repository.是Fork)
    }

    func testRepositoryPermissionFallsBackToNoneWhenMissing() throws {
        let json = Data("""
        {
          "id": 1,
          "name": "repo",
          "full_name": "owner/repo",
          "private": false,
          "html_url": "https://github.com/owner/repo",
          "owner": {
            "login": "owner",
            "id": 2,
            "avatar_url": "https://example.com/avatar.png"
          }
        }
        """.utf8)

        let repository = try JSONDecoder().decode(Repository.self, from: json)

        XCTAssertEqual(repository.当前权限, .none)
        XCTAssertFalse(repository.可写)
        XCTAssertFalse(repository.是Fork)
    }

    func testCodeSearchResponseDecodesNestedRepository() throws {
        let json = Data("""
        {
          "total_count": 1,
          "items": [{
            "name": "README.md",
            "path": "docs/README.md",
            "sha": "abc123",
            "url": "https://api.github.com/repos/owner/repo/contents/docs/README.md",
            "git_url": "https://api.github.com/repos/owner/repo/git/blobs/abc123",
            "html_url": "https://github.com/owner/repo/blob/main/docs/README.md",
            "repository": {
              "id": 9,
              "name": "repo",
              "full_name": "owner/repo",
              "private": false,
              "html_url": "https://github.com/owner/repo",
              "owner": {
                "login": "owner",
                "id": 2,
                "avatar_url": "https://example.com/avatar.png"
              }
            }
          }]
        }
        """.utf8)

        let response = try JSONDecoder().decode(CodeSearchResponse.self, from: json)
        let item = try XCTUnwrap(try JSONDecoder().decode([CodeSearchItem].self, from: jsonObjectItems(from: json)).first)

        XCTAssertEqual(response.totalCount, 1)
        XCTAssertEqual(response.items.first?.path, "docs/README.md")
        XCTAssertEqual(item.id, "abc123")
        XCTAssertEqual(item.repository.ownerName, "owner")
    }

    func testGitHubAPIErrorDecodesDocumentationURL() throws {
        let json = Data("""
        {"message":"Not Found","documentation_url":"https://docs.github.com/rest"}
        """.utf8)

        let error = try JSONDecoder().decode(GitHubAPIError.self, from: json)

        XCTAssertEqual(error.message, "Not Found")
        XCTAssertEqual(error.documentationUrl, "https://docs.github.com/rest")
    }

    private func jsonObjectItems(from data: Data) throws -> Data {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let items = try XCTUnwrap(object["items"])
        return try JSONSerialization.data(withJSONObject: items)
    }
}
