import Foundation

// MARK: - 代码搜索结果模型

/// 代码搜索结果项
struct CodeSearchItem: Codable, Identifiable {
    // 使用sha作为唯一标识符（代码搜索API不返回node_id）
    var id: String { sha }
    let name: String
    let path: String
    let sha: String
    let url: String
    let gitUrl: String
    let htmlUrl: String
    let repository: CodeSearchRepository

    enum CodingKeys: String, CodingKey {
        case name, path, sha, url
        case gitUrl = "git_url"
        case htmlUrl = "html_url"
        case repository
    }
}

/// 代码搜索结果中的简化仓库模型（避免完整Repository模型的解码问题）
struct CodeSearchRepository: Codable {
    let id: Int
    let name: String
    let fullName: String
    let isPrivate: Bool
    let htmlUrl: String
    let owner: CodeSearchRepositoryOwner

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
        case isPrivate = "private"
        case htmlUrl = "html_url"
    }

    var ownerName: String {
        return owner.login
    }
}

/// 代码搜索结果中的简化仓库所有者模型
struct CodeSearchRepositoryOwner: Codable {
    let login: String
    let id: Int
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
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
