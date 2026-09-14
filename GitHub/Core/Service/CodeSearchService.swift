import Foundation

final class CodeSearchService {
    static let shared = CodeSearchService()
    private init() {}

    func searchCode(
        owner: String,
        repo: String,
        query: String,
        branch: String? = nil
    ) async throws -> [CodeSearchFile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "CodeSearch", code: -1, userInfo: [NSLocalizedDescriptionKey: "搜索词不能为空"])
        }

        var components = URLComponents(string: "https://api.github.com/search/code")!
        var q = "repo:\(owner)/\(repo) \(trimmed)"
        if let branch = branch, !branch.isEmpty {
            q += " branch:\(branch)"
        }
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
        return result.items
    }

    func getFileContent(
        owner: String,
        repo: String,
        path: String,
        branch: String
    ) async throws -> String {
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
        return file.decodedContent
    }

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
