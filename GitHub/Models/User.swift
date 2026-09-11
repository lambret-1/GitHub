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
    let publicRepos: Int?
    let followers: Int?
    let following: Int?
    let htmlUrl: String
    let createdAt: String?
    
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
        guard let createdAt = createdAt else { return "未知" }
        // 使用统一的相对时间工具类
        return 日期工具.相对时间(fromISO: createdAt)
    }
}
