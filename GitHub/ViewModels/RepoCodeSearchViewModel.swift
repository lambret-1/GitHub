import Foundation
import SwiftUI

// MARK: - 仓库代码搜索ViewModel

/// 仓库代码搜索ViewModel，管理搜索状态、防抖、竞态防护、任务取消
@MainActor
final class RepoCodeSearchViewModel: ObservableObject {
    // 输入参数
    let owner: String
    let repo: String
    let branch: String

    // 输出状态
    @Published var query: String = ""
    @Published var state: SearchState = .idle
    @Published var results: [CodeSearchResult] = []
    @Published var selectedResult: CodeSearchResult?
    @Published var snippets: [CodeSnippet] = []
    @Published var snippetLoading: Bool = false
    @Published var snippetError: String?

    // 内部状态
    private var searchTask: Task<Void, Never>?
    private var snippetTask: Task<Void, Never>?
    private let service: CodeSearchService

    // 防抖延迟（纳秒）
    private let debounceDelay: UInt64 = 300_000_000  // 300ms

    // 初始化
    init(
        owner: String,
        repo: String,
        branch: String,
        service: CodeSearchService = .shared
    ) {
        self.owner = owner
        self.repo = repo
        self.branch = branch
        self.service = service
    }

    // MARK: - 搜索方法

    /// 执行搜索（带防抖）
    /// - Parameter query: 搜索关键词
    func search(with query: String) {
        // 取消之前的搜索任务
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // 空查询处理
        guard !trimmed.isEmpty else {
            state = .idle
            results = []
            return
        }

        // 设置搜索中状态
        state = .searching

        // 防抖搜索
        searchTask = Task {
            // 等待防抖延迟
            try? await Task.sleep(nanoseconds: debounceDelay)

            // 检查任务是否被取消
            guard !Task.isCancelled else { return }

            // 再次检查查询是否为空（可能在等待期间被清空）
            let currentTrimmed = self.query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !currentTrimmed.isEmpty else {
                await MainActor.run {
                    self.state = .idle
                    self.results = []
                }
                return
            }

            do {
                // 执行搜索
                let results = try await service.search(
                    owner: owner,
                    repo: repo,
                    query: currentTrimmed,
                    branch: branch
                )

                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                // 更新UI
                await MainActor.run {
                    self.results = results
                    self.state = results.isEmpty ? .empty : .success
                }
            } catch let error as CodeSearchError {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                // 取消错误不显示
                if case .cancelled = error {
                    return
                }

                await MainActor.run {
                    self.state = .error(error.localizedDescription ?? "搜索失败")
                }
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.state = .error("搜索失败：\(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - 加载代码片段

    /// 加载指定搜索结果的代码片段
    /// - Parameter result: 搜索结果
    func loadSnippets(for result: CodeSearchResult) {
        // 取消之前的片段加载任务
        snippetTask?.cancel()

        snippetLoading = true
        snippetError = nil
        snippets = []

        snippetTask = Task {
            do {
                // 获取文件内容
                let content = try await service.getFileContent(
                    owner: owner,
                    repo: repo,
                    path: result.filePath,
                    branch: branch
                )

                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                // 在后台线程提取片段（显式使用self，避免闭包捕获语义错误）
                let extractedSnippets = Task.detached(priority: .userInitiated) { [service] in
                    return service.extractSnippets(
                        content: content,
                        query: query,
                        contextLines: 2
                    )
                }
                let snippetsResult = try await extractedSnippets.value

                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                // 更新UI
                await MainActor.run {
                    self.snippets = snippetsResult
                    self.snippetLoading = false
                }
            } catch let error as CodeSearchError {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.snippetLoading = false
                    self.snippetError = error.localizedDescription
                }
            } catch {
                // 检查任务是否被取消
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    self.snippetLoading = false
                    self.snippetError = "加载失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 选择搜索结果

    /// 选择搜索结果（打开代码片段弹窗）
    /// - Parameter result: 搜索结果
    func selectResult(_ result: CodeSearchResult) {
        selectedResult = result
        loadSnippets(for: result)
    }

    // MARK: - 取消方法

    /// 取消所有进行中的任务
    func cancel() {
        searchTask?.cancel()
        snippetTask?.cancel()
        searchTask = nil
        snippetTask = nil
    }

    // MARK: - 重置方法

    /// 重置所有状态
    func reset() {
        cancel()
        query = ""
        state = .idle
        results = []
        selectedResult = nil
        snippets = []
        snippetLoading = false
        snippetError = nil
    }

    // MARK: - 重试方法

    /// 重试搜索
    func retry() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .idle
            return
        }
        search(with: query)
    }

    // MARK: - 清空搜索

    /// 清空搜索
    func clearSearch() {
        query = ""
        searchTask?.cancel()
        state = .idle
        results = []
    }
}
