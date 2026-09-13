import SwiftUI

// MARK: - 提交列表视图
struct CommitsListView: View {
    let owner: String
    let repo: String
    let branch: String?
    @EnvironmentObject var appState: AppState

    // 提交列表状态
    @State private var commits: [Commit] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var isLoadingMore: Bool = false

    // 选中的提交（用于跳转详情）
    @State private var selectedCommit: Commit?

    var body: some View {
        List {
            if isLoading && commits.isEmpty {
                loadingRow
            } else if let error = errorMessage, commits.isEmpty {
                errorRow(error: error)
            } else if commits.isEmpty {
                emptyRow
            } else {
                ForEach(commits) { commit in
                    CommitRow(commit: commit)
                        .onTapGesture {
                            selectedCommit = commit
                        }
                        .onAppear {
                            // 滚动到底部时加载更多
                            if commit.id == commits.last?.id && hasMore && !isLoadingMore {
                                loadMoreCommits()
                            }
                        }
                        .listRowBackground(appState.isDarkMode ? Color.black : Color.white)
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.plain)
        .background(appState.isDarkMode ? Color.black : Color(.systemBackground))
        .navigationTitle("提交记录")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if commits.isEmpty {
                loadCommits()
            }
        }
        .refreshable {
            currentPage = 1
            hasMore = true
            loadCommits()
        }
        .sheet(item: $selectedCommit) { commit in
            CommitDetailView(owner: owner, repo: repo, commit: commit)
        }
    }

    // MARK: - 加载中
    private var loadingRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("加载中...")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .listRowBackground(Color.clear)
        .padding(.vertical, 40)
    }

    // MARK: - 错误
    private func errorRow(error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(error)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                currentPage = 1
                hasMore = true
                loadCommits()
            }
            .buttonStyle(.borderedProminent)
        }
        .listRowBackground(Color.clear)
        .padding(.vertical, 40)
    }

    // MARK: - 空状态
    private var emptyRow: some View {
        VStack(spacing: 12) {
            Image(systemName: "dot.circle")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("暂无提交记录")
                .foregroundColor(.secondary)
        }
        .listRowBackground(Color.clear)
        .padding(.vertical, 40)
    }

    // MARK: - 加载提交列表
    private func loadCommits() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getCommits(owner: owner, repo: repo, branch: branch, perPage: 30) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let newCommits):
                    commits = newCommits
                    hasMore = newCommits.count >= 30
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 加载更多提交
    private func loadMoreCommits() {
        isLoadingMore = true
        currentPage += 1

        // GitHub API的commits接口不直接支持分页参数，但可以通过per_page和sha来实现
        // 这里简化处理，直接重新加载第一页（实际项目中应该使用last commit的sha作为参数）
        GitHubAPI.shared.getCommits(owner: owner, repo: repo, branch: branch, perPage: 30) { result in
            DispatchQueue.main.async {
                isLoadingMore = false
                switch result {
                case .success(let newCommits):
                    // 去重：只添加不在现有列表中的提交
                    let existingIds = Set(commits.map { $0.id })
                    let uniqueNewCommits = newCommits.filter { !existingIds.contains($0.id) }
                    commits.append(contentsOf: uniqueNewCommits)
                    hasMore = uniqueNewCommits.count >= 30
                case .failure:
                    currentPage -= 1
                }
            }
        }
    }
}

// MARK: - 提交行视图
struct CommitRow: View {
    let commit: Commit
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 提交图标
            Image(systemName: "commit")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                // 提交信息
                Text(commit.message)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .lineLimit(2)

                // 作者和时间
                HStack(spacing: 8) {
                    // 作者头像
                    AsyncImage(url: URL(string: commit.author?.avatarUrl ?? "")) { image in
                        image.resizable()
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())

                    Text(commit.authorName)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(commit.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    // 短哈希
                    Text(commit.shortSha)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
