import Foundation
import SwiftUI

// MARK: - Issue状态枚举
enum IssueState: String, Codable {
    case open = "open"
    case closed = "closed"

    var 显示文本: String {
        switch self {
        case .open: return "开放"
        case .closed: return "已关闭"
        }
    }

    var 图标名称: String {
        switch self {
        case .open: return "exclamationmark.circle.fill"
        case .closed: return "checkmark.circle.fill"
        }
    }

    var 颜色: Color {
        switch self {
        case .open: return .green
        case .closed: return .purple
        }
    }
}

// MARK: - Issue标签
struct IssueLabel: Codable, Identifiable {
    let id: Int
    let name: String
    let color: String
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, color, description
    }

    /// 十六进制颜色转Color
    var 背景颜色: Color {
        let hex = color.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    /// 根据背景亮度计算文字颜色（深色背景用白字，浅色背景用黑字）
    var 文字颜色: Color {
        return isLightColor ? .black : .white
    }

    /// 判断颜色是否为浅色
    private var isLightColor: Bool {
        let hex = color.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        let brightness = (r * 299 + g * 587 + b * 114) / 1000
        return brightness > 0.5
    }
}

// MARK: - Issue里程碑
struct IssueMilestone: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let description: String?
    let state: String
    let openIssues: Int
    let closedIssues: Int
    let createdAt: String?
    let updatedAt: String?
    let dueOn: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, description, state
        case openIssues = "open_issues"
        case closedIssues = "closed_issues"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case dueOn = "due_on"
    }
}

// MARK: - Issue模型
struct Issue: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: IssueState
    let user: GitHubUser
    let labels: [IssueLabel]?
    let milestone: IssueMilestone?
    let comments: Int
    let createdAt: String?
    let updatedAt: String?
    let closedAt: String?
    let htmlUrl: String
    let pullRequest: PullRequestInfo?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, milestone, comments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case htmlUrl = "html_url"
        case pullRequest = "pull_request"
    }

    /// 是否是Pull Request
    var 是PullRequest: Bool {
        return pullRequest != nil
    }

    /// 创建时间显示
    var 创建时间显示: String {
        guard let createdAt = createdAt else { return "未知时间" }
        return 日期工具.相对时间(fromISO: createdAt)
    }

    /// 更新时间显示
    var 更新时间显示: String {
        guard let updatedAt = updatedAt else { return "未知时间" }
        return 日期工具.相对时间(fromISO: updatedAt)
    }
}

// MARK: - Pull Request简要信息（用于区分Issue和PR）
struct PullRequestInfo: Codable {
    let url: String?
    let htmlUrl: String?
    let diffUrl: String?
    let patchUrl: String?

    enum CodingKeys: String, CodingKey {
        case url
        case htmlUrl = "html_url"
        case diffUrl = "diff_url"
        case patchUrl = "patch_url"
    }
}

// MARK: - Issue评论
struct IssueComment: Codable, Identifiable {
    let id: Int
    let body: String?
    let user: GitHubUser
    let createdAt: String?
    let updatedAt: String?
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case id, body, user
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
    }

    /// 创建时间显示
    var 创建时间显示: String {
        guard let createdAt = createdAt else { return "未知时间" }
        return 日期工具.相对时间(fromISO: createdAt)
    }
}

// MARK: - 创建Issue请求
struct CreateIssueRequest: Codable {
    let title: String
    let body: String?
    let labels: [String]?
    let assignees: [String]?

    enum CodingKeys: String, CodingKey {
        case title, body, labels, assignees
    }
}
