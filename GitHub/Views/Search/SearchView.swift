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

    enum SearchTab: String, CaseIterable {
        case repositories = "仓库"
        case users = "用户"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText, placeholder: "搜索仓库或用户", onSearchButtonClicked: {
                    performSearch()
                })
                .padding(.horizontal)
                .padding(.vertical, 8)

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
    }

    // MARK: - 搜索方法

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        currentPage = 1
        hasMoreResults = true

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: searchText, page: currentPage) { result in
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
            GitHubAPI.shared.searchUsers(query: searchText, page: currentPage) { result in
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

        if selectedTab == .repositories {
            GitHubAPI.shared.searchRepos(query: searchText, page: currentPage) { result in
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
            GitHubAPI.shared.searchUsers(query: searchText, page: currentPage) { result in
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
            CachedImageView(urlString: user.avatarUrl, size: CGSize(width: 48, height: 48))
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

// MARK: - 搜索栏组件

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "搜索"
    var onSearchButtonClicked: (() -> Void)? = nil

    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        var onSearchButtonClicked: (() -> Void)?

        init(text: Binding<String>, onSearchButtonClicked: (() -> Void)?) {
            _text = text
            self.onSearchButtonClicked = onSearchButtonClicked
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
            onSearchButtonClicked?()
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text, onSearchButtonClicked: onSearchButtonClicked)
    }

    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: UIViewRepresentableContext<SearchBar>) {
        uiView.text = text
    }
}
