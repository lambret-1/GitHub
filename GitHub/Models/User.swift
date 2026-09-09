import Foundation

struct GitHubUser: Codable, Identifiable {
    let id: Int
    let login: String
    let name: String?
    let avatarUrl: String
    let bio: String?
    let company: String?
    let location: String?
    let blog: String?
    let publicRepos: Int
    let followers: Int
    let following: Int
    let htmlUrl: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, login, name, bio, company, location, blog
        case avatarUrl = "avatar_url"
        case publicRepos = "public_repos"
        case followers, following
        case htmlUrl = "html_url"
        case createdAt = "created_at"
    }
    
    var displayName: String {
        return name ?? login
    }
    
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: createdAt) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy年MM月dd日"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        return createdAt
    }
}
