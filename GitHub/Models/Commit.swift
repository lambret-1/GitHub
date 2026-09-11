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
        // 使用统一的日期工具类格式化
        guard let date = 日期工具.解析ISO日期(authorDate) else {
            return authorDate
        }
        return 日期工具.格式化日期(date)
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
}

struct CommitAuthor: Codable {
    let login: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}
