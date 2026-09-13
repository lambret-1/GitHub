import SwiftUI

// MARK: - 星标仓库列表页面（全新重构，对齐GitHub官方样式）
struct StarredReposView: View {
    @EnvironmentObject var appState: AppState

    // 仓库列表状态
    @State private var repos: [Repository] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMorePages: Bool = true
    @State private var isLoadingMore: Bool = false

    // 搜索状态
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // 筛选状态
    enum FilterType: String, CaseIterable {
        case all = "全部"
        case own = "自己的"
        case others = "别人的"
    }
    @State private var selectedFilter: FilterType = .all

    // 排序状态
    enum SortType: String, CaseIterable {
        case starredTime = "星标时间"
        case repoName = "仓库名"
        case updateTime = "更新时间"
        case stars = "Star数"
    }
    @State private var selectedSort: SortType = .starredTime
    @State private var showSortMenu: Bool = false

    // 操作提示
    @State private var operationMessage: String = ""
    @State private var showOperationMessage: Bool = false

    // 当前登录用户名（用于筛选自己的仓库）
    private var currentUsername: String {
        return appState.currentUser?.login ?? ""
    }

    // 过滤后的仓库列表
    private var filteredRepos: [Repository] {
        var result = repos

        // 按筛选类型过滤
        switch selectedFilter {
        case .own:
            result = result.filter { $0.ownerName == currentUsername }
        case .others:
            result = result.filter { $0.ownerName != currentUsername }
        case .all:
            break
        }

        // 按搜索文本过滤
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            result = result.filter { repo in
                repo.name.lowercased().contains(query) ||
                (repo.description ?? "").lowercased().contains(query) ||
                repo.ownerName.lowercased().contains(query)
            }
        }

        // 按排序类型排序
        switch selectedSort {
        case .repoName:
            result.sort { $0.name.lowercased() < $1.name.lowercased() }
        case .updateTime:
            result.sort { ($0.updatedAt ?? "") > ($1.updatedAt ?? "") }
        case .stars:
            result.sort { ($0.stargazersCount ?? 0) > ($1.stargazersCount ?? 0) }
        case .starredTime:
            // GitHub API返回的星标列表默认按星标时间排序
            break
        }

        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            // 筛选标签栏
            filterBar

            // 仓库列表
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error: error)
            } else if filteredRepos.isEmpty {
                emptyView
            } else {
                repoListView
            }
        }
        .background(appState.isDarkMode ? Color.black : Color(.systemBackground))
        .navigationTitle("我的星标")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(SortType.allCases, id: \.self) { sortType in
                        Button(action: {
                            selectedSort = sortType
                        }) {
                            if selectedSort == sortType {
                                Label(sortType.rawValue, systemImage: "checkmark")
                            } else {
                                Text(sortType.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            if repos.isEmpty {
                loadStarredRepos()
            }
        }
        .refreshable {
            await refreshStarredRepos()
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

    // MARK: - 搜索框
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 16))

            TextField("搜索星标仓库...", text: $searchText)
                .font(.system(size: 15))
                .foregroundColor(appState.isDarkMode ? .white : .primary)
                .autocapitalization(.none)
                .disableAutocorrection(true)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - 筛选标签栏
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases, id: \.self) { filterType in
                    Button(action: {
                        selectedFilter = filterType
                    }) {
                        Text(filterType.rawValue)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(
                                selectedFilter == filterType ?
                                Color.blue :
                                (appState.isDarkMode ? Color.white.opacity(0.1) : Color(.systemGray5))
                            )
                            .foregroundColor(
                                selectedFilter == filterType ? .white : .secondary
                            )
                            .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Spacer()

                // 仓库数量
                Text("\(filteredRepos.count) 个仓库")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 8)
    }

    // MARK: - 加载中视图
    private var loadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("加载星标仓库中...")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 错误视图
    private func errorView(error: String) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button(action: {
                    loadStarredRepos()
                }) {
                    Text("重试")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 空状态视图
    private var emptyView: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "star.slash")
                    .font(.system(size: 56))
                    .foregroundColor(.gray)
                Text(searchText.isEmpty ? "还没有星标任何仓库" : "没有找到匹配的仓库")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                if searchText.isEmpty {
                    Text("在仓库页面点击星标按钮即可收藏")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                } else {
                    Text("试试其他关键词")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 仓库列表视图
    private var repoListView: some View {
        List {
            ForEach(filteredRepos) { repo in
                NavigationLink(destination: FileBrowserView(repository: repo)) {
                    StarredRepoCard(repo: repo)
                }
                .listRowBackground(appState.isDarkMode ? Color.black : Color.white)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                // 左滑取消星标
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        unstarRepository(repo)
                    } label: {
                        Label("取消星标", systemImage: "star.slash")
                    }
                }
                // 重按菜单
                .contextMenu {
                    Button(action: {
                        unstarRepository(repo)
                    }) {
                        Label("取消星标", systemImage: "star.slash")
                    }

                    Button(action: {
                        if let url = URL(string: repo.htmlUrl) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Label("在 GitHub 打开", systemImage: "safari")
                    }

                    Button(action: {
                        UIPasteboard.general.string = repo.htmlUrl
                        operationMessage = "已复制仓库地址"
                        showOperationMessage = true
                    }) {
                        Label("复制仓库地址", systemImage: "link")
                    }
                }
                // 滚动到底部自动加载更多
                .onAppear {
                    if repo.id == filteredRepos.last?.id && hasMorePages && !isLoadingMore && searchText.isEmpty {
                        loadMoreRepos()
                    }
                }
            }

            // 加载更多指示器
            if isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView("加载更多...")
                        .padding(.vertical, 16)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(PlainListStyle())
        .background(appState.isDarkMode ? Color.black : Color(.systemBackground))
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
                    // 去重
                    let existingIds = Set(self.repos.map { $0.id })
                    let uniqueNewRepos = newRepos.filter { !existingIds.contains($0.id) }
                    self.repos.append(contentsOf: uniqueNewRepos)
                    self.currentPage = nextPage
                    hasMorePages = uniqueNewRepos.count >= 30
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
                switch result {
                case .success:
                    // 从列表中移除
                    repos.removeAll { $0.id == repo.id }
                    operationMessage = "已取消星标"
                    showOperationMessage = true
                case .failure(let error):
                    operationMessage = "取消星标失败: \(error.localizedDescription)"
                    showOperationMessage = true
                }
            }
        }
    }
}

// MARK: - 星标仓库卡片（全新重构，对齐GitHub官方样式）
struct StarredRepoCard: View {
    let repo: Repository
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 第一行：仓库图标 + 所有者/仓库名 + 星标图标
            HStack(spacing: 8) {
                // 仓库图标
                Image(systemName: repo.isPrivate ? "lock.fill" : "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(repo.isPrivate ? .orange : .blue)

                // 所有者/仓库名
                Text("\(repo.ownerName)/\(repo.name)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.blue)
                    .lineLimit(1)

                Spacer()

                // 星标图标
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.yellow)
            }

            // 第二行：仓库描述
            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(appState.isDarkMode ? .white.opacity(0.8) : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 第三行：语言 + Star数 + Fork数 + 更新时间
            HStack(spacing: 16) {
                // 语言
                if let language = repo.language, !language.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: repo.languageColor))
                            .frame(width: 12, height: 12)
                        Text(language)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                // Star数
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("\(repo.stargazersCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                // Fork数
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
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(appState.isDarkMode ? Color.white.opacity(0.05) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(appState.isDarkMode ? Color.white.opacity(0.1) : Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

// MARK: - Color 扩展（如果已有则忽略）
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
