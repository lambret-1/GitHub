import Foundation

final class CodeSearchService {
    static let shared = CodeSearchService()
    private init() {}

    // MARK: - 文件内容缓存（1分钟过期）

    private var fileContentCache: [String: FileContentCacheItem] = [:]
    private let cacheExpirationInterval: TimeInterval = 60 // 缓存过期时间60秒

    // 清除所有文件内容缓存（用户主动刷新时调用）
    func clearAllFileContentCache() {
        fileContentCache.removeAll()
    }

    // 清除指定文件的缓存
    func clearFileContentCache(owner: String, repo: String, path: String, branch: String) {
        let key = "\(owner)/\(repo)/\(path)@\(branch)"
        fileContentCache.removeValue(forKey: key)
    }

    // 获取文件内容（带缓存）
    func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String
    ) async throws -> String {
        let cacheKey = "\(owner)/\(repo)/\(path)@\(branch)"

        // 检查缓存是否存在且未过期
        if let cached = fileContentCache[cacheKey], !cached.isExpired {
            return cached.content
        }

        // 缓存不存在或已过期，重新请求
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)")!
        components.queryItems = [URLQueryItem(name: "ref", value: branch)]

        guard let url = components.url else {
            throw NSError(domain: "CodeSearch", code: -4, userInfo: [NSLocalizedDescriptionKey: "URL构建失败"])
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let file = try JSONDecoder().decode(FileContent.self, from: data)

        // 存入缓存
        let cacheItem = FileContentCacheItem(
            content: file.decodedContent,
            timestamp: Date(),
            owner: owner,
            repo: repo,
            path: path,
            branch: branch
        )
        fileContentCache[cacheKey] = cacheItem

        return file.decodedContent
    }

    // MARK: - 搜索历史记录

    private let searchHistoryKey = "CodeSearchHistory"
    private let maxSearchHistoryCount = 20 // 最多保存20条历史记录

    // 获取搜索历史记录（按时间倒序）
    func getSearchHistory() -> [SearchHistoryItem] {
        guard let data = UserDefaults.standard.data(forKey: searchHistoryKey) else {
            return []
        }
        do {
            let history = try JSONDecoder().decode([SearchHistoryItem].self, from: data)
            return history.sorted { $0.timestamp > $1.timestamp }
        } catch {
            return []
        }
    }

    // 添加搜索历史记录
    func addSearchHistory(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var history = getSearchHistory()

        // 移除相同的搜索词（避免重复）
        history.removeAll { $0.query == trimmed }

        // 添加新记录
        let newItem = SearchHistoryItem(query: trimmed)
        history.insert(newItem, at: 0)

        // 限制最大数量
        if history.count > maxSearchHistoryCount {
            history = Array(history.prefix(maxSearchHistoryCount))
        }

        // 保存
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: searchHistoryKey)
        } catch {
            // 保存失败静默处理
        }
    }

    // 清除所有搜索历史记录
    func clearSearchHistory() {
        UserDefaults.standard.removeObject(forKey: searchHistoryKey)
    }

    // 删除单条搜索历史记录
    func removeSearchHistory(_ item: SearchHistoryItem) {
        var history = getSearchHistory()
        history.removeAll { $0.id == item.id }
        do {
            let data = try JSONEncoder().encode(history)
            UserDefaults.standard.set(data, forKey: searchHistoryKey)
        } catch {
            // 保存失败静默处理
        }
    }

    // MARK: - 搜索建议

    // 常用搜索关键词建议
    private let commonSearchSuggestions = [
        "func",
        "class",
        "struct",
        "import",
        "let",
        "var",
        "if",
        "for",
        "while",
        "switch",
        "return",
        "print",
        "TODO",
        "FIXME",
        "MARK"
    ]

    // 获取搜索建议（基于输入前缀匹配历史记录和常用关键词）
    func getSearchSuggestions(for prefix: String) -> [String] {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            // 输入为空时返回历史记录（前10条）
            return Array(getSearchHistory().prefix(10).map { $0.query })
        }

        var suggestions: [String] = []

        // 从历史记录中匹配
        let historyMatches = getSearchHistory()
            .filter { $0.query.lowercased().hasPrefix(trimmed.lowercased()) }
            .map { $0.query }
        suggestions.append(contentsOf: historyMatches)

        // 从常用关键词中匹配
        let commonMatches = commonSearchSuggestions
            .filter { $0.lowercased().hasPrefix(trimmed.lowercased()) }
        suggestions.append(contentsOf: commonMatches)

        // 去重并限制数量
        var uniqueSuggestions: [String] = []
        var seen = Set<String>()
        for suggestion in suggestions {
            if !seen.contains(suggestion.lowercased()) {
                seen.insert(suggestion.lowercased())
                uniqueSuggestions.append(suggestion)
            }
        }

        return Array(uniqueSuggestions.prefix(10))
    }

    // MARK: - 搜索结果排序

    // 对搜索结果进行排序
    func sortSearchResults(_ results: [CodeSearchFile], sortOption: CodeSearchSortOption) -> [CodeSearchFile] {
        switch sortOption {
        case .updated:
            // 按更新时间降序（GitHub API默认按相关性排序，这里按路径倒序模拟最新）
            // 注意：GitHub代码搜索API不直接返回更新时间，这里按sha倒序近似
            return results.sorted { $0.sha > $1.sha }
        case .path:
            // 按文件路径字母顺序升序
            return results.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
        case .relevance:
            // 按相关性（保持GitHub API返回的原始顺序）
            return results
        }
    }

    // MARK: - 搜索代码

    func searchCode(
        owner: String,
        repo: String,
        query: String,
        branch: String? = nil,
        sortOption: CodeSearchSortOption = .updated
    ) async throws -> [CodeSearchFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "CodeSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "搜索词不能为空"])
        }

        // 注意：GitHub代码搜索API的branch筛选器存在索引延迟问题，可能返回0结果
        // 因此暂不使用branch筛选器，搜索默认分支（通常是main/master）
        var components = URLComponents(string: "https://api.github.com/search/code")!
        let q = "repo:\(owner)/\(repo) \(trimmed)"
        components.queryItems = [
            URLQueryItem(name: "q", value: q),
            URLQueryItem(name: "per_page", value: "30")
        ]

        guard let url = components.url else {
            throw NSError(domain: "CodeSearch", code: -2, userInfo: [NSLocalizedDescriptionKey: "URL构建失败"])
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "CodeSearch", code: -3, userInfo: [NSLocalizedDescriptionKey: "无效响应"])
        }
        guard (200...299).contains(http.statusCode) else {
            let msg = "请求失败(\(http.statusCode))"
            throw NSError(domain: "CodeSearch", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let result = try JSONDecoder().decode(CodeSearchResponse.self, from: data)

        // 保存搜索历史记录
        addSearchHistory(trimmed)

        // 按指定选项排序
        return sortSearchResults(result.items, sortOption: sortOption)
    }

    // MARK: - 获取文件最后编辑时间

    // Git提交信息模型
    private struct GitCommit: Codable {
        let commit: CommitDetail

        struct CommitDetail: Codable {
            let committer: Committer
        }

        struct Committer: Codable {
            let date: String
        }
    }

    // 获取单个文件的最后编辑时间（通过commits API）
    func getFileLastModified(
        owner: String,
        repo: String,
        path: String,
        branch: String
    ) async throws -> Date? {
        var components = URLComponents(string: "https://api.github.com/repos/\(owner)/\(repo)/commits")!
        components.queryItems = [
            URLQueryItem(name: "path", value: path),
            URLQueryItem(name: "sha", value: branch),
            URLQueryItem(name: "per_page", value: "1")
        ]

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        let commits = try JSONDecoder().decode([GitCommit].self, from: data)
        guard let firstCommit = commits.first else {
            return nil
        }

        // 解析ISO 8601日期格式
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.date(from: firstCommit.commit.committer.date)
    }

    // 批量获取文件最后编辑时间（并发请求，提升性能）
    func loadLastModifiedForFiles(
        _ files: [CodeSearchFile],
        owner: String,
        repo: String,
        branch: String
    ) async -> [CodeSearchFile] {
        var updatedFiles = files

        // 使用withTaskGroup并发请求（搜索结果最多30个，不会超过GitHub API速率限制）
        await withTaskGroup(of: (Int, Date?).self) { group in
            for (index, file) in files.enumerated() {
                group.addTask {
                    do {
                        let date = try await self.getFileLastModified(
                            owner: owner,
                            repo: repo,
                            path: file.path,
                            branch: branch
                        )
                        return (index, date)
                    } catch {
                        return (index, nil)
                    }
                }
            }

            // 收集剩余结果
            for await result in group {
                if let date = result.1 {
                    updatedFiles[result.0].lastModified = date
                }
            }
        }

        return updatedFiles
    }

    // MARK: - 代码片段提取

    func extractSnippets(content: String, query: String, contextLines: Int = 2) -> [CodeSnippet] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lines = content.components(separatedBy: .newlines)
        guard !lines.isEmpty else { return [] }

        var matchIndices: [Int] = []
        for (i, line) in lines.enumerated() {
            if line.range(of: trimmed, options: .caseInsensitive) != nil {
                matchIndices.append(i)
            }
        }
        guard !matchIndices.isEmpty else { return [] }

        var ranges: [(start: Int, end: Int)] = []
        var start = matchIndices[0]
        var prev = matchIndices[0]
        for idx in matchIndices.dropFirst() {
            if idx - prev > 1 {
                ranges.append((start, prev))
                start = idx
            }
            prev = idx
        }
        ranges.append((start, prev))

        var snippets: [CodeSnippet] = []
        for range in ranges.prefix(20) {
            let ctxStart = max(0, range.start - contextLines)
            let ctxEnd = min(lines.count - 1, range.end + contextLines)
            var codeLines: [CodeLine] = []
            for i in ctxStart...ctxEnd {
                codeLines.append(CodeLine(
                    lineNumber: i + 1,
                    content: lines[i],
                    isMatch: matchIndices.contains(i)
                ))
            }
            snippets.append(CodeSnippet(
                startLine: ctxStart + 1,
                endLine: ctxEnd + 1,
                lines: codeLines
            ))
        }
        return snippets
    }
}
