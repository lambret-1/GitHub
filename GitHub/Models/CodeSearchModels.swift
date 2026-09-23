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
    // 最后编辑时间（搜索API不返回，需要额外通过commits API获取）
    var lastModified: Date?

    enum CodingKeys: String, CodingKey {
        case name, path, sha
        case htmlUrl = "html_url"
    }

    // 相对时间显示：xx分钟/小时/日/月/年之前
    var lastModifiedRelativeString: String {
        guard let date = lastModified else {
            return "未知时间"
        }
        return date.relativeTimeString
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

// GitHub API错误响应模型
struct GitHubAPIError: Codable {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
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

// MARK: - 相对时间显示扩展

extension Date {
    // 格式化为相对时间：xx分钟/小时/日/月/年之前
    var relativeTimeString: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .month, .year], from: self, to: now)

        if let year = components.year, year >= 1 {
            return year == 1 ? "1年前" : "\(year)年前"
        }
        if let month = components.month, month >= 1 {
            return month == 1 ? "1个月前" : "\(month)个月前"
        }
        if let day = components.day, day >= 1 {
            return day == 1 ? "1天前" : "\(day)天前"
        }
        if let hour = components.hour, hour >= 1 {
            return hour == 1 ? "1小时前" : "\(hour)小时前"
        }
        if let minute = components.minute, minute >= 1 {
            return minute == 1 ? "1分钟前" : "\(minute)分钟前"
        }
        return "刚刚"
    }
}

// 时间格式化工具
enum TimeFormatter {
    // 将ISO8601字符串转换为Date
    static func date(fromISO8601 string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    // 将时间字符串转换为相对时间显示
    static func relativeTime(from string: String) -> String {
        guard let date = date(fromISO8601: string) else {
            return "未知时间"
        }
        return date.relativeTimeString
    }
}
