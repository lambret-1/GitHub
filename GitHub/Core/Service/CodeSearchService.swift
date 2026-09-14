import Foundation

// MARK: - 代码搜索服务

/// 代码搜索服务，封装搜索API调用、文件内容获取、片段提取等业务逻辑
final class CodeSearchService {
    // 单例
    static let shared = CodeSearchService()

    // 搜索结果缓存：query -> CachedSearchResult，TTL 5分钟
    private var searchCache: [String: CachedSearchResult] = [:]
    // 文件内容缓存：path -> (content, timestamp)，TTL 10分钟
    private var fileContentCache: [String: (content: String, timestamp: Date)] = [:]
    // 片段提取缓存：path+query -> [CodeSnippet]，TTL 10分钟
    private var snippetCache: [String: [CodeSnippet]] = [:]

    // 缓存配置
    private let searchCacheTTL: TimeInterval = 300      // 搜索缓存5分钟
    private let fileCacheTTL: TimeInterval = 600         // 文件缓存10分钟
    private let maxSearchCacheSize = 50                   // 搜索缓存最大条数
    private let maxFileCacheSize = 20                      // 文件缓存最大条数

    private init() {}

    // MARK: - 搜索代码

    /// 在指定仓库内搜索代码
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - query: 搜索关键词
    ///   - branch: 分支名称（可选）
    ///   - page: 页码
    ///   - perPage: 每页数量
    /// - Returns: 搜索结果数组
    func search(
        owner: String,
        repo: String,
        query: String,
        branch: String? = nil,
        page: Int = 1,
        perPage: Int = 30
    ) async throws -> [CodeSearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            throw CodeSearchError.emptyQuery
        }

        // 构建缓存键
        let cacheKey = "\(owner)/\(repo):\(trimmedQuery):\(branch ?? "default"):\(page)"

        // 检查缓存
        if let cached = searchCache[cacheKey], !cached.isExpired(ttl: searchCacheTTL) {
            return cached.results
        }

        // 使用URLComponents构建URL，确保查询参数正确编码
        guard var urlComponents = URLComponents(string: "https://api.github.com/search/code") else {
            throw CodeSearchError.invalidURL
        }

        // 构建查询字符串：repo:owner/repo query [branch:xxx]
        var queryString = "repo:\(owner)/\(repo) \(trimmedQuery)"
        if let branch = branch, !branch.isEmpty {
            queryString += " branch:\(branch)"
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: queryString),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)")
        ]

        guard let url = urlComponents.url?.absoluteString else {
            throw CodeSearchError.invalidURL
        }

        // 执行网络请求
        let data = try await performRequest(url: url)

        // 解析响应
        do {
            let searchResult = try JSONDecoder().decode(CodeSearchResultResponse.self, from: data)
            let results = searchResult.items.map { item in
                CodeSearchResult.fromAPIItem(item, owner: owner, repo: repo)
            }

            // 写入缓存
            searchCache[cacheKey] = CachedSearchResult(
                results: results,
                timestamp: Date(),
                query: trimmedQuery
            )

            // 清理过期缓存和超出大小限制的缓存
            cleanupCache()

            return results
        } catch {
            throw CodeSearchError.parsingError(error)
        }
    }

    // MARK: - 获取文件内容

    /// 获取指定文件的内容
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - path: 文件路径
    ///   - branch: 分支名称
    /// - Returns: 文件内容字符串
    func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String
    ) async throws -> String {
        // 构建缓存键
        let cacheKey = "\(owner)/\(repo):\(path):\(branch)"

        // 检查缓存
        if let cached = fileContentCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < fileCacheTTL {
            return cached.content
        }

        // 构建URL
        guard var urlComponents = URLComponents(
            string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)"
        ) else {
            throw CodeSearchError.invalidURL
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "ref", value: branch)
        ]

        guard let url = urlComponents.url?.absoluteString else {
            throw CodeSearchError.invalidURL
        }

        // 执行网络请求
        let data = try await performRequest(url: url)

        // 解析文件内容
        do {
            let fileContent = try JSONDecoder().decode(FileContent.self, from: data)
            let content = fileContent.decodedContent

            // 写入缓存
            fileContentCache[cacheKey] = (content: content, timestamp: Date())

            // 清理缓存
            cleanupFileCache()

            return content
        } catch {
            // 可能是目录
            if let items = try? JSONDecoder().decode([FileItem].self, from: data) {
                throw CodeSearchError.fileNotFound
            }
            throw CodeSearchError.parsingError(error)
        }
    }

    // MARK: - 提取代码片段

    /// 从文件内容中提取包含搜索关键词的代码片段
    /// - Parameters:
    ///   - content: 文件内容
    ///   - query: 搜索关键词
    ///   - contextLines: 上下文行数（前后各N行）
    /// - Returns: 代码片段数组
    func extractSnippets(
        content: String,
        query: String,
        contextLines: Int = 2
    ) -> [CodeSnippet] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return []
        }

        // 按行分割
        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else {
            return []
        }

        // 一次遍历找出所有匹配行
        var matchLineIndices: [Int] = []
        for (index, line) in lines.enumerated() {
            if line.range(of: trimmedQuery, options: .caseInsensitive) != nil {
                matchLineIndices.append(index)
            }
        }

        guard !matchLineIndices.isEmpty else {
            return []
        }

        // 合并连续匹配行（间隔<=1的合并为一个片段）
        var mergedRanges: [(start: Int, end: Int)] = []
        var rangeStart = matchLineIndices[0]
        var previousIndex = matchLineIndices[0]

        for index in matchLineIndices.dropFirst() {
            if index - previousIndex <= 1 {
                // 连续，扩展当前区间
                previousIndex = index
            } else {
                // 不连续，结束上一个区间
                mergedRanges.append((start: rangeStart, end: previousIndex))
                rangeStart = index
                previousIndex = index
            }
        }
        // 处理最后一个区间
        mergedRanges.append((start: rangeStart, end: previousIndex))

        // 对每个合并区间生成代码片段（包含上下文行）
        var snippets: [CodeSnippet] = []
        for range in mergedRanges {
            let contextStart = max(0, range.start - contextLines)
            let contextEnd = min(lines.count - 1, range.end + contextLines)

            var codeLines: [CodeLine] = []
            var matchNumbers: [Int] = []

            for lineIndex in contextStart...contextEnd {
                let isMatch = matchLineIndices.contains(lineIndex)
                if isMatch {
                    matchNumbers.append(lineIndex + 1) // 行号从1开始
                }
                codeLines.append(CodeLine(
                    lineNumber: lineIndex + 1,
                    content: lines[lineIndex],
                    isMatch: isMatch
                ))
            }

            snippets.append(CodeSnippet(
                startLine: contextStart + 1,
                endLine: contextEnd + 1,
                lines: codeLines,
                matchLineNumbers: matchNumbers
            ))

            // 最多显示20个片段
            if snippets.count >= 20 {
                break
            }
        }

        return snippets
    }

    // MARK: - 取消所有请求

    /// 取消所有进行中的请求（通过取消Task实现）
    func cancelAll() {
        // 缓存保留，不清除
    }

    // MARK: - 清除缓存

    /// 清除所有缓存
    func clearCache() {
        searchCache.removeAll()
        fileContentCache.removeAll()
        snippetCache.removeAll()
    }

    // MARK: - 私有方法

    /// 执行网络请求（async/await封装）
    private func performRequest(url: String) async throws -> Data {
        guard let urlObj = URL(string: url) else {
            throw CodeSearchError.invalidURL
        }

        var request = URLRequest(url: urlObj)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw CodeSearchError.networkError(NSError(domain: "CodeSearch", code: -1))
            }

            // 处理HTTP状态码
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw CodeSearchError.unauthorized
            case 403:
                // 检查是否是速率限制
                if let remaining = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
                   remaining == "0" {
                    throw CodeSearchError.rateLimited
                }
                throw CodeSearchError.httpError(httpResponse.statusCode, "请求被拒绝")
            case 422:
                throw CodeSearchError.httpError(httpResponse.statusCode, "搜索词格式不正确")
            default:
                // 尝试解析错误消息
                var errorMessage = "请求失败"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let message = json["message"] as? String {
                    errorMessage = message
                }
                throw CodeSearchError.httpError(httpResponse.statusCode, errorMessage)
            }
        } catch let error as CodeSearchError {
            throw error
        } catch {
            throw CodeSearchError.networkError(error)
        }
    }

    /// 获取请求头
    private func getHeaders() -> [String: String] {
        guard let token = TokenKeychain.shared.getToken() else {
            return [
                "Accept": "application/vnd.github.v3+json",
                "User-Agent": "GitHub-iOS-Client",
                "Cache-Control": "no-cache, no-store, must-revalidate"
            ]
        }
        return [
            "Authorization": "token \(token)",
            "Accept": "application/vnd.github.v3+json",
            "User-Agent": "GitHub-iOS-Client",
            "Cache-Control": "no-cache, no-store, must-revalidate"
        ]
    }

    /// 清理搜索缓存（过期+超出大小限制）
    private func cleanupCache() {
        // 移除过期缓存
        searchCache = searchCache.filter { !$0.value.isExpired(ttl: searchCacheTTL) }

        // 如果超出大小限制，移除最旧的
        if searchCache.count > maxSearchCacheSize {
            let sorted = searchCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(searchCache.count - maxSearchCacheSize)
            for item in toRemove {
                searchCache.removeValue(forKey: item.key)
            }
        }
    }

    /// 清理文件缓存（过期+超出大小限制）
    private func cleanupFileCache() {
        // 移除过期缓存
        fileContentCache = fileContentCache.filter {
            Date().timeIntervalSince($0.value.timestamp) < fileCacheTTL
        }

        // 如果超出大小限制，移除最旧的
        if fileContentCache.count > maxFileCacheSize {
            let sorted = fileContentCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let toRemove = sorted.prefix(fileContentCache.count - maxFileCacheSize)
            for item in toRemove {
                fileContentCache.removeValue(forKey: item.key)
            }
        }
    }
}

// MARK: - GitHub API搜索响应模型

/// GitHub代码搜索API响应
private struct CodeSearchResultResponse: Codable {
    let totalCount: Int
    let incompleteResults: Bool
    let items: [CodeSearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case incompleteResults = "incomplete_results"
        case items
    }
}
