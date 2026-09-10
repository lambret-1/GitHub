import Foundation

enum APIEndpoints {
    // API 请求始终使用官方 API 地址
    // 重要：不使用镜像加速，避免镜像服务器缓存其他用户的认证响应，导致账号信息泄露
    // 镜像加速仅用于文件下载、网页预览、头像加载等公开资源
    static let baseURL = "https://api.github.com"

    case user
    case userRepos(page: Int, perPage: Int)
    case repoContent(owner: String, repo: String, path: String, branch: String)
    case updateFile(owner: String, repo: String, path: String)
    case repoBranches(owner: String, repo: String)
    case commits(owner: String, repo: String, path: String?)
    case searchRepos(query: String, page: Int)
    case searchUsers(query: String, page: Int)

    var url: String {
        switch self {
        case .user:
            return "\(APIEndpoints.baseURL)/user"
        case .userRepos(let page, let perPage):
            return "\(APIEndpoints.baseURL)/user/repos?page=\(page)&per_page=\(perPage)&sort=updated"
        case .repoContent(let owner, let repo, let path, let branch):
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)?ref=\(branch)"
        case .updateFile(let owner, let repo, let path):
            let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/contents/\(encodedPath)"
        case .repoBranches(let owner, let repo):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/branches"
        case .commits(let owner, let repo, let path):
            var url = "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/commits?per_page=30"
            if let path = path {
                url += "&path=\(path)"
            }
            return url
        case .searchRepos(let query, let page):
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return "\(APIEndpoints.baseURL)/search/repositories?q=\(encodedQuery)&page=\(page)&per_page=30&sort=stars"
        case .searchUsers(let query, let page):
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return "\(APIEndpoints.baseURL)/search/users?q=\(encodedQuery)&page=\(page)&per_page=30&sort=followers"
        }
    }
}
