import Foundation

// 搜索状态
enum SearchState {
    case idle
    case searching
    case success
    case empty
    case error(String)
}

// 搜索结果项
struct CodeSearchFile: Identifiable, Codable {
    var id: String { sha }
    let name: String
    let path: String
    let sha: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case name, path, sha
        case htmlUrl = "html_url"
    }
}

// 搜索响应
struct CodeSearchResponse: Codable {
    let totalCount: Int
    let items: [CodeSearchFile]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

// 代码行
struct CodeLine: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let content: String
    let isMatch: Bool
}

// 代码片段
struct CodeSnippet: Identifiable {
    let id = UUID()
    let startLine: Int
    let endLine: Int
    let lines: [CodeLine]
}
