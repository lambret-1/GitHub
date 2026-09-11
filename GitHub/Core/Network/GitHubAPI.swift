import Foundation

class GitHubAPI {
    static let shared = GitHubAPI()

    private init() {}

    /// 防止多个请求同时返回401时重复处理的标志
    private var isHandling401: Bool = false

    /// 处理401未授权错误：清除token并跳转到登录页面
    private func handleUnauthorizedError() {
        // 防止重复处理
        guard !isHandling401 else { return }
        isHandling401 = true

        DispatchQueue.main.async {
            // 清除token
            TokenKeychain.shared.deleteToken()

            // 从AccountManager中删除当前账号
            if let currentAccount = AccountManager.shared.currentAccount {
                AccountManager.shared.deleteAccount(currentAccount)
            }

            // 更新AppState登录状态
            AppState.shared.currentUser = nil
            AppState.shared.isLoggedIn = false

            // 延迟重置标志，允许后续重新登录
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.isHandling401 = false
            }
        }
    }

    /// 通用简单请求方法：处理只返回成功/失败的API请求，自动处理401错误
    private func performSimpleRequest(url: String, method: String = "GET", body: [String: Any]? = nil, successMessage: String = "操作成功", failureMessage: String = "操作失败", completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = method
        request.allHTTPHeaderFields = getHeaders()
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据

        if let body = body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "无效响应"])))
                    return
                }

                // 检测401未授权错误
                if httpResponse.statusCode == 401 {
                    self.handleUnauthorizedError()
                    completion(.failure(NSError(domain: "GitHubAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新登录"])))
                    return
                }

                if (200...299).contains(httpResponse.statusCode) {
                    completion(.success(true))
                } else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "\(failureMessage)，状态码: \(httpResponse.statusCode)"])))
                }
            }
        }.resume()
    }

    private func getHeaders() -> [String: String] {
        guard let token = TokenKeychain.shared.getToken() else {
            return [
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "GitHub-iOS-Client",
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache"
            ]
        }
        return [
            "Authorization": "token \(token)",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "GitHub-iOS-Client",
            "Cache-Control": "no-cache, no-store, must-revalidate",
            "Pragma": "no-cache"
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
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据
        
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
                    // 检测401未授权错误：token失效或权限不足
                    if httpResponse.statusCode == 401 {
                        self.handleUnauthorizedError()
                        completion(.failure(NSError(domain: "GitHubAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新登录"])))
                        return
                    }

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
    
    // MARK: - 仓库信息

    /// 获取仓库信息（包括默认分支）
    func getRepository(owner: String, repo: String, completion: @escaping (Result<Repository, Error>) -> Void) {
        performRequest(url: APIEndpoints.repository(owner: owner, repo: repo).url) { result in
            switch result {
            case .success(let data):
                do {
                    let repository = try JSONDecoder().decode(Repository.self, from: data)
                    completion(.success(repository))
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 获取仓库README内容（Markdown原文）
    func getReadme(owner: String, repo: String, branch: String? = nil, path: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        performRequest(url: APIEndpoints.readme(owner: owner, repo: repo, branch: branch, path: path).url) { result in
            switch result {
            case .success(let data):
                do {
                    let fileContent = try JSONDecoder().decode(FileContent.self, from: data)
                    // 解码Base64内容
                    if let content = fileContent.content,
                       let encoding = fileContent.encoding,
                       encoding == "base64",
                       let decodedData = Data(base64Encoded: content, options: .ignoreUnknownCharacters),
                       let decodedString = String(data: decodedData, encoding: .utf8) {
                        completion(.success(decodedString))
                    } else if let downloadUrl = fileContent.downloadUrl {
                        // 如果内容太大，API会返回download_url，需要单独下载
                        self.downloadRawContent(url: downloadUrl, completion: completion)
                    } else {
                        completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析README内容"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 下载原始内容（用于大文件）
    private func downloadRawContent(url: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }

        var request = URLRequest(url: urlObj)
        request.allHTTPHeaderFields = getHeaders()
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data, let content = String(data: data, encoding: .utf8) else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法读取内容"])))
                    return
                }

                completion(.success(content))
            }
        }.resume()
    }

    /// 使用GitHub官方Markdown API渲染Markdown文本（与GitHub网页显示完全一致）
    /// - Parameters:
    ///   - markdown: Markdown原文
    ///   - context: 仓库上下文（owner/repo），用于解析相对链接
    ///   - completion: 渲染后的HTML
    func renderMarkdown(markdown: String, context: String? = nil, completion: @escaping (Result<String, Error>) -> Void) {
        var body: [String: Any] = [
            "text": markdown,
            "mode": "gfm"
        ]
        if let context = context {
            body["context"] = context
        }

        performRequest(url: APIEndpoints.markdown.url, method: "POST", body: body) { result in
            switch result {
            case .success(let data):
                if let html = String(data: data, encoding: .utf8) {
                    completion(.success(html))
                } else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析Markdown渲染结果"])))
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

    /// 搜索代码
    func searchCode(query: String, page: Int = 1, completion: @escaping (Result<[CodeSearchItem], Error>) -> Void) {
        let url = APIEndpoints.searchCode(query: query, page: page).url

        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    let searchResult = try JSONDecoder().decode(CodeSearchResult.self, from: data)
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
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据

        // 使用镜像专用URLSession，允许无效证书（镜像站点可能证书无效）
        URLSession.mirrorSession.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(NSError(domain: "GitHubAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "文件下载失败"])))
                    return
                }

                // 检测401未授权错误
                if httpResponse.statusCode == 401 {
                    self.handleUnauthorizedError()
                    completion(.failure(NSError(domain: "GitHubAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新登录"])))
                    return
                }

                guard (200...299).contains(httpResponse.statusCode),
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

    /// 创建新分支（基于指定分支）
    func createBranch(owner: String, repo: String, newBranchName: String, fromBranch: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // 先获取源分支的最新commit SHA
        let url = APIEndpoints.repoBranches(owner: owner, repo: repo).url + "/\(fromBranch.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fromBranch)"
        performRequest(url: url) { result in
            switch result {
            case .success(let data):
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let commit = json["commit"] as? [String: Any],
                       let sha = commit["sha"] as? String {
                        // 创建新分支
                        let createUrl = APIEndpoints.createBranch(owner: owner, repo: repo).url
                        let body: [String: Any] = [
                            "ref": "refs/heads/\(newBranchName)",
                            "sha": sha
                        ]
                        self.performSimpleRequest(url: createUrl, method: "POST", body: body, failureMessage: "创建分支失败", completion: completion)
                    } else {
                        completion(.failure(NSError(domain: "GitHubAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取源分支的commit SHA"])))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// 重命名分支
    func renameBranch(owner: String, repo: String, oldBranchName: String, newBranchName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.renameBranch(owner: owner, repo: repo, branch: oldBranchName).url
        let body: [String: Any] = [
            "new_name": newBranchName
        ]
        performSimpleRequest(url: url, method: "POST", body: body, failureMessage: "重命名分支失败", completion: completion)
    }

    /// 删除分支
    func deleteBranch(owner: String, repo: String, branchName: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.deleteBranch(owner: owner, repo: repo, branch: branchName).url
        performSimpleRequest(url: url, method: "DELETE", failureMessage: "删除分支失败", completion: completion)
    }
    
    // MARK: - 提交记录
    
    func getCommits(owner: String, repo: String, path: String? = nil, branch: String? = nil, perPage: Int? = nil, completion: @escaping (Result<[Commit], Error>) -> Void) {
        performRequest(url: APIEndpoints.commits(owner: owner, repo: repo, path: path, branch: branch, perPage: perPage).url) { result in
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
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据

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
        performSimpleRequest(url: url, method: "POST", failureMessage: "取消运行失败", completion: completion)
    }

    /// 重新运行工作流
    func rerunWorkflowRun(owner: String, repo: String, runId: Int, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.rerunWorkflowRun(owner: owner, repo: repo, runId: runId).url
        performSimpleRequest(url: url, method: "POST", failureMessage: "重新运行失败", completion: completion)
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
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // 禁用缓存，确保每次刷新都获取最新数据

        URLSession.shared.dataTask(with: request) { _, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    // 检测401未授权错误
                    if httpResponse.statusCode == 401 {
                        self.handleUnauthorizedError()
                        completion(.failure(NSError(domain: "GitHubAPI", code: 401, userInfo: [NSLocalizedDescriptionKey: "登录已过期，请重新登录"])))
                        return
                    }

                    if httpResponse.statusCode == 204 {
                        completion(.success(true)) // 已星标
                    } else if httpResponse.statusCode == 404 {
                        completion(.success(false)) // 未星标
                    } else {
                        completion(.failure(NSError(domain: "GitHubAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "检查星标状态失败，状态码: \(httpResponse.statusCode)"])))
                    }
                }
            }
        }.resume()
    }

    /// 星标仓库
    func starRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.starRepository(owner: owner, repo: repo).url
        performSimpleRequest(url: url, method: "PUT", failureMessage: "星标仓库失败", completion: completion)
    }

    /// 取消星标仓库
    func unstarRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.unstarRepository(owner: owner, repo: repo).url
        performSimpleRequest(url: url, method: "DELETE", failureMessage: "取消星标失败", completion: completion)
    }

    /// Fork 仓库
    func forkRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.forkRepository(owner: owner, repo: repo).url
        performSimpleRequest(url: url, method: "POST", failureMessage: "Fork仓库失败", completion: completion)
    }

    /// 删除仓库（需要admin权限）
    func deleteRepository(owner: String, repo: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.deleteRepository(owner: owner, repo: repo).url
        performSimpleRequest(url: url, method: "DELETE", failureMessage: "删除仓库失败", completion: completion)
    }

    /// 更新仓库信息（重命名、设置公开/私有等，需要admin权限）
    func updateRepository(owner: String, repo: String, name: String? = nil, description: String? = nil, isPrivate: Bool? = nil, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.updateRepository(owner: owner, repo: repo).url
        var body: [String: Any] = [:]
        if let name = name {
            body["name"] = name
        }
        if let description = description {
            body["description"] = description
        }
        if let isPrivate = isPrivate {
            body["private"] = isPrivate
        }
        performSimpleRequest(url: url, method: "PATCH", body: body, failureMessage: "更新仓库失败", completion: completion)
    }

    /// 创建新仓库
    func createRepository(name: String, description: String = "", isPrivate: Bool = false, autoInit: Bool = true, completion: @escaping (Result<Bool, Error>) -> Void) {
        let url = APIEndpoints.createRepository.url
        var body: [String: Any] = [
            "name": name,
            "description": description,
            "private": isPrivate,
            "auto_init": autoInit
        ]
        performSimpleRequest(url: url, method: "POST", body: body, failureMessage: "创建仓库失败", completion: completion)
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
