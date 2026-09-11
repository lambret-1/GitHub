import SwiftUI

// MARK: - 全局搜索页面

struct SearchView: View {
    @EnvironmentObject var appState: AppState
    @State private var searchText: String = ""
    @State private var selectedTab: SearchTab = .repositories
    @State private var repos: [Repository] = []
    @State private var users: [GitHubUser] = []
    @State private var codeResults: [CodeSearchItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMoreResults: Bool = true
    @State private var showAdvancedFilter: Bool = false
    @State private var repoFilter: RepoFilterState = RepoFilterState()
    @State private var userFilter: UserFilterState = UserFilterState()

    enum SearchTab: String, CaseIterable {
        case repositories = "仓库"
        case users = "用户"
        case code = "代码"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏 + 筛选按钮
                HStack(spacing: 8) {
                    SearchBar(text: $searchText, placeholder: "搜索仓库、用户或代码", onSearchButtonClicked: {
                        performSearch()
                    })

                    // 高级筛选按钮
                    Button(action: {
                        showAdvancedFilter = true
                    }) {
                        ZStack {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18))
                                .foregroundColor(hasActiveFilters ? .blue : .gray)

                            // 激活筛选条件数量角标
                            if hasActiveFilters {
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
                if hasActiveFilters {
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
                                resetFilters()
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
                        } else if selectedTab == .users {
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
                        } else {
                            // 代码搜索结果
                            ForEach(codeResults) { item in
                                NavigationLink(destination: CodeEditorView(
                                    owner: item.repository.ownerName,
                                    repo: item.repository.name,
                                    path: item.path,
                                    branch: "main",
                                    fileName: item.name
                                )) {
                                    CodeSearchRow(item: item)
                                }
                            }
                            if hasMoreResults && !codeResults.isEmpty {
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
                repoFilter: $repoFilter,
                userFilter: $userFilter,
                selectedTab: selectedTab,
                onApply: {
                    if !searchText.isEmpty {
                        performSearch()
                    }
                },
                onReset: {
                    resetFilters()
                }
            )
        }
    }

    // MARK: - 辅助属性和方法

    private var hasActiveFilters: Bool {
        return selectedTab == .repositories ? repoFilter.hasFilters : userFilter.hasFilters
    }

    private func resetFilters() {
        if selectedTab == .repositories {
            repoFilter.reset()
        } else {
            userFilter.reset()
        }
    }

    // MARK: - 激活的筛选条件标签

    private var activeFilterTags: [String] {
        var tags: [String] = []

        if selectedTab == .repositories {
            if !repoFilter.searchInName || !repoFilter.searchInDescription || repoFilter.searchInReadme {
                var scopes: [String] = []
                if repoFilter.searchInName { scopes.append("名称") }
                if repoFilter.searchInDescription { scopes.append("描述") }
                if repoFilter.searchInReadme { scopes.append("README") }
                tags.append("范围:\(scopes.joined(separator: "+"))")
            }
            if repoFilter.isPublic { tags.append("公开") }
            if repoFilter.isPrivate { tags.append("私有") }
            if let archived = repoFilter.isArchived { tags.append(archived ? "已归档" : "未归档") }
            if let template = repoFilter.isTemplate { tags.append(template ? "模板" : "非模板") }
            if let language = repoFilter.language { tags.append("语言:\(language)") }
            if let topic = repoFilter.topic { tags.append("主题:\(topic)") }
            if let license = repoFilter.license { tags.append("许可证:\(license.uppercased())") }
            if let user = repoFilter.user { tags.append("用户:\(user)") }
            if let org = repoFilter.org { tags.append("组织:\(org)") }
            if let minStars = repoFilter.minStars { tags.append("Star>=\(minStars)") }
            if let minForks = repoFilter.minForks { tags.append("Fork>=\(minForks)") }
            if let minSizeKB = repoFilter.minSizeKB { tags.append("大小>=\(minSizeKB)KB") }
            if repoFilter.createdAfter != nil { tags.append("创建时间") }
            if repoFilter.pushedAfter != nil { tags.append("推送时间") }
        } else {
            if !userFilter.searchInLogin || !userFilter.searchInFullName || userFilter.searchInEmail {
                var scopes: [String] = []
                if userFilter.searchInLogin { scopes.append("用户名") }
                if userFilter.searchInFullName { scopes.append("全名") }
                if userFilter.searchInEmail { scopes.append("邮箱") }
                tags.append("范围:\(scopes.joined(separator: "+"))")
            }
            if let userType = userFilter.userType { tags.append("类型:\(userType.rawValue)") }
            if let location = userFilter.location { tags.append("位置:\(location)") }
            if let language = userFilter.language { tags.append("语言:\(language)") }
            if let minRepos = userFilter.minRepos { tags.append("仓库>=\(minRepos)") }
            if let minFollowers = userFilter.minFollowers { tags.append("关注者>=\(minFollowers)") }
            if let minFollowing = userFilter.minFollowing { tags.append("关注>=\(minFollowing)") }
            if userFilter.createdAfter != nil { tags.append("注册时间") }
        }

        return tags
    }

    // MARK: - 搜索方法

    private func performSearch() {
        guard !searchText.isEmpty || hasActiveFilters else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMoreResults = true

        // 使用筛选配置构建查询
        let query: String
        if selectedTab == .repositories {
            query = repoFilter.buildQuery(baseQuery: searchText)
        } else if selectedTab == .users {
            query = userFilter.buildQuery(baseQuery: searchText)
        } else {
            query = searchText
        }

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: query, page: currentPage) { result in
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
        } else if selectedTab == .users {
            GitHubAPI.shared.searchUsers(query: query, page: currentPage) { result in
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
        } else {
            // 代码搜索
            GitHubAPI.shared.searchCode(query: query, page: currentPage) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let codeResults):
                        self.codeResults = codeResults
                        self.hasMoreResults = codeResults.count >= 30
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
        let query: String
        if selectedTab == .repositories {
            query = repoFilter.buildQuery(baseQuery: searchText)
        } else if selectedTab == .users {
            query = userFilter.buildQuery(baseQuery: searchText)
        } else {
            query = searchText
        }

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: query, page: currentPage) { result in
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
        } else if selectedTab == .users {
            GitHubAPI.shared.searchUsers(query: query, page: currentPage) { result in
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
        } else {
            // 代码搜索加载更多
            GitHubAPI.shared.searchCode(query: query, page: currentPage) { result in
                DispatchQueue.main.async {
                    isLoading = false
                    switch result {
                    case .success(let codeResults):
                        self.codeResults.append(contentsOf: codeResults)
                        self.hasMoreResults = codeResults.count >= 30
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

// MARK: - 代码搜索结果行

struct CodeSearchRow: View {
    let item: CodeSearchItem

    var body: some View {
        HStack(spacing: 12) {
            // 文件图标
            Image(systemName: fileIconName)
                .font(.system(size: 24))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                // 文件名
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                // 文件路径
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 仓库信息
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    Text("\(item.repository.ownerName)/\(item.repository.name)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // 箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 8)
    }

    /// 根据文件扩展名获取图标名称
    private var fileIconName: String {
        let ext = (item.name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "py": return "python"
        case "java": return "cup.and.saucer"
        case "go": return "g.circle"
        case "rb": return "ruby"
        case "php": return "php"
        case "html", "htm": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "less": return "paintbrush"
        case "json", "xml", "yml", "yaml": return "list.bullet"
        case "md", "markdown": return "doc.text"
        case "sh", "bash": return "terminal"
        case "c", "h", "cpp", "hpp": return "c.square"
        case "rs": return "r.square"
        case "dart": return "dart"
        case "vue": return "v.square"
        case "sql": return "database"
        default: return "doc.text"
        }
    }
}
