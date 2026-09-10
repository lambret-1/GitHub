import Foundation

enum APIEndpoints {
    // 动态获取当前 API 基础 URL（支持镜像加速）
    static var baseURL: String {
        AppSettings.shared.currentBaseURL
    }

    case user
    case userRepos(page: Int, perPage: Int)
    case repoContent(owner: String, repo: String, path: String, branch: String)
    case updateFile(owner: String, repo: String, path: String)
    case repoBranches(owner: String, repo: String)
    case commits(owner: String, repo: String, path: String?)
    case searchRepos(query: String, page: Int)

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
        }
    }
}
