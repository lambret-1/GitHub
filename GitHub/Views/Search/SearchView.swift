import SwiftUI

// MARK: - 全局搜索页面

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedTab: SearchTab = .repositories
    @State private var repos: [Repository] = []
    @State private var users: [GitHubUser] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMoreResults: Bool = true
    @State private var showAdvancedFilter: Bool = false
    @State private var filterConfig: FilterConfiguration = FilterConfiguration()

    enum SearchTab: String, CaseIterable {
        case repositories = "仓库"
        case users = "用户"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏 + 筛选按钮
                HStack(spacing: 8) {
                    SearchBar(text: $searchText, placeholder: "搜索仓库或用户", onSearchButtonClicked: {
                        performSearch()
                    })

                    // 高级筛选按钮
                    Button(action: {
                        showAdvancedFilter = true
                    }) {
                        ZStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(filterConfig.hasActiveFilters ? .blue : .gray)

                            // 激活筛选条件数量角标
                            if filterConfig.hasActiveFilters {
                                Text("●")
                                    .font(.system(size: 8))
                                    .foregroundColor(.blue)
                                    .offset(x: 10, y: -8)
                            }
                        }
                        .frame(width: 32, height: 32)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // 当前激活的筛选条件标签
                if filterConfig.hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text("筛选:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // 显示激活的筛选条件
                            ForEach(activeFilterTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }

                            // 清除所有筛选按钮
                            Button(action: {
                                filterConfig.reset()
                                if !searchText.isEmpty {
                                    performSearch()
                                }
                            }) {
                                Text("清除")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 4)
                }

                // 标签页切换
                Picker("搜索类型", selection: $selectedTab) {
                    ForEach(SearchTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                .padding(.bottom, 8)
                .onChange(of: selectedTab) { _ in
                    // 切换标签页时，如果有搜索文本，重新搜索
                    if !searchText.isEmpty {
                        performSearch()
                    }
                }

                // 搜索结果
                if isLoading {
                    Spacer()
                    ProgressView("搜索中...")
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
                            performSearch()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("输入关键词开始搜索")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        if selectedTab == .repositories {
                            ForEach(repos) { repo in
                                NavigationLink(destination: FileBrowserView(repository: repo)) {
                                    RepoRow(repo: repo)
                                }
                            }
                            if hasMoreResults && !repos.isEmpty {
                                HStack {
                                    Spacer()
                                    Button("加载更多") {
                                        loadMore()
                                    }
                                    .foregroundColor(.blue)
                                    Spacer()
                                }
                            }
                        } else {
                            ForEach(users) { user in
                                UserRow(user: user)
                            }
                            if hasMoreResults && !users.isEmpty {
                                HStack {
                                    Spacer()
                                    Button("加载更多") {
                                        loadMore()
                                    }
                                    .foregroundColor(.blue)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("搜索")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showAdvancedFilter) {
            AdvancedFilterView(
                searchType: $selectedTab,
                filterConfig: $filterConfig
            ) { config in
                filterConfig = config
                if !searchText.isEmpty {
                    performSearch()
                }
            }
        }
    }

    // MARK: - 激活的筛选条件标签

    private var activeFilterTags: [String] {
        var tags: [String] = []

        if selectedTab == .repositories {
            if !filterConfig.language.isEmpty { tags.append("语言:\(filterConfig.language)") }
            if !filterConfig.minStars.isEmpty { tags.append("Star>=\(filterConfig.minStars)") }
            if !filterConfig.maxStars.isEmpty { tags.append("Star<=\(filterConfig.maxStars)") }
            if !filterConfig.minForks.isEmpty { tags.append("Fork>=\(filterConfig.minForks)") }
            if !filterConfig.maxForks.isEmpty { tags.append("Fork<=\(filterConfig.maxForks)") }
            if !filterConfig.license.isEmpty { tags.append("许可证:\(filterConfig.license)") }
            if filterConfig.hasIssues { tags.append("有议题") }
            if filterConfig.hasWiki { tags.append("有Wiki") }
            if filterConfig.hasProjects { tags.append("有项目") }
            if filterConfig.archived { tags.append("已归档") }
            if !filterConfig.repoType.isEmpty { tags.append("类型:\(filterConfig.repoType)") }
            if !filterConfig.topics.isEmpty { tags.append("主题") }
        } else {
            if !filterConfig.userType.isEmpty { tags.append("类型:\(filterConfig.userType)") }
            if !filterConfig.minRepos.isEmpty { tags.append("仓库>=\(filterConfig.minRepos)") }
            if !filterConfig.maxRepos.isEmpty { tags.append("仓库<=\(filterConfig.maxRepos)") }
            if !filterConfig.minFollowers.isEmpty { tags.append("关注者>=\(filterConfig.minFollowers)") }
            if !filterConfig.maxFollowers.isEmpty { tags.append("关注者<=\(filterConfig.maxFollowers)") }
            if !filterConfig.location.isEmpty { tags.append("位置:\(filterConfig.location)") }
            if filterConfig.isHireable { tags.append("可雇佣") }
        }

        return tags
    }

    // MARK: - 搜索方法

    private func performSearch() {
        guard !searchText.isEmpty || filterConfig.hasActiveFilters else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMoreResults = true

        // 使用筛选配置构建查询
        let query = filterConfig.buildQuery(baseQuery: searchText)

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: query, page: currentPage, sort: filterConfig.getSortParameter()) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let repos):
                        self.repos = repos
                        self.hasMoreResults = repos.count >= 30
                    case .failure(let error):
                        self.errorMessage = "搜索失败: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            GitHubAPI.shared.searchUsers(query: query, page: currentPage, sort: filterConfig.getSortParameter()) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let users):
                        self.users = users
                        self.hasMoreResults = users.count >= 30
                    case .failure(let error):
                        self.errorMessage = "搜索失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func loadMore() {
        currentPage += 1
        isLoading = true

        // 使用筛选配置构建查询
        let query = filterConfig.buildQuery(baseQuery: searchText)

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: query, page: currentPage, sort: filterConfig.getSortParameter()) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let repos):
                        self.repos.append(contentsOf: repos)
                        self.hasMoreResults = repos.count >= 30
                    case .failure(let error):
                        self.errorMessage = "加载更多失败: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            GitHubAPI.shared.searchUsers(query: query, page: currentPage, sort: filterConfig.getSortParameter()) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let users):
                        self.users.append(contentsOf: users)
                        self.hasMoreResults = users.count >= 30
                    case .failure(let error):
                        self.errorMessage = "加载更多失败: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}

// MARK: - 用户行视图

struct UserRow: View {
    let user: GitHubUser

    var body: some View {
        HStack(spacing: 12) {
            // 头像
            CachedImageView(urlString: user.avatarUrl)
                .frame(width: 48, height: 48)
                .clipShape(Circle())

            // 用户信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.displayName)
                        .font(.headline)
                    Text("@\(user.login)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let bio = user.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    if let company = user.company, !company.isEmpty {
                        Label(company, systemImage: "building.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let location = user.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Text("\(user.publicRepos) 仓库")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(user.followers) 关注者")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(user.following) 关注")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 在 GitHub 打开按钮
            Button(action: {
                if let url = URL(string: user.htmlUrl) {
                    UIApplication.shared.open(url)
                }
            }) {
                Image(systemName: "safari")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 8)
    }
}
