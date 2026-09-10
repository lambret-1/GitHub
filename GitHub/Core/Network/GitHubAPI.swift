import Foundation

class GitHubAPI {
    static let shared = GitHubAPI()
    
    private init() {}
    
    private func getHeaders() -> [String: String] {
        guard let token = TokenKeychain.shared.getToken() else {
            return [:]
        }
        return [
            "Authorization": "token \(token)",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "GitHub-iOS-Client"
        ]
    }
    
    private func performRequest(url: String, method: String = "GET", body: [String: Any]? = nil, completion: @escaping (Result<Data, Error>) -> Void) {
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        
        var request = URLRequest(url: urlObj)
        request.httpMethod = method
        request.allHTTPHeaderFields = getHeaders()
        
        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效响应"])))
                    return
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    if let data = data {
                        completion(.success(data))
                    } else {
                        completion(.success(Data()))
                    }
                } else {
                    var errorMessage = "请求失败 (HTTP \(httpResponse.statusCode))"
                    if let data = data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let message = json["message"] as? String {
                        errorMessage = message
                    }
                    completion(.failure(NSError(domain: "GitHubAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                }
            }
        }.resume()
    }
    
    // MARK: - 用户信息
    
    func getUserInfo(completion: @escaping (Result<GitHubUser, Error>) -> Void) {
        performRequest(url: APIEndpoints.user.url) { result in
            switch result {
            case .success(let data):
                do {
                    let user = try JSONDecoder().decode(GitHubUser.self, from: data)
                    completion(.success(user))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 仓库列表
    
    func getUserRepos(page: Int = 1, perPage: Int = 100, completion: @escaping (Result<[Repository], Error>) -> Void) {
        performRequest(url: APIEndpoints.userRepos(page: page, perPage: perPage).url) { result in
            switch result {
            case .success(let data):
                do {
                    let repos = try JSONDecoder().decode([Repository].self, from: data)
                    completion(.success(repos))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func searchRepos(query: String, page: Int = 1, sort: String = "", completion: @escaping (Result<[Repository], Error>) -> Void) {
        let url: String
        if sort.isEmpty {
            url = APIEndpoints.searchRepos(query: query, page: page).url
        } else {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            url = "\(APIEndpoints.baseURL)/search/repositories?q=\(encodedQuery)&page=\(page)&per_page=30&sort=\(sort)"
        }

        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let searchResult = try JSONDecoder().decode(SearchResult<Repository>.self, from: data)
                    completion(.success(searchResult.items))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func searchUsers(query: String, page: Int = 1, sort: String = "", completion: @escaping (Result<[GitHubUser], Error>) -> Void) {
        let url: String
        if sort.isEmpty {
            url = APIEndpoints.searchUsers(query: query, page: page).url
        } else {
            let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            url = "\(APIEndpoints.baseURL)/search/users?q=\(encodedQuery)&page=\(page)&per_page=30&sort=\(sort)"
        }

        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let searchResult = try JSONDecoder().decode(SearchResult<GitHubUser>.self, from: data)
                    completion(.success(searchResult.items))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 文件内容
    
    func getFileContent(owner: String, repo: String, path: String, branch: String = "main", completion: @escaping (Result<FileContent, Error>) -> Void) {
        performRequest(url: APIEndpoints.repoContent(owner: owner, repo: repo, path: path, branch: branch).url) { result in
            switch result {
            case .success(let data):
                do {
                    let file = try JSONDecoder().decode(FileContent.self, from: data)
                    completion(.success(file))
                } catch {
                    // 可能是目录
                    if let items = try? JSONDecoder().decode([FileItem].self, from: data) {
                        completion(.failure(NSError(domain: "GitHubAPI", code: -10, userInfo: [NSLocalizedDescriptionKey: "这是一个目录", "files": items])))
                    } else {
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getDirectoryContents(owner: String, repo: String, path: String, branch: String = "main", completion: @escaping (Result<[FileItem], Error>) -> Void) {
        performRequest(url: APIEndpoints.repoContent(owner: owner, repo: repo, path: path, branch: branch).url) { result in
            switch result {
            case .success(let data):
                do {
                    let items = try JSONDecoder().decode([FileItem].self, from: data)
                    completion(.success(items))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 更新文件
    
    func updateFile(owner: String, repo: String, path: String, content: String, sha: String, message: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        let base64Content = content.data(using: .utf8)?.base64EncodedString() ?? ""
        
        let body: [String: Any] = [
            "message": message,
            "content": base64Content,
            "sha": sha,
            "branch": branch
        ]
        
        performRequest(url: APIEndpoints.updateFile(owner: owner, repo: repo, path: path).url, method: "PUT", body: body) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func createFile(owner: String, repo: String, path: String, content: String, message: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        let base64Content = content.data(using: .utf8)?.base64EncodedString() ?? ""

        let body: [String: Any] = [
            "message": message,
            "content": base64Content,
            "branch": branch
        ]

        performRequest(url: APIEndpoints.updateFile(owner: owner, repo: repo, path: path).url, method: "PUT", body: body) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 上传二进制文件（支持任意文件类型）

    func uploadFileData(owner: String, repo: String, path: String, fileData: Data, message: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        let base64Content = fileData.base64EncodedString()

        let body: [String: Any] = [
            "message": message,
            "content": base64Content,
            "branch": branch
        ]

        performRequest(url: APIEndpoints.updateFile(owner: owner, repo: repo, path: path).url, method: "PUT", body: body) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 下载文件原始数据

    func downloadFileData(url: String, completion: @escaping (Result<Data, Error>) -> Void) {
        // 应用镜像加速转换
        let convertedURL = AppSettings.shared.convertDownloadURL(url)

        guard let urlObj = URL(string: convertedURL) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的下载URL"])))
            return
        }

        var request = URLRequest(url: urlObj)
        request.allHTTPHeaderFields = getHeaders()
        request.timeoutInterval = 60

        // 使用镜像专用URLSession，允许无效证书（镜像站点可能证书无效）
        URLSession.mirrorSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode),
                      let data = data else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "文件下载失败"])))
                    return
                }

                completion(.success(data))
            }
        }.resume()
    }

    // MARK: - 创建文件夹（通过创建.gitkeep文件实现）

    func createDirectory(owner: String, repo: String, path: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        let gitkeepPath = path.isEmpty ? ".gitkeep" : "\(path)/.gitkeep"

        createFile(owner: owner, repo: repo, path: gitkeepPath, content: "", message: "创建文件夹: \(path)（通过iOS客户端）", branch: branch, completion: completion)
    }

    // MARK: - 删除文件

    func deleteFile(owner: String, repo: String, path: String, sha: String, message: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        let body: [String: Any] = [
            "message": message,
            "sha": sha,
            "branch": branch
        ]

        performRequest(url: APIEndpoints.updateFile(owner: owner, repo: repo, path: path).url, method: "DELETE", body: body) { result in
            switch result {
            case .success:
                completion(.success(true))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 重命名文件（复制内容到新路径+删除旧文件）

    func renameFile(owner: String, repo: String, oldPath: String, newPath: String, branch: String = "main", completion: @escaping (Result<Bool, Error>) -> Void) {
        // 1. 获取旧文件内容和sha
        getFileContent(owner: owner, repo: repo, path: oldPath, branch: branch) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let fileContent):
                // 2. 创建新文件
                self.createFile(owner: owner, repo: repo, path: newPath, content: fileContent.decodedContent, message: "重命名文件: \(oldPath) → \(newPath)（通过iOS客户端）", branch: branch) { createResult in
                    switch createResult {
                    case .success:
                        // 3. 删除旧文件
                        self.deleteFile(owner: owner, repo: repo, path: oldPath, sha: fileContent.sha, message: "重命名文件: \(oldPath) → \(newPath)（通过iOS客户端）", branch: branch, completion: completion)
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - 获取文件最后修改时间（通过commits API）

    func getFileLastCommit(owner: String, repo: String, path: String, branch: String = "main", completion: @escaping (Result<Commit, Error>) -> Void) {
        let url = "https://api.github.com/repos/\(owner)/\(repo)/commits?path=\(path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path)&sha=\(branch)&per_page=1"

        performRequest(url: url, method: "GET", body: nil) { result in
            switch result {
            case .success(let data):
                do {
                    let commits = try JSONDecoder().decode([Commit].self, from: data)
                    if let commit = commits.first {
                        completion(.success(commit))
                    } else {
                        completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到提交记录"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 分支
    
    func getBranches(owner: String, repo: String, completion: @escaping (Result<[Branch], Error>) -> Void) {
        performRequest(url: APIEndpoints.repoBranches(owner: owner, repo: repo).url) { result in
            switch result {
            case .success(let data):
                do {
                    let branches = try JSONDecoder().decode([Branch].self, from: data)
                    completion(.success(branches))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - 提交记录
    
    func getCommits(owner: String, repo: String, path: String? = nil, completion: @escaping (Result<[Commit], Error>) -> Void) {
        performRequest(url: APIEndpoints.commits(owner: owner, repo: repo, path: path).url) { result in
            switch result {
            case .success(let data):
                do {
                    let commits = try JSONDecoder().decode([Commit].self, from: data)
                    completion(.success(commits))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - GitHub Actions 相关 API

    /// 获取仓库的工作流列表
    func getWorkflows(owner: String, repo: String, completion: @escaping (Result<[Workflow], Error>) -> Void) {
        performRequest(url: APIEndpoints.workflows(owner: owner, repo: repo).url) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(WorkflowsResponse.self, from: data)
                    completion(.success(response.workflows))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取仓库的所有工作流运行记录
    func getWorkflowRuns(owner: String, repo: String, page: Int = 1, perPage: Int = 30, completion: @escaping (Result<[WorkflowRun], Error>) -> Void) {
        let url = APIEndpoints.workflowRuns(owner: owner, repo: repo, page: page, perPage: perPage).url
        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
                    completion(.success(response.workflowRuns))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取指定工作流的运行记录
    func getWorkflowRunsForWorkflow(owner: String, repo: String, workflowId: Int, page: Int = 1, perPage: Int = 30, completion: @escaping (Result<[WorkflowRun], Error>) -> Void) {
        let url = APIEndpoints.workflowRunsForWorkflow(owner: owner, repo: repo, workflowId: workflowId, page: page, perPage: perPage).url
        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(WorkflowRunsResponse.self, from: data)
                    completion(.success(response.workflowRuns))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取单个工作流运行详情
    func getWorkflowRun(owner: String, repo: String, runId: Int, completion: @escaping (Result<WorkflowRun, Error>) -> Void) {
        performRequest(url: APIEndpoints.workflowRun(owner: owner, repo: repo, runId: runId).url) { result in
            switch result {
            case .success(let data):
                do {
                    let run = try JSONDecoder().decode(WorkflowRun.self, from: data)
                    completion(.success(run))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取工作流运行的作业列表
    func getWorkflowJobs(owner: String, repo: String, runId: Int, completion: @escaping (Result<[WorkflowJob], Error>) -> Void) {
        performRequest(url: APIEndpoints.workflowJobs(owner: owner, repo: repo, runId: runId).url) { result in
            switch result {
            case .success(let data):
                do {
                    let response = try JSONDecoder().decode(WorkflowJobsResponse.self, from: data)
                    completion(.success(response.jobs))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取作业日志（纯文本）
    func getJobLogs(owner: String, repo: String, jobId: Int, completion: @escaping (Result<String, Error>) -> Void) {
        let url = APIEndpoints.jobLogs(owner: owner, repo: repo, jobId: jobId).url
        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                if let logs = String(data: data, encoding: .utf8) {
                    completion(.success(logs))
                } else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "日志数据解析失败"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 触发工作流运行（workflow_dispatch）
    func triggerWorkflowDispatch(owner: String, repo: String, workflowId: Int, ref: String = "main", inputs: [String: String] = [:], completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.workflowDispatch(owner: owner, repo: repo, workflowId: workflowId).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["ref": ref]
        if !inputs.isEmpty {
            body["inputs"] = inputs
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "触发工作流失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }

    /// 取消工作流运行
    func cancelWorkflowRun(owner: String, repo: String, runId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.cancelWorkflowRun(owner: owner, repo: repo, runId: runId).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "取消运行失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }

    /// 重新运行工作流
    func rerunWorkflowRun(owner: String, repo: String, runId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.rerunWorkflowRun(owner: owner, repo: repo, runId: runId).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "重新运行失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }

    // MARK: - 仓库交互相关 API

    /// 检查仓库是否已被星标
    func checkStarred(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.checkStarred(owner: owner, repo: repo).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    completion(.success(true)) // 已星标
                } else if httpResponse.statusCode == 404 {
                    completion(.success(false)) // 未星标
                } else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "检查星标状态失败，状态码: \(httpResponse.statusCode)"])))
                }
            }
        }.resume()
    }

    /// 星标仓库
    func starRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.starRepository(owner: owner, repo: repo).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "PUT"
        request.allHTTPHeaderFields = getHeaders()

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "星标仓库失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }

    /// 取消星标仓库
    func unstarRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.unstarRepository(owner: owner, repo: repo).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getHeaders()

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "取消星标失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }

    /// Fork 仓库
    func forkRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.forkRepository(owner: owner, repo: repo).url
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }
        var request = URLRequest(url: urlObj)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                completion(.success(true))
            } else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                completion(.failure(NSError(domain: "GitHubAPI", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Fork仓库失败，状态码: \(statusCode)"])))
            }
        }.resume()
    }
}

// MARK: - 搜索结果包装

struct SearchResult<T: Codable>: Codable {
    let totalCount: Int
    let items: [T]
    
    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}
