import SwiftUI

// MARK: - 用户仓库主页视图（点击仓库所有者头像进入，显示该用户的所有仓库）

struct UserReposView: View {
    let username: String
    let avatarUrl: String

    @EnvironmentObject var appState: AppState
    @State private var repositories: [Repository] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMore = true
    @State private var isLoadingMore = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // 用户信息头部
                userHeaderSection

                // 仓库列表
                if isLoading {
                    loadingView
                } else if let error = errorMessage {
                    errorView(error: error)
                } else if repositories.isEmpty {
                    emptyView
                } else {
                    reposListView
                }
            }
        }
        .navigationTitle(username)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if repositories.isEmpty {
                loadRepositories()
            }
        }
    }

    // MARK: - 用户信息头部

    private var userHeaderSection: some View {
        VStack(spacing: 12) {
            // 用户头像
            AsyncImage(url: URL(string: avatarUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))

            // 用户名
            Text(username)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            // 仓库数量
            Text("\(repositories.count) 个仓库")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(appState.isDarkMode ? Color.white.opacity(0.03) : Color(.systemGray6))
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView("加载中...")
                .padding(.vertical, 40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 错误视图

    private func errorView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                currentPage = 1
                hasMore = true
                repositories = []
                errorMessage = nil
                loadRepositories()
            }
            .foregroundColor(.blue)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 空视图

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("暂无仓库")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - 仓库列表视图

    private var reposListView: some View {
        LazyVStack(spacing: 0) {
            ForEach(repositories) { repo in
                NavigationLink(destination: FileBrowserView(repository: repo)) {
                    repoRow(repo)
                }
                .buttonStyle(PlainButtonStyle())
                .onAppear {
                    if repo.id == repositories.last?.id && hasMore && !isLoadingMore {
                        loadMoreRepositories()
                    }
                }
            }

            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 16)
            }
        }
    }

    // MARK: - 仓库行视图

    private func repoRow(_ repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 仓库名称
            HStack {
                Image(systemName: repo.isPrivate ? "lock.fill" : "folder")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                Text(repo.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                Spacer()
            }

            // 仓库描述
            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // 仓库元信息
            HStack(spacing: 16) {
                if let language = repo.language, !language.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForLanguage(language))
                            .frame(width: 12, height: 12)
                        Text(language)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    Text("\(repo.stargazersCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(repo.forksCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 更新时间
                Text(repo.formattedUpdateTime)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(appState.isDarkMode ? Color.white.opacity(0.02) : Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    // MARK: - 语言颜色映射

    private func colorForLanguage(_ language: String) -> Color {
        let colors: [String: Color] = [
            "Swift": .orange,
            "Python": .blue,
            "JavaScript": .yellow,
            "TypeScript": .blue,
            "Java": .red,
            "Kotlin": .purple,
            "Go": .cyan,
            "Rust": .orange,
            "C++": .pink,
            "C": .gray,
            "Objective-C": .blue,
            "Shell": .green,
            "Ruby": .red,
            "PHP": .purple,
            "HTML": .orange,
            "CSS": .blue,
            "Vue": .green,
            "React": .cyan
        ]
        return colors[language] ?? .gray
    }

    // MARK: - 数据加载

    private func loadRepositories() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getUserReposByUser(username: username, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let repos):
                    self.repositories = repos
                    self.hasMore = repos.count >= 100
                case .failure(let error):
                    self.errorMessage = "加载仓库失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadMoreRepositories() {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        currentPage += 1

        GitHubAPI.shared.getUserReposByUser(username: username, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingMore = false
                switch result {
                case .success(let repos):
                    self.repositories.append(contentsOf: repos)
                    self.hasMore = repos.count >= 100
                case .failure:
                    self.currentPage -= 1
                }
            }
        }
    }
}

// MARK: - 预览

struct UserReposView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            UserReposView(username: "octocat", avatarUrl: "https://avatars.githubusercontent.com/u/583231?v=4")
        }
    }
}
