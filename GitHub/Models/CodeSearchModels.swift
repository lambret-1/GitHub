import Foundation

// 搜索状态
enum SearchState {
    case idle
    case searching
    case success
    case empty
    case error(String)
}

// 搜索排序选项
enum CodeSearchSortOption: String, CaseIterable, Identifiable {
    case updated = "更新时间"
    case path = "文件路径"
    case relevance = "相关性"

    var id: String { rawValue }

    // 排序描述
    var description: String {
        switch self {
        case .updated: return "按文件最后更新时间降序排列"
        case .path: return "按文件路径字母顺序排列"
        case .relevance: return "按搜索相关性排列（GitHub默认）"
        }
    }
}

// 搜索历史记录
struct SearchHistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let query: String
    let timestamp: Date

    init(query: String) {
        self.id = UUID()
        self.query = query
        self.timestamp = Date()
    }
}

// 文件内容缓存项
struct FileContentCacheItem {
    let content: String
    let timestamp: Date
    let owner: String
    let repo: String
    let path: String
    let branch: String

    // 缓存是否过期（1分钟）
    var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 60
    }

    // 缓存key
    var cacheKey: String {
        "\(owner)/\(repo)/\(path)@\(branch)"
    }
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
