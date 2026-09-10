import Foundation

// MARK: - 高级筛选条件模型

/// 仓库搜索筛选条件
struct RepoFilterState: Codable {
    // 搜索范围
    var searchInName: Bool = true
    var searchInDescription: Bool = true
    var searchInReadme: Bool = false

    // 仓库属性
    var isPublic: Bool = false
    var isPrivate: Bool = false
    var isArchived: Bool? // nil=不限, true=仅已归档, false=仅未归档
    var isTemplate: Bool?

    // 语言
    var language: String?

    // 主题
    var topic: String?

    // 许可证
    var license: String?

    // 所有者
    var user: String?
    var org: String?

    // 数值范围
    var minStars: Int?
    var minForks: Int?
    var minSizeKB: Int?

    // 时间范围
    var createdAfter: Date?
    var pushedAfter: Date?

    init() {}

    /// 构建查询字符串
    func buildQuery(baseQuery: String) -> String {
        var query = baseQuery

        // 搜索范围
        var inOptions: [String] = []
        if searchInName { inOptions.append("name") }
        if searchInDescription { inOptions.append("description") }
        if searchInReadme { inOptions.append("readme") }
        if !inOptions.isEmpty {
            query += " in:\(inOptions.joined(separator: ","))"
        }

        // 仓库属性
        if isPublic { query += " is:public" }
        if isPrivate { query += " is:private" }
        if let archived = isArchived {
            query += archived ? " archived:true" : " archived:false"
        }
        if let template = isTemplate {
            query += template ? " template:true" : " template:false"
        }

        // 语言
        if let language = language, !language.isEmpty {
            query += " language:\(language)"
        }

        // 主题
        if let topic = topic, !topic.isEmpty {
            query += " topic:\(topic)"
        }

        // 许可证
        if let license = license, !license.isEmpty {
            query += " license:\(license)"
        }

        // 所有者
        if let user = user, !user.isEmpty {
            query += " user:\(user)"
        }
        if let org = org, !org.isEmpty {
            query += " org:\(org)"
        }

        // 数值范围
        if let minStars = minStars, minStars > 0 {
            query += " stars:>=\(minStars)"
        }
        if let minForks = minForks, minForks > 0 {
            query += " forks:>=\(minForks)"
        }
        if let minSizeKB = minSizeKB, minSizeKB > 0 {
            query += " size:>=\(minSizeKB)"
        }

        // 时间范围
        if let createdAfter = createdAfter {
            let dateStr = Self.dateFormatter.string(from: createdAfter)
            query += " created:>=\(dateStr)"
        }
        if let pushedAfter = pushedAfter {
            let dateStr = Self.dateFormatter.string(from: pushedAfter)
            query += " pushed:>=\(dateStr)"
        }

        return query
    }

    /// 判断是否有任何筛选条件
    var hasFilters: Bool {
        return !searchInName || !searchInDescription || searchInReadme ||
               isPublic || isPrivate || isArchived != nil || isTemplate != nil ||
               language != nil || topic != nil || license != nil ||
               user != nil || org != nil ||
               minStars != nil || minForks != nil || minSizeKB != nil ||
               createdAfter != nil || pushedAfter != nil
    }

    /// 重置所有筛选条件
    mutating func reset() {
        searchInName = true
        searchInDescription = true
        searchInReadme = false
        isPublic = false
        isPrivate = false
        isArchived = nil
        isTemplate = nil
        language = nil
        topic = nil
        license = nil
        user = nil
        org = nil
        minStars = nil
        minForks = nil
        minSizeKB = nil
        createdAfter = nil
        pushedAfter = nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

/// 用户搜索筛选条件
struct UserFilterState: Codable {
    // 搜索范围
    var searchInLogin: Bool = true
    var searchInFullName: Bool = true
    var searchInEmail: Bool = false

    // 用户类型
    var userType: UserType? // nil=不限, .user=仅用户, .org=仅组织

    enum UserType: String, Codable, CaseIterable {
        case user = "用户"
        case org = "组织"
    }

    // 位置
    var location: String?

    // 语言
    var language: String?

    // 数值范围
    var minRepos: Int?
    var minFollowers: Int?
    var minFollowing: Int?

    // 时间范围
    var createdAfter: Date?

    init() {}

    /// 构建查询字符串
    func buildQuery(baseQuery: String) -> String {
        var query = baseQuery

        // 搜索范围
        var inOptions: [String] = []
        if searchInLogin { inOptions.append("login") }
        if searchInFullName { inOptions.append("fullname") }
        if searchInEmail { inOptions.append("email") }
        if !inOptions.isEmpty {
            query += " in:\(inOptions.joined(separator: ","))"
        }

        // 用户类型
        if let userType = userType {
            query += " type:\(userType == .user ? "user" : "org")"
        }

        // 位置
        if let location = location, !location.isEmpty {
            query += " location:\(location)"
        }

        // 语言
        if let language = language, !language.isEmpty {
            query += " language:\(language)"
        }

        // 数值范围
        if let minRepos = minRepos, minRepos > 0 {
            query += " repos:>=\(minRepos)"
        }
        if let minFollowers = minFollowers, minFollowers > 0 {
            query += " followers:>=\(minFollowers)"
        }
        if let minFollowing = minFollowing, minFollowing > 0 {
            query += " following:>=\(minFollowing)"
        }

        // 时间范围
        if let createdAfter = createdAfter {
            let dateStr = Self.dateFormatter.string(from: createdAfter)
            query += " created:>=\(dateStr)"
        }

        return query
    }

    /// 判断是否有任何筛选条件
    var hasFilters: Bool {
        return !searchInLogin || !searchInFullName || searchInEmail ||
               userType != nil || location != nil || language != nil ||
               minRepos != nil || minFollowers != nil || minFollowing != nil ||
               createdAfter != nil
    }

    /// 重置所有筛选条件
    mutating func reset() {
        searchInLogin = true
        searchInFullName = true
        searchInEmail = false
        userType = nil
        location = nil
        language = nil
        minRepos = nil
        minFollowers = nil
        minFollowing = nil
        createdAfter = nil
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

// MARK: - 常用选项数据

struct FilterOptions {
    static let languages = [
        "Swift", "Objective-C", "JavaScript", "TypeScript", "Python", "Java",
        "Kotlin", "Go", "Rust", "C++", "C", "Ruby", "PHP", "Dart", "Vue",
        "React", "HTML", "CSS", "Shell", "Markdown", "JSON", "YAML", "XML"
    ]

    static let licenses = [
        "mit", "apache-2.0", "gpl-3.0", "gpl-2.0", "bsd-3-clause",
        "bsd-2-clause", "lgpl-3.0", "lgpl-2.1", "mpl-2.0", "unlicense", "cc0-1.0"
    ]

    static let starOptions = [0, 10, 50, 100, 500, 1000, 5000, 10000]
    static let forkOptions = [0, 10, 50, 100, 500, 1000]
    static let repoOptions = [0, 10, 50, 100, 500, 1000]
    static let followerOptions = [0, 10, 50, 100, 500, 1000, 10000]
}
