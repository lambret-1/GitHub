import Foundation

// MARK: - 仓库权限级别枚举
enum RepoPermission: String, Codable {
    case admin = "admin"
    case write = "write"
    case read = "read"
    case none = "none"

    var 显示文本: String {
        switch self {
        case .admin: return "管理员"
        case .write: return "可读写"
        case .read: return "只读"
        case .none: return "无权限"
        }
    }

    /// 是否有写权限
    var 可写: Bool {
        return self == .admin || self == .write
    }

    /// 是否有管理员权限
    var 是管理员: Bool {
        return self == .admin
    }
}

// MARK: - 仓库权限信息
struct RepoPermissions: Codable {
    let admin: Bool
    let maintain: Bool?
    let push: Bool
    let triage: Bool?
    let pull: Bool

    enum CodingKeys: String, CodingKey {
        case admin, maintain, push, triage, pull
    }

    /// 计算权限级别
    var 权限级别: RepoPermission {
        if admin { return .admin }
        if push { return .write }
        if pull { return .read }
        return .none
    }
}

// MARK: - 开源协议信息
struct RepoLicense: Codable {
    let key: String
    let name: String
    let spdxId: String?
    let url: String?
    let nodeId: String?

    enum CodingKeys: String, CodingKey {
        case key, name, url
        case spdxId = "spdx_id"
        case nodeId = "node_id"
    }
}

// MARK: - 仓库父仓库信息（用于Fork来源，避免递归引用）
struct RepositoryParent: Codable {
    let id: Int
    let name: String
    let fullName: String
    let owner: RepositoryOwner

    enum CodingKeys: String, CodingKey {
        case id, name, owner
        case fullName = "full_name"
    }

    var ownerName: String {
        return owner.login
    }
}

struct Repository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let stargazersCount: Int?
    let forksCount: Int?
    let watchersCount: Int?
    let openIssuesCount: Int?
    let isPrivate: Bool
    let htmlUrl: String
    let defaultBranch: String?
    let updatedAt: String?
    let createdAt: String?
    let owner: RepositoryOwner
    // 新增字段
    let size: Int?
    let topics: [String]?
    let license: RepoLicense?
    let permissions: RepoPermissions?
    let isFork: Bool?
    let parent: RepositoryParent?
    let archived: Bool?
    let disabled: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner, size, topics, license, permissions, parent, archived, disabled
        case fullName = "full_name"
        case stargazersCount = "stargazers_count"
        case forksCount = "forks_count"
        case watchersCount = "watchers_count"
        case openIssuesCount = "open_issues_count"
        case isPrivate = "private"
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case updatedAt = "updated_at"
        case createdAt = "created_at"
        case isFork = "fork"
    }

    var ownerName: String {
        return owner.login
    }

    var formattedUpdateTime: String {
        guard let updatedAt = updatedAt else { return "未知" }
        // 使用统一的相对时间工具类
        return 日期工具.相对时间(fromISO: updatedAt)
    }

    var formattedCreateTime: String? {
        guard let createdAt = createdAt else { return nil }
        // 使用统一的相对时间工具类
        return 日期工具.相对时间(fromISO: createdAt)
    }

    var formattedSize: String {
        return 大小显示
    }

    var languageColor: String {
        guard let lang = language else { return "#CCCCCC" }
        let colors: [String: String] = [
            "Swift": "#F05138",
            "Python": "#3572A5",
            "JavaScript": "#F1E05A",
            "TypeScript": "#2B7489",
            "Java": "#B07219",
            "Kotlin": "#A97BFF",
            "Go": "#00ADD8",
            "Rust": "#DEA584",
            "C++": "#F34B7D",
            "C": "#555555",
            "Objective-C": "#438EFF",
            "Ruby": "#701516",
            "PHP": "#4F5D95",
            "HTML": "#E34C26",
            "CSS": "#563D7C",
            "Shell": "#89E051",
            "Dart": "#00B4AB",
            "Vue": "#41B883",
            "Markdown": "#083FA1"
        ]
        return colors[lang] ?? "#CCCCCC"
    }

    // MARK: - 新增计算属性

    /// 当前用户对仓库的权限级别
    var 当前权限: RepoPermission {
        return permissions?.权限级别 ?? .none
    }

    /// 是否有写权限
    var 可写: Bool {
        return 当前权限.可写
    }

    /// 仓库大小显示文本（KB/MB）
    var 大小显示: String {
        guard let size = size else { return "未知" }
        if size < 1024 {
            return "\(size) KB"
        } else {
            return String(format: "%.1f MB", Double(size) / 1024.0)
        }
    }

    /// 是否是Fork仓库
    var 是Fork: Bool {
        return isFork ?? false
    }

    /// 是否已归档
    var 已归档: Bool {
        return archived ?? false
    }

    /// 开源协议名称
    var 协议名称: String {
        return license?.name ?? "未指定协议"
    }
}

struct RepositoryOwner: Codable {
    let login: String
    let id: Int
    let avatarUrl: String

    enum CodingKeys: String, CodingKey {
        case login, id
        case avatarUrl = "avatar_url"
    }
}
