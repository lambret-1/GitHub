import SwiftUI

struct RepoListView: View {
    @EnvironmentObject var appState: AppState
    @State private var repos: [Repository] = []
    @State private var filteredRepos: [Repository] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var selectedFilter: FilterType = .all
    @State private var showSearchView: Bool = false
    // 删除仓库相关状态
    @State private var repoToDelete: Repository?
    @State private var showDeleteConfirm: Bool = false
    @State private var isDeletingRepo: Bool = false
    // 重命名仓库相关状态
    @State private var repoToRename: Repository?
    @State private var showRenameDialog: Bool = false
    @State private var newRepoName: String = ""
    @State private var isRenamingRepo: Bool = false
    
    enum FilterType: String, CaseIterable {
        case all = "全部"
        case owner = "我的"
        case `private` = "私有"
        case publicRepo = "公开"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                SearchBar(text: $searchText, placeholder: "搜索仓库")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                
                // 筛选栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FilterType.allCases, id: \.self) { filter in
                            FilterChip(title: filter.rawValue, isSelected: selectedFilter == filter) {
                                selectedFilter = filter
                                applyFilter()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // 仓库列表
                if isLoading {
                    Spacer()
                    ProgressView("加载仓库中...")
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
                            loadRepos()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    Spacer()
                } else if filteredRepos.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.questionmark")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("没有找到仓库")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredRepos) { repo in
                            NavigationLink(destination: FileBrowserView(repository: repo)) {
                                RepoRow(repo: repo)
                            }
                            // 重按菜单（长按仓库弹出操作菜单）
                            .contextMenu {
                                // 重命名仓库
                                Button(action: {
                                    repoToRename = repo
                                    newRepoName = repo.name
                                    showRenameDialog = true
                                }) {
                                    Label("重命名仓库", systemImage: "pencil")
                                }

                                // 复制仓库地址
                                Button(action: {
                                    let repoURL = "https://github.com/\(repo.ownerName)/\(repo.name)"
                                    UIPasteboard.general.string = repoURL
                                }) {
                                    Label("复制仓库地址", systemImage: "link")
                                }

                                Divider()

                                // 删除仓库
                                Button(role: .destructive, action: {
                                    repoToDelete = repo
                                    showDeleteConfirm = true
                                }) {
                                    Label("删除仓库", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        await loadReposAsync()
                    }
                }
            }
            .navigationTitle("仓库")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: {
                            showSearchView = true
                        }) {
                            Image(systemName: "magnifyingglass")
                        }
                        Button(action: {
                            loadRepos()
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showSearchView) {
                SearchView()
                    .environmentObject(appState)
            }
            // 删除仓库二次确认弹窗
            .alert("确认删除仓库", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {
                    repoToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let repo = repoToDelete {
                        deleteRepository(repo)
                    }
                }
            } message: {
                if let repo = repoToDelete {
                    Text("确定要删除仓库「\(repo.ownerName)/\(repo.name)」吗？此操作不可撤销，仓库的所有代码、Issue、Pull Request都将被永久删除。")
                } else {
                    Text("确定要删除该仓库吗？此操作不可撤销。")
                }
            }
            // 重命名仓库弹窗
            .alert("重命名仓库", isPresented: $showRenameDialog) {
                TextField("新仓库名称", text: $newRepoName)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Button("取消", role: .cancel) {
                    repoToRename = nil
                    newRepoName = ""
                }
                Button("重命名") {
                    if let repo = repoToRename, !newRepoName.isEmpty {
                        renameRepository(repo, newName: newRepoName)
                    }
                }
                .disabled(newRepoName.isEmpty || isRenamingRepo)
            } message: {
                if let repo = repoToRename {
                    Text("请输入仓库「\(repo.name)」的新名称。重命名后，旧的仓库URL将自动重定向到新URL。")
                } else {
                    Text("请输入新的仓库名称。")
                }
            }
        }
        .onAppear {
            if repos.isEmpty {
                loadRepos()
            }
        }
        // 监听账号切换，切换后自动重新加载仓库
        .onChange(of: AccountManager.shared.currentAccount?.id) { _ in
            repos = []
            filteredRepos = []
            loadRepos()
        }
        .onChange(of: searchText) { _ in
            applyFilter()
        }
    }
    
    private func loadRepos(completion: (() -> Void)? = nil) {
        isLoading = true
        errorMessage = nil
        
        GitHubAPI.shared.getUserRepos { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let repos):
                    self.repos = repos
                    applyFilter()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
                completion?()
            }
        }
    }

    // 异步加载仓库，用于下拉刷新
    private func loadReposAsync() async {
        await withCheckedContinuation { continuation in
            loadRepos {
                // 最小延迟确保刷新动画流畅
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }

    // 删除仓库（需要admin权限）
    private func deleteRepository(_ repo: Repository) {
        isDeletingRepo = true
        GitHubAPI.shared.deleteRepository(owner: repo.ownerName, repo: repo.name) { result in
            DispatchQueue.main.async {
                isDeletingRepo = false
                repoToDelete = nil
                switch result {
                case .success:
                    // 从列表中移除已删除的仓库
                    repos.removeAll { $0.id == repo.id }
                    applyFilter()
                    // 显示删除成功提示（可以用appState或者其他方式）
                case .failure(let error):
                    errorMessage = "删除仓库失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // 重命名仓库（需要admin权限）
    private func renameRepository(_ repo: Repository, newName: String) {
        isRenamingRepo = true
        GitHubAPI.shared.updateRepository(owner: repo.ownerName, repo: repo.name, name: newName) { result in
            DispatchQueue.main.async {
                isRenamingRepo = false
                repoToRename = nil
                newRepoName = ""
                switch result {
                case .success:
                    // 重命名成功后重新加载仓库列表（因为Repository.name是let常量，不能直接修改）
                    loadRepos()
                case .failure(let error):
                    errorMessage = "重命名仓库失败: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func applyFilter() {
        var result = repos
        
        // 关键词搜索
        if !searchText.isEmpty {
            result = result.filter { repo in
                repo.name.lowercased().contains(searchText.lowercased()) ||
                (repo.description?.lowercased().contains(searchText.lowercased()) ?? false)
            }
        }
        
        // 类型筛选
        switch selectedFilter {
        case .all:
            break
        case .owner:
            if let user = appState.currentUser {
                result = result.filter { $0.ownerName == user.login }
            }
        case .private:
            result = result.filter { $0.isPrivate }
        case .publicRepo:
            result = result.filter { !$0.isPrivate }
        }
        
        filteredRepos = result
    }
}

// MARK: - 仓库行视图

struct RepoRow: View {
    let repo: Repository
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: repo.isPrivate ? "lock.fill" : "folder.fill")
                    .foregroundColor(repo.isPrivate ? .orange : .blue)
                Text(repo.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if let language = repo.language {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: repo.languageColor))
                            .frame(width: 10, height: 10)
                        Text(language)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 16) {
                Label("\(repo.stargazersCount ?? 0)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(repo.forksCount ?? 0)", systemImage: "tuningfork")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(repo.formattedUpdateTime)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 搜索栏

struct SearchBar: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSearchButtonClicked: (() -> Void)?

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

// MARK: - 筛选标签

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isSelected ? Color.black : Color.gray.opacity(0.15))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Color 扩展

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

struct RepoListView_Previews: PreviewProvider {
    static var previews: some View {
        RepoListView()
            .environmentObject(AppState.shared)
    }
}
