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
                    .font(.system(size: 60))  // 这是字体大小尺寸，控制占位图标显示的字号大小，单位是pt；改大图标更大更醒目，改小图标更小更精致；还能配合.weight设粗体/设字重
                    .foregroundColor(.gray)
            }
            .frame(width: 80, height: 80)  // 这是视图宽高尺寸，控制用户头像显示的宽度和高度，单位是pt（点）；改大头像显示更大更醒目，改小头像显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))  // 这是边框线宽尺寸，控制头像边框的粗细程度，单位是pt；改大边框更粗更明显，改小边框更细更细腻；还能改成.stroke的lineWidth参数调整

            // 用户名
            Text(username)
                .font(.system(size: 20, weight: .bold))  // 这是字体大小尺寸，控制用户名显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.primary)

            // 仓库数量
            Text("\(repositories.count) 个仓库")
                .font(.system(size: 14))  // 这是字体大小尺寸，控制仓库数量文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 24)  // 这是垂直内边距，控制用户信息头部上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
        .frame(maxWidth: .infinity)
        .background(appState.isDarkMode ? Color.white.opacity(0.03) : Color(.systemGray6))
    }

    // MARK: - 加载视图

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView("加载中...")
                .padding(.vertical, 40)  // 这是垂直内边距，控制加载指示器上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
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
        .padding(.vertical, 40)  // 这是垂直内边距，控制错误视图上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
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
        .padding(.vertical, 40)  // 这是垂直内边距，控制空视图上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
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
                .padding(.vertical, 16)  // 这是垂直内边距，控制加载更多指示器上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
            }
        }
    }

    // MARK: - 仓库行视图

    private func repoRow(_ repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 仓库名称
            HStack {
                Image(systemName: repo.isPrivate ? "lock.fill" : "folder")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制仓库图标显示的字号大小，单位是pt；改大图标更大更醒目，改小图标更小更精致；还能配合.weight设粗体/设字重
                    .foregroundColor(.blue)
                Text(repo.name)
                    .font(.system(size: 16, weight: .semibold))  // 这是字体大小尺寸，控制仓库名称显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)
                Spacer()
            }

            // 仓库描述
            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制仓库描述显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            // 仓库元信息
            HStack(spacing: 16) {
                if let language = repo.language, !language.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorForLanguage(language))
                            .frame(width: 12, height: 12)  // 这是视图宽高尺寸，控制语言颜色圆点显示的宽度和高度，单位是pt（点）；改大圆点更大更醒目，改小圆点更小更精致；还能改成.maxWidth/.infinity自适应
                        Text(language)
                            .font(.system(size: 12))  // 这是字体大小尺寸，控制语言名称显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制星标图标显示的字号大小，单位是pt；改大图标更大更醒目，改小图标更小更精致；还能配合.weight设粗体/设字重
                        .foregroundColor(.yellow)
                    Text("\(repo.stargazersCount ?? 0)")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制星标数量显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "tuningfork")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制Fork图标显示的字号大小，单位是pt；改大图标更大更醒目，改小图标更小更精致；还能配合.weight设粗体/设字重
                        .foregroundColor(.secondary)
                    Text("\(repo.forksCount ?? 0)")
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制Fork数量显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 更新时间
                Text(repo.formattedUpdateTime)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制更新时间显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制仓库行内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 12)  // 这是垂直内边距，控制仓库行内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(appState.isDarkMode ? Color.white.opacity(0.02) : Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 1),  // 这是视图高度尺寸，控制分隔线显示的高度，单位是pt；改大分隔线更粗更明显，改小分隔线更细更细腻；还能改成.frame(height:)参数调整
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
