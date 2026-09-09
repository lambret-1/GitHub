import Foundation

// ==============================================================================
// GitHubAccount 账号模型
// 功能：存储GitHub账号信息，包括用户名、Token、头像等
// ==============================================================================

struct GitHubAccount: Codable, Identifiable, Equatable {
    let id: String
    let username: String
    let token: String
    let avatarUrl: String?
    let displayName: String?
    let addedAt: Date

    init(id: String, username: String, token: String, avatarUrl: String? = nil, displayName: String? = nil) {
        self.id = id
        self.username = username
        self.token = token
        self.avatarUrl = avatarUrl
        self.displayName = displayName
        self.addedAt = Date()
    }

    static func == (lhs: GitHubAccount, rhs: GitHubAccount) -> Bool {
        return lhs.id == rhs.id
    }
}
