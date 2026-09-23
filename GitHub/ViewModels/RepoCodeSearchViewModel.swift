import SwiftUI
import Combine

@MainActor
final class RepoCodeSearchViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var state: SearchState = .idle
    @Published var results: [CodeSearchFile] = []
    @Published var selectedFile: CodeSearchFile? = nil
    @Published var snippets: [CodeSnippet] = []
    @Published var snippetLoading: Bool = false

    // 排序选项（默认按更新时间降序）
    @Published var sortOption: CodeSearchSortOption = .updated

    // 搜索历史记录
    @Published var searchHistory: [SearchHistoryItem] = []

    // 搜索建议
    @Published var searchSuggestions: [String] = []

    // 是否显示搜索建议（输入框聚焦且有输入时显示）
    @Published var showSuggestions: Bool = false

    private let owner: String
    private let repo: String
    private let branch: String
    private var searchTask: Task<Void, Never>?
    private var snippetTask: Task<Void, Never>?

    init(owner: String, repo: String, branch: String) {
        self.owner = owner
        self.repo = repo
        self.branch = branch
        loadSearchHistory()
    }

    // 加载搜索历史记录
    func loadSearchHistory() {
        searchHistory = CodeSearchService.shared.getSearchHistory()
    }

    // 更新搜索建议
    func updateSuggestions() {
        searchSuggestions = CodeSearchService.shared.getSearchSuggestions(for: query)
    }

    // 选择搜索建议
    func selectSuggestion(_ suggestion: String) {
        query = suggestion
        showSuggestions = false
        search()
    }

    // 选择搜索历史
    func selectHistory(_ item: SearchHistoryItem) {
        query = item.query
        showSuggestions = false
        search()
    }

    // 删除单条搜索历史
    func removeHistory(_ item: SearchHistoryItem) {
        CodeSearchService.shared.removeSearchHistory(item)
        loadSearchHistory()
    }

    // 清除所有搜索历史
    func clearAllHistory() {
        CodeSearchService.shared.clearSearchHistory()
        loadSearchHistory()
    }

    // 切换排序选项并重新排序
    func changeSortOption(_ option: CodeSearchSortOption) {
        sortOption = option
        if !results.isEmpty {
            results = CodeSearchService.shared.sortSearchResults(results, sortOption: option)
        }
    }

    // 刷新搜索（清除缓存并重新搜索）
    func refresh() {
        // 清除所有文件内容缓存
        CodeSearchService.shared.clearAllFileContentCache()
        // 重新搜索
        search()
    }

    func search() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .idle
            results = []
            return
        }
        state = .searching
        showSuggestions = false
        searchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                // 注意：View层已有300ms输入防抖，这里不再额外延迟，避免搜索响应过慢
                let items = try await CodeSearchService.shared.searchCode(
                    owner: self.owner,
                    repo: self.repo,
                    query: trimmed,
                    branch: self.branch,
                    sortOption: self.sortOption
                )
                if Task.isCancelled { return }
                await MainActor.run {
                    self.results = items
                    self.state = items.isEmpty ? .empty : .success
                    // 重新加载搜索历史（因为搜索成功后会添加新记录）
                    self.loadSearchHistory()
                }

                // 异步加载文件最后编辑时间（不阻塞UI显示）
                if !items.isEmpty {
                    Task { [weak self] in
                        guard let self = self else { return }
                        let updatedFiles = await CodeSearchService.shared.loadLastModifiedForFiles(
                            items,
                            owner: self.owner,
                            repo: self.repo,
                            branch: self.branch
                        )
                        if Task.isCancelled { return }
                        await MainActor.run {
                            self.results = updatedFiles
                        }
                    }
                }
            } catch is CancellationError {
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.state = .error(error.localizedDescription)
                }
            }
        }
    }

    func loadSnippets(for file: CodeSearchFile) {
        snippetTask?.cancel()
        selectedFile = file
        snippets = []
        snippetLoading = true
        snippetTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                let content = try await CodeSearchService.shared.getFileContent(
                    owner: self.owner,
                    repo: self.repo,
                    path: file.path,
                    branch: self.branch
                )
                if Task.isCancelled { return }
                let extracted = CodeSearchService.shared.extractSnippets(
                    content: content,
                    query: self.query,
                    contextLines: 2
                )
                if Task.isCancelled { return }
                await MainActor.run {
                    self.snippets = extracted
                    self.snippetLoading = false
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    self.snippetLoading = false
                }
            }
        }
    }

    func cancel() {
        searchTask?.cancel()
        snippetTask?.cancel()
    }

    func clear() {
        query = ""
        state = .idle
        results = []
        selectedFile = nil
        snippets = []
        showSuggestions = false
    }
}
