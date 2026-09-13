import SwiftUI

// MARK: - 仓库内代码搜索页面

/// 仓库内代码搜索页面，支持搜索代码并显示代码片段
struct RepoCodeSearchView: View {
    let owner: String
    let repo: String
    let branch: String
    // 点击代码片段后的跳转回调（替代NotificationCenter，更SwiftUI风格）
    var onJumpToCode: ((_ filePath: String, _ lineNumber: Int) -> Void)?

    @State private var searchQuery: String = ""
    @State private var searchResults: [CodeSearchItem] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String?
    @State private var selectedItem: CodeSearchItem?
    @State private var showCodeSnippet: Bool = false
    // 防抖搜索任务
    @State private var searchTask: Task<Void, Never>?
    // 当前搜索请求任务（用于取消旧请求，解决竞态条件）
    @State private var currentSearchWorkItem: DispatchWorkItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 搜索框
                searchBar

                // 搜索结果统计栏（修正文案语义）
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
                            // 使用闭包回调替代NotificationCenter
                            onJumpToCode?(filePath, lineNumber)
                        }
                    )
                }
            }
            .onDisappear {
                // 视图消失时取消防抖任务，防止内存泄漏
                searchTask?.cancel()
                currentSearchWorkItem?.cancel()
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
                .textFieldStyle(.plain)  // 使用iOS16+推荐简写样式
                .textInputAutocapitalization(.never)  // 关闭自动大写，搜索代码时避免首字母大写影响准确性
                .autocorrectionDisabled()  // 关闭自动拼写纠错，避免搜索词被自动修改
                .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                // 使用iOS16.5兼容的双参数onChange（单参数版本在iOS17已废弃）
                .onChange(of: searchQuery) { _, newValue in
                    // 防抖搜索：取消上一次任务，300ms后执行新搜索
                    searchTask?.cancel()
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        searchResults = []
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
                    searchTask?.cancel()
                    currentSearchWorkItem?.cancel()
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

    // MARK: - 搜索结果统计栏（修正文案语义）

    private var searchStatsBar: some View {
        HStack {
            // 修正文案：items.count是文件数，不是匹配数
            Text("共找到 \(searchResults.count) 个文件包含匹配")
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
            // 搜索结果列表（使用.plain简写样式，移除默认行内边距避免双重padding）
            List {
                ForEach(searchResults) { item in
                    Button(action: {
                        selectedItem = item
                        showCodeSnippet = true
                    }) {
                        searchResultRow(item)
                    }
                    .buttonStyle(.plain)  // 使用iOS16+推荐简写样式
                    .listRowInsets(EdgeInsets())  // 移除List默认行内边距，由searchResultRow统一控制
                }
            }
            .listStyle(.plain)  // 使用iOS16+推荐简写样式
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

                // 文件路径（长路径中间截断）
                Text(item.path)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)  // 长路径中间截断，保留首尾关键信息

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

    // MARK: - 执行搜索（修复竞态条件+传入branch参数）

    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }

        // 取消上一次未完成的搜索请求，解决竞态条件
        currentSearchWorkItem?.cancel()

        isSearching = true
        errorMessage = nil
        searchResults = []

        // 捕获当前查询词，回调时校验，防止旧请求覆盖新结果
        let capturedQuery = searchQuery

        let workItem = DispatchWorkItem {
            GitHubAPI.shared.searchCodeInRepo(
                owner: owner,
                repo: repo,
                query: capturedQuery,
                branch: branch  // 传入当前分支参数，确保搜索范围为当前分支
            ) { result in
                DispatchQueue.main.async {
                    // 校验：如果查询词已变化或任务已取消，忽略旧请求结果
                    guard searchQuery == capturedQuery else { return }
                    guard !workItem.isCancelled else { return }

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

        currentSearchWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
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
    @State private var loadFileTask: Task<Void, Never>?  // 网络加载任务，用于取消
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFileContent()
            }
            .onDisappear {
                // 视图消失时取消网络请求，防止回调更新已销毁视图
                loadFileTask?.cancel()
            }
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
                // 文件路径（长路径中间截断）
                Text(item.path)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)  // 长路径中间截断，保留首尾关键信息
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
                    ForEach(snippets) { snippet in
                        snippetRow(snippet)
                        if snippet.id != snippets.last?.id {
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

    // MARK: - 代码片段行（修复Button嵌套ScrollView手势冲突）

    private func snippetRow(_ snippet: CodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 片段位置信息（仅在此区域添加点击手势，不包裹ScrollView）
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Text("第 \(snippet.lineNumber) 行")
                    .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Spacer()
                Text("点击跳转")
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
            .contentShape(Rectangle())
            // 仅在头部信息栏添加点击手势，ScrollView区域可正常横向滚动
            .onTapGesture {
                onJumpToCode?(item.path, snippet.lineNumber)
                dismiss()
            }

            // 代码内容（高亮关键词）- 独立ScrollView，不被Button包裹，手势不冲突
            ScrollView(.horizontal, showsIndicators: false) {
                highlightedCode(snippet.code)
                    .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                    .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
        }
    }

    // MARK: - 高亮关键词（使用AttributedString替代AnyView，提升性能）

    private func highlightedCode(_ code: String) -> Text {
        let attributed = buildHighlightedAttributedString(code)
        return Text(attributed)
    }

    // 构建高亮富文本（使用原始字符串range(of:options:)，避免小写字符串长度不匹配崩溃）
    private func buildHighlightedAttributedString(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        let normalFont = Font.system(size: 11, design: .monospaced)
        result.font = normalFont

        // 直接在原始字符串上使用不区分大小写搜索，返回的range即为原始字符串范围
        // 避免对小写字符串使用Range去索引原始字符串导致的Unicode长度不匹配崩溃
        var searchRange = code.startIndex..<code.endIndex

        while let range = code.range(of: searchQuery, options: .caseInsensitive, range: searchRange) {
            // 转换为AttributedString的范围
            if let attrRange = Range(range, in: result) {
                result[attrRange].font = Font.system(size: 11, weight: .bold, design: .monospaced)
                result[attrRange].backgroundColor = .yellow.opacity(0.5)
                result[attrRange].foregroundColor = .red
            }

            // 继续搜索剩余部分
            searchRange = range.upperBound..<code.endIndex
        }

        return result
    }

    // MARK: - 加载文件内容（增加Task取消机制）

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil
        snippets = []

        // 取消上一次未完成的加载任务
        loadFileTask?.cancel()

        loadFileTask = Task {
            // 使用withCheckedThrowingContinuation包装回调式API为async
            let result = await withCheckedContinuation { continuation in
                GitHubAPI.shared.getFileContent(
                    owner: owner,
                    repo: repo,
                    path: item.path,
                    branch: branch
                ) { result in
                    continuation.resume(returning: result)
                }
            }

            // 检查任务是否已取消
            guard !Task.isCancelled else { return }

            await MainActor.run {
                isLoading = false
                switch result {
                case .success(let file):
                    fileContent = file.decodedContent
                    // 片段提取移到后台线程执行，避免大文件卡顿UI
                    extractSnippetsInBackground()
                case .failure(let error):
                    errorMessage = "加载文件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 后台提取代码片段（优化算法+后台执行，避免UI卡顿）

    private func extractSnippetsInBackground() {
        guard let content = fileContent else { return }

        Task.detached(priority: .userInitiated) {
            let lines = content.components(separatedBy: .newlines)
            let lowercasedQuery = searchQuery.lowercased()

            // 优化算法：一次遍历直接构建合并区间，无需先存储所有匹配行索引
            // 减少大文件内存占用
            var mergedRanges: [(start: Int, end: Int)] = []
            var rangeStart: Int?
            var previousIndex: Int?

            for (index, line) in lines.enumerated() {
                if line.lowercased().contains(lowercasedQuery) {
                    if let prev = previousIndex {
                        if index == prev + 1 {
                            // 连续命中，扩展当前区间
                            previousIndex = index
                            continue
                        } else {
                            // 不连续，结束上一个区间
                            if let start = rangeStart {
                                mergedRanges.append((start: start, end: prev))
                            }
                            rangeStart = index
                            previousIndex = index
                        }
                    } else {
                        rangeStart = index
                        previousIndex = index
                    }
                }
            }
            // 处理最后一个区间
            if let start = rangeStart, let prev = previousIndex {
                mergedRanges.append((start: start, end: prev))
            }

            // 对每个合并区间生成一个片段（前后各2行上下文）
            var result: [CodeSnippet] = []
            for range in mergedRanges {
                let contextStart = max(0, range.start - 2)
                let contextEnd = min(lines.count - 1, range.end + 2)
                let snippetCode = lines[contextStart...contextEnd].joined(separator: "\n")

                result.append(CodeSnippet(
                    lineNumber: range.start + 1,
                    code: snippetCode
                ))

                // 最多显示20个片段
                if result.count >= 20 {
                    break
                }
            }

            // 回到主线程更新UI
            await MainActor.run {
                snippets = result
            }
        }
    }
}

// MARK: - 代码片段模型

/// 代码片段模型
struct CodeSnippet: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let code: String
}
