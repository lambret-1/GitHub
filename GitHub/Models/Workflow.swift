import Foundation

// MARK: - GitHub Actions 工作流模型

struct Workflow: Codable, Identifiable {
    let id: Int
    let name: String
    let path: String
    let state: String
    let createdAt: String
    let updatedAt: String
    let htmlUrl: String
    let badgeUrl: String

    enum CodingKeys: String, CodingKey {
        case id, name, path, state
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case htmlUrl = "html_url"
        case badgeUrl = "badge_url"
    }

    // 工作流状态显示文本
    var stateDisplay: String {
        switch state {
        case "active": return "启用"
        case "disabled_manually": return "手动禁用"
        case "disabled_inactivity": return "因不活跃禁用"
        default: return state
        }
    }

    // 工作流文件名
    var fileName: String {
        return (path as NSString).lastPathComponent
    }
}

// MARK: - 工作流运行列表响应

struct WorkflowRunsResponse: Codable {
    let totalCount: Int
    let workflowRuns: [WorkflowRun]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflowRuns = "workflow_runs"
    }
}

// MARK: - 工作流运行模型

struct WorkflowRun: Codable, Identifiable {
    let id: Int
    let name: String
    let nodeId: String
    let headBranch: String
    let headSha: String
    let runNumber: Int
    let event: String
    let status: String
    let conclusion: String?
    let workflowId: Int
    let url: String
    let htmlUrl: String
    let createdAt: String
    let updatedAt: String
    let runStartedAt: String?
    let jobsUrl: String
    let logsUrl: String
    let checkSuiteUrl: String
    let artifactsUrl: String
    let cancelUrl: String
    let rerunUrl: String
    let headCommit: HeadCommit?
    let actor: Actor?

    enum CodingKeys: String, CodingKey {
        case id, name, event, status, conclusion, url
        case nodeId = "node_id"
        case headBranch = "head_branch"
        case headSha = "head_sha"
        case runNumber = "run_number"
        case workflowId = "workflow_id"
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case runStartedAt = "run_started_at"
        case jobsUrl = "jobs_url"
        case logsUrl = "logs_url"
        case checkSuiteUrl = "check_suite_url"
        case artifactsUrl = "artifacts_url"
        case cancelUrl = "cancel_url"
        case rerunUrl = "rerun_url"
        case headCommit = "head_commit"
        case actor
    }

    // 运行状态显示文本和颜色
    var statusDisplay: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "成功"
            case "failure": return "失败"
            case "cancelled": return "已取消"
            case "timed_out": return "超时"
            case "action_required": return "需要操作"
            case "neutral": return "中性"
            case "skipped": return "已跳过"
            default: return conclusion ?? "已完成"
            }
        } else if status == "in_progress" {
            return "进行中"
        } else if status == "queued" {
            return "排队中"
        } else if status == "waiting" {
            return "等待中"
        } else if status == "requested" {
            return "已请求"
        } else if status == "pending" {
            return "待处理"
        }
        return status
    }

    // 状态对应的系统图标
    var statusIcon: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "stop.circle.fill"
            case "timed_out": return "clock.fill"
            case "action_required": return "exclamationmark.circle.fill"
            default: return "circle.fill"
            }
        } else if status == "in_progress" {
            return "arrow.triangle.2.circlepath"
        } else if status == "queued" || status == "pending" {
            return "clock"
        }
        return "circle"
    }

    // 状态对应的颜色
    var statusColor: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "systemGreen"
            case "failure": return "systemRed"
            case "cancelled": return "systemGray"
            case "timed_out": return "systemOrange"
            default: return "systemGray"
            }
        } else if status == "in_progress" {
            return "systemBlue"
        }
        return "systemGray"
    }

    // 触发事件显示文本
    var eventDisplay: String {
        switch event {
        case "push": return "推送"
        case "pull_request": return "拉取请求"
        case "workflow_dispatch": return "手动触发"
        case "schedule": return "定时触发"
        case "release": return "发布"
        case "create": return "创建"
        case "delete": return "删除"
        case "fork": return "Fork"
        case "watch": return "关注"
        case "issue_comment": return "议题评论"
        case "issues": return "议题"
        case "pull_request_review": return "PR 审查"
        case "pull_request_review_comment": return "PR 评论"
        case "repository_dispatch": return "仓库触发"
        default: return event
        }
    }

    // 提交短哈希
    var shortSha: String {
        return String(headSha.prefix(7))
    }

    // 格式化的创建时间（统一相对时间格式）
    var formattedCreatedAt: String {
        return 日期工具.相对时间(fromISO: createdAt)
    }
}

// MARK: - 头部提交信息

struct HeadCommit: Codable {
    let id: String
    let treeId: String
    let message: String
    let timestamp: String
    let author: WorkflowCommitAuthor?
    let committer: WorkflowCommitAuthor?

    enum CodingKeys: String, CodingKey {
        case id, message, timestamp, author, committer
        case treeId = "tree_id"
    }
}

// MARK: - 提交作者

struct WorkflowCommitAuthor: Codable {
    let name: String
    let email: String
    let username: String?
}

// MARK: - 执行者

struct Actor: Codable {
    let login: String
    let id: Int
    let avatarUrl: String
    let htmlUrl: String
    let type: String

    enum CodingKeys: String, CodingKey {
        case login, id, type
        case avatarUrl = "avatar_url"
        case htmlUrl = "html_url"
    }
}

// MARK: - 工作流作业列表响应

struct WorkflowJobsResponse: Codable {
    let totalCount: Int
    let jobs: [WorkflowJob]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case jobs
    }
}

// MARK: - 工作流作业模型

struct WorkflowJob: Codable, Identifiable {
    let id: Int
    let runId: Int
    let runUrl: String
    let nodeId: String
    let headSha: String
    let url: String
    let htmlUrl: String
    let status: String
    let conclusion: String?
    let startedAt: String?
    let completedAt: String?
    let name: String
    let steps: [JobStep]?
    let checkRunUrl: String
    let labels: [String]
    let runnerId: Int?
    let runnerName: String?
    let runnerGroupId: Int?
    let runnerGroupName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion, url, steps, labels
        case runId = "run_id"
        case runUrl = "run_url"
        case nodeId = "node_id"
        case headSha = "head_sha"
        case htmlUrl = "html_url"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case checkRunUrl = "check_run_url"
        case runnerId = "runner_id"
        case runnerName = "runner_name"
        case runnerGroupId = "runner_group_id"
        case runnerGroupName = "runner_group_name"
    }

    // 作业状态显示文本
    var statusDisplay: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "成功"
            case "failure": return "失败"
            case "cancelled": return "已取消"
            case "timed_out": return "超时"
            case "skipped": return "已跳过"
            default: return conclusion ?? "已完成"
            }
        } else if status == "in_progress" {
            return "进行中"
        } else if status == "queued" {
            return "排队中"
        } else if status == "waiting" {
            return "等待中"
        } else if status == "pending" {
            return "待处理"
        }
        return status
    }

    // 状态对应的系统图标
    var statusIcon: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "stop.circle.fill"
            case "timed_out": return "clock.fill"
            default: return "circle.fill"
            }
        } else if status == "in_progress" {
            return "arrow.triangle.2.circlepath"
        } else if status == "queued" || status == "pending" {
            return "clock"
        }
        return "circle"
    }

    // 状态对应的颜色
    var statusColor: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "systemGreen"
            case "failure": return "systemRed"
            case "cancelled": return "systemGray"
            case "timed_out": return "systemOrange"
            default: return "systemGray"
            }
        } else if status == "in_progress" {
            return "systemBlue"
        }
        return "systemGray"
    }

    // 运行时长（秒）
    var durationSeconds: Int? {
        guard let start = parseDate(startedAt ?? ""),
              let end = parseDate(completedAt ?? "") else {
            return nil
        }
        return Int(end.timeIntervalSince(start))
    }

    // 格式化的运行时长
    var durationDisplay: String {
        guard let seconds = durationSeconds else { return "-" }
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        } else {
            return "\(seconds / 3600)时\((seconds % 3600) / 60)分"
        }
    }
}

// MARK: - 作业步骤模型

struct JobStep: Codable, Identifiable {
    let name: String
    let status: String
    let conclusion: String?
    let number: Int
    let startedAt: String?
    let completedAt: String?

    enum CodingKeys: String, CodingKey {
        case name, status, conclusion, number
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }

    var id: Int { number }

    // 步骤状态显示文本
    var statusDisplay: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "成功"
            case "failure": return "失败"
            case "cancelled": return "已取消"
            case "skipped": return "已跳过"
            default: return conclusion ?? "已完成"
            }
        } else if status == "in_progress" {
            return "进行中"
        } else if status == "queued" || status == "pending" {
            return "等待中"
        }
        return status
    }

    // 状态对应的系统图标
    var statusIcon: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "checkmark.circle.fill"
            case "failure": return "xmark.circle.fill"
            case "cancelled": return "stop.circle.fill"
            case "skipped": return "arrow.right.circle.fill"
            default: return "circle.fill"
            }
        } else if status == "in_progress" {
            return "arrow.triangle.2.circlepath"
        } else if status == "queued" || status == "pending" {
            return "clock"
        }
        return "circle"
    }

    // 状态对应的颜色
    var statusColor: String {
        if status == "completed" {
            switch conclusion {
            case "success": return "systemGreen"
            case "failure": return "systemRed"
            case "cancelled": return "systemGray"
            default: return "systemGray"
            }
        } else if status == "in_progress" {
            return "systemBlue"
        }
        return "systemGray"
    }

    // 运行时长（秒）
    var durationSeconds: Int? {
        guard let start = parseDate(startedAt ?? ""),
              let end = parseDate(completedAt ?? "") else {
            return nil
        }
        return Int(end.timeIntervalSince(start))
    }

    // 格式化的运行时长
    var durationDisplay: String {
        guard let seconds = durationSeconds else { return "-" }
        if seconds < 60 {
            return "\(seconds)秒"
        } else {
            return "\(seconds / 60)分\(seconds % 60)秒"
        }
    }
}

// MARK: - 工作流列表响应

struct WorkflowsResponse: Codable {
    let totalCount: Int
    let workflows: [Workflow]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case workflows
    }
}

// MARK: - 日期解析辅助函数

func parseDate(_ dateString: String) -> Date? {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatter.date(from: dateString) {
        return date
    }
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: dateString)
}

// MARK: - 日期格式化器扩展

extension DateFormatter {
    static let githubDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter
    }()
}
