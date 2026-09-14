import Foundation

// MARK: - 搜索状态枚举

/// 搜索状态机，明确管理搜索的各个阶段
enum SearchState: Equatable {
    case idle              // 初始状态，未搜索
    case searching         // 搜索中
    case success           // 搜索成功（有结果）
    case empty             // 搜索成功但无结果
    case error(String)     // 搜索失败（带错误信息）

    static func == (lhs: SearchState, rhs: SearchState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.searching, .searching),
             (.success, .success),
             (.empty, .empty):
            return true
        case let (.error(lhsMsg), .error(rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }
}

// MARK: - 代码搜索错误类型

/// 代码搜索错误类型，分层管理各种错误
enum CodeSearchError: LocalizedError {
    case invalidURL                    // 无效URL
    case networkError(Error)           // 网络错误
    case httpError(Int, String)        // HTTP错误（状态码+消息）
    case parsingError(Error)           // 数据解析错误
    case rateLimited                    // 速率限制
    case unauthorized                   // 未授权
    case emptyQuery                     // 空查询
    case cancelled                      // 任务被取消
    case fileNotFound                   // 文件不存在
    case fileTooLarge                   // 文件过大

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL构建失败，请重试"
        case .networkError:
            return "网络连接失败，请检查网络后重试"
        case .httpError(let code, let message):
            return "请求失败（\(code)）：\(message)"
        case .parsingError:
            return "数据解析失败，请重试"
        case .rateLimited:
            return "请求过于频繁，请稍后再试"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .emptyQuery:
            return "请输入搜索关键词"
        case .cancelled:
            return "请求已取消"
        case .fileNotFound:
            return "文件不存在"
        case .fileTooLarge:
            return "文件过大，无法显示代码片段"
        }
    }
}

// MARK: - 代码匹配项

/// 单个代码匹配项
struct CodeMatch: Identifiable, Codable {
    let id = UUID()
    let lineNumber: Int            // 行号
    let lineContent: String        // 行内容

    enum CodingKeys: String, CodingKey {
        case lineNumber, lineContent
    }
}

// MARK: - 代码搜索结果

/// 代码搜索结果（单个文件）
struct CodeSearchResult: Identifiable, Codable {
    let id = UUID()
    let filePath: String           // 文件完整路径
    let fileName: String           // 文件名
    let fileExtension: String      // 文件扩展名
    let repo: String               // 仓库名
    let owner: String              // 所有者
    let matches: [CodeMatch]       // 匹配项列表
    let totalMatches: Int          // 总匹配数
    let htmlURL: String            // GitHub网页URL

    enum CodingKeys: String, CodingKey {
        case filePath, fileName, fileExtension, repo, owner, matches, totalMatches, htmlURL
    }

    /// 从GitHub API原始响应转换
    static func fromAPIItem(_ item: CodeSearchItem, owner: String, repo: String) -> CodeSearchResult {
        let fileName = (item.path as NSString).lastPathComponent
        let fileExtension = (fileName as NSString).pathExtension
        return CodeSearchResult(
            filePath: item.path,
            fileName: fileName,
            fileExtension: fileExtension,
            repo: repo,
            owner: owner,
            matches: [],
            totalMatches: 0,
            htmlURL: item.htmlUrl
        )
    }
}

// MARK: - 代码行

/// 代码行模型
struct CodeLine: Identifiable {
    let id = UUID()
    let lineNumber: Int            // 行号
    let content: String            // 行内容
    let isMatch: Bool              // 是否匹配行
}

// MARK: - 代码片段

/// 代码片段（包含多行，匹配行高亮）
struct CodeSnippet: Identifiable {
    let id = UUID()
    let startLine: Int             // 起始行
    let endLine: Int               // 结束行
    let lines: [CodeLine]          // 代码行列表
    let matchLineNumbers: [Int]    // 匹配行号
}

// MARK: - 缓存的搜索结果

/// 缓存的搜索结果（带时间戳）
struct CachedSearchResult {
    let results: [CodeSearchResult]
    let timestamp: Date
    let query: String

    /// 是否过期
    func isExpired(ttl: TimeInterval = 300) -> Bool {
        return Date().timeIntervalSince(timestamp) > ttl
    }
}
