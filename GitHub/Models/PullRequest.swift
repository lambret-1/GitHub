import Foundation
import SwiftUI

// MARK: - PR状态枚举
enum PullRequestState: String, Codable {
    case open = "open"
    case closed = "closed"
    case merged = "merged"

    var 显示文本: String {
        switch self {
        case .open: return "开放"
        case .closed: return "已关闭"
        case .merged: return "已合并"
        }
    }

    var 图标名称: String {
        switch self {
        case .open: return "arrow.right.circle.fill"
        case .closed: return "xmark.circle.fill"
        case .merged: return "arrow.merge.circle.fill"
        }
    }

    var 颜色: Color {
        switch self {
        case .open: return .green
        case .closed: return .red
        case .merged: return .purple
        }
    }
}

// MARK: - PR合并状态枚举
enum MergeableState: String, Codable {
    case clean = "clean"
    case dirty = "dirty"
    case unknown = "unknown"
    case unstable = "unstable"
    case blocked = "blocked"
    case behind = "behind"

    var 显示文本: String {
        switch self {
        case .clean: return "可合并"
        case .dirty: return "存在冲突"
        case .unknown: return "检查中"
        case .unstable: return "检查未通过"
        case .blocked: return "被阻止"
        case .behind: return "落后于目标分支"
        }
    }
}

// MARK: - PR标签（复用IssueLabel）
typealias PullRequestLabel = IssueLabel

// MARK: - PR里程碑（复用IssueMilestone）
typealias PullRequestMilestone = IssueMilestone

// MARK: - PR分支信息
struct PullRequestBranch: Codable {
    let label: String?
    let ref: String
    let sha: String
    let user: GitHubUser?
    let repo: Repository?

    enum CodingKeys: String, CodingKey {
        case label, ref, sha, user, repo
    }

    var 分支名称: String {
        return ref
    }

    var 完整标签: String {
        return label ?? ref
    }
}

// MARK: - PR模型
struct PullRequest: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let body: String?
    let state: PullRequestState
    let user: GitHubUser
    let labels: [PullRequestLabel]?
    let milestone: PullRequestMilestone?
    let comments: Int?
    let reviewComments: Int?
    let commits: Int?
    let additions: Int?
    let deletions: Int?
    let changedFiles: Int?
    let createdAt: String?
    let updatedAt: String?
    let closedAt: String?
    let mergedAt: String?
    let htmlUrl: String
    let head: PullRequestBranch
    let base: PullRequestBranch
    let draft: Bool?
    let mergeable: Bool?
    let mergeableState: MergeableState?
    let merged: Bool?
    let mergedBy: GitHubUser?
    let mergeCommitSha: String?

    enum CodingKeys: String, CodingKey {
        case id, number, title, body, state, user, labels, milestone, comments, head, base, draft, merged
        case reviewComments = "review_comments"
        case commits = "commits"
        case additions = "additions"
        case deletions = "deletions"
        case changedFiles = "changed_files"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case closedAt = "closed_at"
        case mergedAt = "merged_at"
        case htmlUrl = "html_url"
        case mergeable = "mergeable"
        case mergeableState = "mergeable_state"
        case mergedBy = "merged_by"
        case mergeCommitSha = "merge_commit_sha"
    }

    /// 是否是草稿
    var 是草稿: Bool {
        return draft ?? false
    }

    /// 是否已合并
    var 已合并: Bool {
        return merged ?? false
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

    /// 合并时间显示
    var 合并时间显示: String? {
        guard let mergedAt = mergedAt else { return nil }
        return 日期工具.相对时间(fromISO: mergedAt)
    }

    /// 变更统计显示
    var 变更统计显示: String {
        var parts: [String] = []
        if let commits = commits {
            parts.append("\(commits) 次提交")
        }
        if let changedFiles = changedFiles {
            parts.append("\(changedFiles) 个文件变更")
        }
        if let additions = additions {
            parts.append("+\(additions)")
        }
        if let deletions = deletions {
            parts.append("-\(deletions)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - PR评论（复用IssueComment）
typealias PullRequestComment = IssueComment

// MARK: - PR审查评论
struct PullRequestReviewComment: Codable, Identifiable {
    let id: Int
    let body: String?
    let user: GitHubUser
    let createdAt: String?
    let updatedAt: String?
    let htmlUrl: String
    let path: String?
    let position: Int?
    let originalPosition: Int?
    let commitId: String?
    let originalCommitId: String?
    let diffHunk: String?
    let inReplyToId: Int?

    enum CodingKeys: String, CodingKey {
        case id, body, user, path, position
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case originalPosition = "original_position"
        case commitId = "commit_id"
        case originalCommitId = "original_commit_id"
        case diffHunk = "diff_hunk"
        case inReplyToId = "in_reply_to_id"
    }

    /// 创建时间显示
    var 创建时间显示: String {
        guard let createdAt = createdAt else { return "未知时间" }
        return 日期工具.相对时间(fromISO: createdAt)
    }
}

// MARK: - PR审查
struct PullRequestReview: Codable, Identifiable {
    let id: Int
    let user: GitHubUser
    let body: String?
    let state: String
    let submittedAt: String?
    let htmlUrl: String
    let commitId: String?

    enum CodingKeys: String, CodingKey {
        case id, user, body, state
        case submittedAt = "submitted_at"
        case htmlUrl = "html_url"
        case commitId = "commit_id"
    }

    var 状态显示: String {
        switch state.lowercased() {
        case "approved": return "已批准"
        case "changes_requested": return "要求修改"
        case "commented": return "已评论"
        case "dismissed": return "已驳回"
        case "pending": return "待处理"
        default: return state
        }
    }

    var 状态颜色: Color {
        switch state.lowercased() {
        case "approved": return .green
        case "changes_requested": return .orange
        case "commented": return .blue
        case "dismissed": return .gray
        default: return .secondary
        }
    }

    /// 提交时间显示
    var 提交时间显示: String {
        guard let submittedAt = submittedAt else { return "未知时间" }
        return 日期工具.相对时间(fromISO: submittedAt)
    }
}

// MARK: - PR提交
struct PullRequestCommit: Codable, Identifiable {
    let id: String
    let sha: String
    let commit: CommitInfo
    let htmlUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "node_id"
        case sha, commit
        case htmlUrl = "html_url"
    }

    var 短哈希: String {
        return String(sha.prefix(7))
    }
}

// MARK: - 提交信息
struct CommitInfo: Codable {
    let message: String?
    let author: CommitAuthor?
    let committer: CommitAuthor?

    enum CodingKeys: String, CodingKey {
        case message, author, committer
    }
}

// MARK: - 提交作者
struct CommitAuthor: Codable {
    let name: String?
    let email: String?
    let date: String?

    enum CodingKeys: String, CodingKey {
        case name, email, date
    }
}

// MARK: - PR变更文件
struct PullRequestFile: Codable, Identifiable {
    let id: Int?
    let filename: String
    let status: String
    let additions: Int
    let deletions: Int
    let changes: Int
    let patch: String?
    let rawUrl: String?
    let blobUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "sha"
        case filename, status, additions, deletions, changes, patch
        case rawUrl = "raw_url"
        case blobUrl = "blob_url"
    }

    var 状态显示: String {
        switch status.lowercased() {
        case "added": return "新增"
        case "modified": return "修改"
        case "removed": return "删除"
        case "renamed": return "重命名"
        default: return status
        }
    }

    var 状态颜色: Color {
        switch status.lowercased() {
        case "added": return .green
        case "modified": return .blue
        case "removed": return .red
        case "renamed": return .orange
        default: return .secondary
        }
    }

    var 文件名: String {
        return (filename as NSString).lastPathComponent
    }

    var 文件路径: String {
        return (filename as NSString).deletingLastPathComponent
    }
}

// MARK: - 创建PR请求
struct CreatePullRequestRequest: Codable {
    let title: String
    let head: String
    let base: String
    let body: String?
    let maintainerCanModify: Bool?

    enum CodingKeys: String, CodingKey {
        case title, head, base, body
        case maintainerCanModify = "maintainer_can_modify"
    }
}

// MARK: - 合并PR请求
struct MergePullRequestRequest: Codable {
    let commitTitle: String?
    let commitMessage: String?
    let sha: String
    let mergeMethod: String

    enum CodingKeys: String, CodingKey {
        case commitTitle = "commit_title"
        case commitMessage = "commit_message"
        case sha
        case mergeMethod = "merge_method"
    }
}
