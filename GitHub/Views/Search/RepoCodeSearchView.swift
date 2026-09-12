import SwiftUI

// MARK: - 仓库内代码搜索页面

/// 仓库内代码搜索页面，支持搜索代码并显示代码片段
struct RepoCodeSearchView: View {
    let owner: String
    let repo: String
    let branch: String

    @State private var searchQuery: String = ""
    @State private var searchResults: [CodeSearchItem] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var selectedItem: CodeSearchItem?
    @State private var showCodeSnippet: Bool = false

    // 代码片段缓存
    @State private var codeSnippets: [String: String] = [:]
    @State private var loadingSnippetPath: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                searchBar

                // 搜索结果列表
                searchResultsList
            }
            .navigationTitle("仓库代码搜索")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCodeSnippet) {
                if let item = selectedItem {
                    CodeSnippetView(
                        owner: owner,
                        repo: repo,
                        branch: branch,
                        item: item,
                        searchQuery: searchQuery
                    )
                }
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)

            TextField("输入关键词搜索代码...", text: $searchQuery, onCommit: {
                performSearch()
            })
            .textFieldStyle(PlainTextFieldStyle())
            .padding(.vertical, 8)

            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 搜索结果列表

    @ViewBuilder
    private var searchResultsList: some View {
        if isSearching {
            // 加载中
            VStack {
                Spacer()
                ProgressView("搜索中...")
                Spacer()
            }
        } else if let error = errorMessage {
            // 错误状态
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                Text(error)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") {
                    performSearch()
                }
                .foregroundColor(.blue)
                Spacer()
            }
            .padding()
        } else if searchResults.isEmpty && !searchQuery.isEmpty {
            // 无结果
            VStack {
                Spacer()
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
                Text("未找到匹配的代码")
                    .foregroundColor(.secondary)
                Spacer()
            }
        } else if searchResults.isEmpty {
            // 初始状态
            VStack {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                Text("在当前仓库中搜索代码")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("支持搜索代码内容、文件名等")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                Spacer()
            }
        } else {
            // 搜索结果列表
            List {
                ForEach(searchResults) { item in
                    Button(action: {
                        selectedItem = item
                        showCodeSnippet = true
                    }) {
                        searchResultRow(item)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(PlainListStyle())
        }
    }

    // MARK: - 搜索结果行

    private func searchResultRow(_ item: CodeSearchItem) -> some View {
        HStack(spacing: 12) {
            // 文件图标
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .font(.system(size: 20))
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                // 文件名
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 文件路径
                Text(item.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 右箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - 执行搜索

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil
        searchResults = []

        GitHubAPI.shared.searchCodeInRepo(
            owner: owner,
            repo: repo,
            query: searchQuery
        ) { result in
            DispatchQueue.main.async {
                isSearching = false
                switch result {
                case .success(let items):
                    searchResults = items
                case .failure(let error):
                    errorMessage = "搜索失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - 代码片段显示页面

/// 代码片段显示页面，获取文件内容并显示包含关键词的代码片段
struct CodeSnippetView: View {
    let owner: String
    let repo: String
    let branch: String
    let item: CodeSearchItem
    let searchQuery: String

    @State private var fileContent: String?
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var snippets: [CodeSnippet] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 文件信息头部
            fileHeader

            // 代码片段内容
            snippetContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground))
        .navigationTitle("代码片段")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing: Button("完成") {
            dismiss()
        })
        .onAppear {
            loadFileContent()
        }
    }

    // MARK: - 文件信息头部

    private var fileHeader: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))
                Text(item.path)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }

    // MARK: - 代码片段内容

    @ViewBuilder
    private var snippetContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("加载文件内容...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if let error = errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") {
                    loadFileContent()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if snippets.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.gray)
                Text("未找到包含关键词的代码片段")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            // 代码片段列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(snippets.enumerated()), id: \.offset) { index, snippet in
                        snippetRow(snippet, index: index)
                        if index < snippets.count - 1 {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - 代码片段行

    private func snippetRow(_ snippet: CodeSnippet, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 片段位置信息
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                Text("第 \(snippet.lineNumber) 行")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Spacer()
                Text("匹配 \(index + 1)")
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))

            // 代码内容（高亮关键词）
            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCode(snippet.code)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - 高亮关键词

    @ViewBuilder
    private func highlightedCode(_ code: String) -> some View {
        let parts = calculateHighlightedParts(code)
        Group {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                part
            }
        }
    }

    // 计算高亮文本片段（在ViewBuilder之外执行，避免控制流语句错误）
    private func calculateHighlightedParts(_ code: String) -> [AnyView] {
        let lowercasedCode = code.lowercased()
        let lowercasedQuery = searchQuery.lowercased()
        let normalFont = Font.system(size: 11, design: .monospaced)
        let boldFont = Font.system(size: 11, weight: .bold, design: .monospaced)

        var searchRange = lowercasedCode.startIndex..<lowercasedCode.endIndex
        var parts: [AnyView] = []

        while let range = lowercasedCode.range(of: lowercasedQuery, range: searchRange) {
            // 添加关键词之前的文本
            let beforeText = String(code[searchRange.lowerBound..<range.lowerBound])
            if !beforeText.isEmpty {
                parts.append(AnyView(Text(beforeText).font(normalFont)))
            }

            // 添加高亮的关键词
            let keyword = String(code[range])
            parts.append(AnyView(
                Text(keyword)
                    .font(boldFont)
                    .background(Color.yellow.opacity(0.5))
                    .foregroundColor(.red)
            ))

            // 继续搜索剩余部分
            searchRange = range.upperBound..<lowercasedCode.endIndex
        }

        // 添加最后剩余的文本
        let remainingText = String(code[searchRange])
        if !remainingText.isEmpty {
            parts.append(AnyView(Text(remainingText).font(normalFont)))
        }

        return parts
    }

    // MARK: - 加载文件内容

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil
        snippets = []

        GitHubAPI.shared.getFileContent(
            owner: owner,
            repo: repo,
            path: item.path,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let file):
                    fileContent = file.decodedContent
                    extractSnippets()
                case .failure(let error):
                    errorMessage = "加载文件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 提取代码片段

    private func extractSnippets() {
        guard let content = fileContent else { return }

        let lines = content.components(separatedBy: .newlines)
        let lowercasedQuery = searchQuery.lowercased()

        var result: [CodeSnippet] = []

        for (index, line) in lines.enumerated() {
            if line.lowercased().contains(lowercasedQuery) {
                // 提取包含关键词的行，以及前后各2行作为上下文
                let start = max(0, index - 2)
                let end = min(lines.count - 1, index + 2)
                let snippetCode = lines[start...end].joined(separator: "\n")

                result.append(CodeSnippet(
                    lineNumber: index + 1,
                    code: snippetCode
                ))

                // 最多显示20个片段
                if result.count >= 20 {
                    break
                }
            }
        }

        snippets = result
    }
}

// MARK: - 代码片段模型

/// 代码片段模型
struct CodeSnippet: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let code: String
}
