import Foundation

// MARK: - 代码搜索结果模型

/// 代码搜索结果项
struct CodeSearchItem: Codable, Identifiable {
    let id: String
    let name: String
    let path: String
    let sha: String
    let url: String
    let gitUrl: String
    let htmlUrl: String
    let repository: Repository

    enum CodingKeys: String, CodingKey {
        case id = "node_id"
        case name
        case path
        case sha
        case url
        case gitUrl = "git_url"
        case htmlUrl = "html_url"
        case repository
    }
}

/// 代码搜索结果包装
struct CodeSearchResult: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [CodeSearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
