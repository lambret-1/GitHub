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
    // 防抖搜索任务（使用Task代替Timer，更可靠）
    @State private var searchTask: Task<Void, Never>?
    // 搜索结果总数
    @State private var totalCount: Int = 0

    // 代码片段缓存
    @State private var codeSnippets: [String: String] = [:]
    @State private var loadingSnippetPath: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                searchBar

                // 搜索结果统计栏
                if !searchResults.isEmpty {
                    searchStatsBar
                }

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
                        searchQuery: searchQuery,
                        onJumpToCode: { filePath, lineNumber in
                            // 跳转到代码编辑页面的通知
                            NotificationCenter.default.post(
                                name: NSNotification.Name("JumpToCodeNotification"),
                                object: nil,
                                userInfo: ["filePath": filePath, "lineNumber": lineNumber]
                            )
                        }
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
                .padding(.leading, 8)  // 这是左侧内边距，控制内容左方与边缘的空白距离，单位是pt；改大左方留白更宽，改小左方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边

            TextField("输入关键词搜索代码...", text: $searchQuery)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .onChange(of: searchQuery) { newValue in
                    // 防抖搜索：取消上一次任务，300ms后执行新搜索
                    searchTask?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        searchResults = []
                        totalCount = 0
                        return
                    }
                    searchTask = Task {
                        // 等待300ms防抖
                        try? await Task.sleep(nanoseconds: 300_000_000)
                        // 检查任务是否被取消
                        if !Task.isCancelled {
                            performSearch()
                        }
                    }
                }

            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                    totalCount = 0
                    searchTask?.cancel()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)  // 这是右侧内边距，控制内容右方与边缘的空白距离，单位是pt；改大右方留白更宽，改小右方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
        .padding(.horizontal)
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 搜索结果统计栏

    private var searchStatsBar: some View {
        HStack {
            Text("共找到 \(totalCount) 个匹配，分布在 \(searchResults.count) 个文件")
                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
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
                    .font(.system(size: 60))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Text("在当前仓库中搜索代码")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("支持搜索代码内容、文件名等")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)  // 这是顶部内边距，控制内容上方与边缘的空白距离，单位是pt；改大上方留白更宽，改小上方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
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
                .font(.system(size: 20))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .frame(width: 28)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            VStack(alignment: .leading, spacing: 4) {
                // 文件名
                Text(item.name)
                    .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 文件路径
                Text(item.path)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 匹配提示
                Text("点击查看匹配的代码片段")
                    .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            Spacer()

            // 右箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .contentShape(Rectangle())
    }

    // MARK: - 执行搜索

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            totalCount = 0
            return
        }

        isSearching = true
        errorMessage = nil
        searchResults = []
        totalCount = 0

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
                    totalCount = items.count
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
    // 点击代码片段后的回调，传递文件路径和行号
    var onJumpToCode: ((_ filePath: String, _ lineNumber: Int) -> Void)?

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
                    .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                Text(item.path)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    // MARK: - 代码片段内容

    @ViewBuilder
    private var snippetContent: some View {
        if isLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
                Text("加载文件内容...")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if let error = errorMessage {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") {
                    loadFileContent()
                }
                .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.blue)
                .padding(.horizontal, 24)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 10)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color(.systemGray6))
                .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }
            .padding(.horizontal, 24)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if snippets.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Text("未找到包含关键词的代码片段")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
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
                                .padding(.leading, 40)  // 这是左侧内边距，控制内容左方与边缘的空白距离，单位是pt；改大左方留白更宽，改小左方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
                        }
                    }
                }
                .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - 代码片段行

    private func snippetRow(_ snippet: CodeSnippet, index: Int) -> some View {
        Button(action: {
            // 点击跳转到代码编辑页面
            onJumpToCode?(item.path, snippet.lineNumber)
            dismiss()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                // 片段位置信息
                HStack {
                    Image(systemName: "number")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.gray)
                    Text("第 \(snippet.lineNumber) 行")
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.gray)
                    Spacer()
                    Text("匹配 \(index + 1)")
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.gray)
                        .padding(.leading, 4)  // 这是左侧内边距，控制内容左方与边缘的空白距离，单位是pt；改大左方留白更宽，改小左方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
                }
                .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color(.systemGray6))

                // 代码内容（高亮关键词）
                ScrollView(.horizontal, showsIndicators: false) {
                    highlightedCode(snippet.code)
                        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Rectangle())
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
