import Foundation

struct Repository: Codable, Identifiable {
    let id: Int
    let name: String
    let fullName: String
    let description: String?
    let language: String?
    let stargazersCount: Int
    let forksCount: Int
    let watchersCount: Int
    let openIssuesCount: Int
    let isPrivate: Bool
    let htmlUrl: String
    let defaultBranch: String
    let updatedAt: String
    let createdAt: String
    let owner: RepositoryOwner
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, language, owner
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
    }
    
    var ownerName: String {
        return owner.login
    }
    
    var formattedUpdateTime: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: updatedAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        return updatedAt
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
