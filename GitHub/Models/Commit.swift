import Foundation

struct Commit: Codable, Identifiable {
    let sha: String
    let commit: CommitDetail
    let author: CommitAuthor?
    let htmlUrl: String
    
    enum CodingKeys: String, CodingKey {
        case sha, commit, author
        case htmlUrl = "html_url"
    }
    
    var id: String { sha }
    
    var shortSha: String {
        return String(sha.prefix(7))
    }
    
    var message: String {
        return commit.message
    }
    
    var authorName: String {
        return commit.author.name
    }
    
    var authorDate: String {
        return commit.author.date
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: authorDate) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        return authorDate
    }
}

struct CommitDetail: Codable {
    let message: String
    let author: CommitPerson
    let committer: CommitPerson
}

struct CommitPerson: Codable {
    let name: String
    let email: String
    let date: String

    // 格式化日期（北京时间）
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        // 先尝试带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        // 再尝试不带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        return date
    }

    // 相对日期（当前时间减去提交时间）
    var relativeDate: String {
        let formatter = ISO8601DateFormatter()
        // 先尝试带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let parsedDate = formatter.date(from: date) else {
            // 再尝试不带小数秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            guard let fallbackDate = formatter.date(from: date) else {
                return formattedDate
            }
            return calculateRelativeDate(from: fallbackDate)
        }
        return calculateRelativeDate(from: parsedDate)
    }

    // 计算相对时间差（核心逻辑：当前时间 - 提交时间）
    private func calculateRelativeDate(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 小于1分钟显示1分钟前
        if interval < 60 {
            return "1 分钟前"
        }
        // 小于1小时显示x分钟前
        else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        }
        // 小于1天显示x小时前
        else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        }
        // 小于1年显示x天前
        else if interval < 31536000 {
            return "\(Int(interval / 86400)) 天前"
        }
        // 大于等于1年显示x年前
        else {
            return "\(Int(interval / 31536000)) 年前"
        }
    }
}

struct CommitAuthor: Codable {
    let login: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}
