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
    case searchCode(query: String, page: Int)

    // MARK: - GitHub Actions 相关端点
    case workflows(owner: String, repo: String)
    case workflowRuns(owner: String, repo: String, page: Int, perPage: Int)
    case workflowRunsForWorkflow(owner: String, repo: String, workflowId: Int, page: Int, perPage: Int)
    case workflowRun(owner: String, repo: String, runId: Int)
    case workflowJobs(owner: String, repo: String, runId: Int)
    case jobLogs(owner: String, repo: String, jobId: Int)
    case workflowDispatch(owner: String, repo: String, workflowId: Int)
    case cancelWorkflowRun(owner: String, repo: String, runId: Int)
    case rerunWorkflowRun(owner: String, repo: String, runId: Int)

    // MARK: - 仓库交互相关端点
    case checkStarred(owner: String, repo: String)
    case starRepository(owner: String, repo: String)
    case unstarRepository(owner: String, repo: String)
    case forkRepository(owner: String, repo: String)

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
        case .searchCode(let query, let page):
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            return "\(APIEndpoints.baseURL)/search/code?q=\(encodedQuery)&page=\(page)&per_page=30"

        // MARK: - GitHub Actions 相关端点实现
        case .workflows(let owner, let repo):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/workflows"
        case .workflowRuns(let owner, let repo, let page, let perPage):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/runs?page=\(page)&per_page=\(perPage)"
        case .workflowRunsForWorkflow(let owner, let repo, let workflowId, let page, let perPage):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/workflows/\(workflowId)/runs?page=\(page)&per_page=\(perPage)"
        case .workflowRun(let owner, let repo, let runId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)"
        case .workflowJobs(let owner, let repo, let runId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)/jobs"
        case .jobLogs(let owner, let repo, let jobId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/jobs/\(jobId)/logs"
        case .workflowDispatch(let owner, let repo, let workflowId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/workflows/\(workflowId)/dispatches"
        case .cancelWorkflowRun(let owner, let repo, let runId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)/cancel"
        case .rerunWorkflowRun(let owner, let repo, let runId):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/actions/runs/\(runId)/rerun"

        // MARK: - 仓库交互相关端点实现
        case .checkStarred(let owner, let repo):
            return "\(APIEndpoints.baseURL)/user/starred/\(owner)/\(repo)"
        case .starRepository(let owner, let repo):
            return "\(APIEndpoints.baseURL)/user/starred/\(owner)/\(repo)"
        case .unstarRepository(let owner, let repo):
            return "\(APIEndpoints.baseURL)/user/starred/\(owner)/\(repo)"
        case .forkRepository(let owner, let repo):
            return "\(APIEndpoints.baseURL)/repos/\(owner)/\(repo)/forks"
        }
    }
}
