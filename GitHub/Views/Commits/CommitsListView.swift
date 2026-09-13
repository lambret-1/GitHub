import SwiftUI

// MARK: - 提交列表视图（全新重构，对齐GitHub官方样式）
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

    // 操作提示
    @State private var operationMessage: String = ""
    @State private var showOperationMessage: Bool = false

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
                        .listRowSeparator(.hidden)
                }

                if isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView("加载更多...")
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 16)
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
        .overlay {
            if showOperationMessage {
                VStack {
                    Spacer()
                    Text(operationMessage)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(8)
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            showOperationMessage = false
                        }
                    }
                }
            }
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

        // 使用最后一个提交的sha作为分页参数
        guard let lastSha = commits.last?.sha else {
            isLoadingMore = false
            return
        }

        GitHubAPI.shared.getCommits(owner: owner, repo: repo, branch: lastSha, perPage: 30) { result in
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

// MARK: - 提交行视图（全新重构，对齐GitHub官方样式）
struct CommitRow: View {
    let commit: Commit
    @EnvironmentObject var appState: AppState

    // 操作提示
    @State private var showCopyMessage: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 提交图标
            Image(systemName: "commit")
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 6) {
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
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                    Text(commit.authorName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("提交于")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(commit.formattedDate)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Spacer()

                    // 短哈希（可点击复制）
                    Button(action: {
                        UIPasteboard.general.string = commit.shortSha
                        showCopyMessage = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopyMessage = false
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showCopyMessage ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(commit.shortSha)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .background(
            appState.isDarkMode ? Color.black : Color.white
        )
        .overlay(
            Rectangle()
                .fill(appState.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                .frame(height: 1)
                .padding(.leading, 40),
            alignment: .bottom
        )
    }
}
