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

    private let owner: String
    private let repo: String
    private let branch: String
    private var searchTask: Task<Void, Never>?
    private var snippetTask: Task<Void, Never>?

    init(owner: String, repo: String, branch: String) {
        self.owner = owner
        self.repo = repo
        self.branch = branch
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
        searchTask = Task { [weak self] in
            guard let self = self else { return }
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
                let items = try await CodeSearchService.shared.searchCode(
                    owner: self.owner,
                    repo: self.repo,
                    query: trimmed,
                    branch: self.branch
                )
                if Task.isCancelled { return }
                await MainActor.run {
                    self.results = items
                    self.state = items.isEmpty ? .empty : .success
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
    }
}
