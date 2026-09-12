import SwiftUI

// MARK: - 星标仓库列表页面
struct StarredReposView: View {
    @EnvironmentObject var appState: AppState
    @State private var repos: [Repository] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMorePages: Bool = true
    @State private var isLoadingMore: Bool = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 页面标题栏
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 18))
                    Text("我的星标")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("\(repos.count) 个仓库")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))

                // 仓库列表
                if isLoading {
                    Spacer()
                    ProgressView("加载星标仓库中...")
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            loadStarredRepos()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if repos.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "star.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("还没有星标任何仓库")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        Text("在仓库页面点击星标按钮即可收藏")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(repos) { repo in
                            NavigationLink(destination: FileBrowserView(repository: repo)) {
                                RepoRow(repo: repo)
                            }
                            // 重按菜单
                            .contextMenu {
                                Button(action: {
                                    // 取消星标
                                    unstarRepository(repo)
                                }) {
                                    Label("取消星标", systemImage: "star.slash")
                                }
                            }
                        }

                        // 加载更多
                        if hasMorePages && !isLoadingMore {
                            Button(action: {
                                loadMoreRepos()
                            }) {
                                HStack {
                                    Spacer()
                                    Text("加载更多")
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 12)
                                    Spacer()
                                }
                            }
                        } else if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.vertical, 12)
                                Spacer()
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await refreshStarredRepos()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if repos.isEmpty {
                    loadStarredRepos()
                }
            }
        }
    }

    // MARK: - 加载星标仓库列表
    private func loadStarredRepos() {
        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMorePages = true

        GitHubAPI.shared.getStarredRepositories(page: 1, perPage: 30) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let repos):
                    self.repos = repos
                    hasMorePages = repos.count >= 30
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - 下拉刷新
    private func refreshStarredRepos() async {
        currentPage = 1
        hasMorePages = true

        return await withCheckedContinuation { continuation in
            GitHubAPI.shared.getStarredRepositories(page: 1, perPage: 30) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let repos):
                        self.repos = repos
                        hasMorePages = repos.count >= 30
                    case .failure:
                        break
                    }
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - 加载更多
    private func loadMoreRepos() {
        guard !isLoadingMore && hasMorePages else { return }
        isLoadingMore = true
        let nextPage = currentPage + 1

        GitHubAPI.shared.getStarredRepositories(page: nextPage, perPage: 30) { result in
            DispatchQueue.main.async {
                isLoadingMore = false
                switch result {
                case .success(let newRepos):
                    self.repos.append(contentsOf: newRepos)
                    self.currentPage = nextPage
                    hasMorePages = newRepos.count >= 30
                case .failure:
                    hasMorePages = false
                }
            }
        }
    }

    // MARK: - 取消星标
    private func unstarRepository(_ repo: Repository) {
        GitHubAPI.shared.unstarRepository(owner: repo.ownerName, repo: repo.name) { result in
            DispatchQueue.main.async {
                if case .success = result {
                    // 从列表中移除
                    repos.removeAll { $0.id == repo.id }
                }
            }
        }
    }
}
