import XCTest
@testable import GitHub

final class APIEndpointTests: XCTestCase {
    func testRepositoryEndpointUsesOwnerAndRepositoryPath() {
        XCTAssertEqual(
            APIEndpoints.repository(owner: "octocat", repo: "hello-world").url,
            "https://api.github.com/repos/octocat/hello-world"
        )
    }

    func testWorkflowRunsEndpointIncludesPagination() {
        XCTAssertEqual(
            APIEndpoints.workflowRuns(owner: "octocat", repo: "hello-world", page: 2, perPage: 50).url,
            "https://api.github.com/repos/octocat/hello-world/actions/runs?page=2&per_page=50"
        )
    }

    func testCodeSearchInRepositoryScopesQueryToRepository() {
        let url = APIEndpoints.searchCodeInRepo(
            owner: "octocat",
            repo: "hello-world",
            query: "language:swift",
            page: 3
        ).url

        XCTAssertTrue(url.hasPrefix("https://api.github.com/search/code?q="))
        XCTAssertTrue(url.contains("repo%3Aoctocat%2Fhello-world"))
        XCTAssertTrue(url.contains("page=3&per_page=30"))
    }

    func testCreateRepositoryEndpointUsesRepositoriesCollection() {
        XCTAssertEqual(
            APIEndpoints.createRepository.url,
            "https://api.github.com/user/repos"
        )
    }
}
