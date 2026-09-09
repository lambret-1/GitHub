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
}

struct CommitAuthor: Codable {
    let login: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case login
        case avatarUrl = "avatar_url"
    }
}
