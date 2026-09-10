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
                        }
                    }
                    .listStyle(PlainListStyle())
                    .refreshable {
                        loadRepos()
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
            .sheet(isPresented: $showSearchView) {
                SearchView()
                    .environmentObject(appState)
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
    
    private func loadRepos() {
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
                Label("\(repo.stargazersCount)", systemImage: "star.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Label("\(repo.forksCount)", systemImage: "tuningfork")
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
    
    class Coordinator: NSObject, UISearchBarDelegate {
        @Binding var text: String
        
        init(text: Binding<String>) {
            _text = text
        }
        
        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }
        
        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(text: $text)
    }
    
    func makeUIView(context: UIViewRepresentableContext<SearchBar>) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.placeholder = placeholder
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
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
