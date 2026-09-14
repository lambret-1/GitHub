import SwiftUI

// MARK: - 仓库内代码搜索页面

/// 仓库内代码搜索页面，支持搜索代码并显示代码片段
struct RepoCodeSearchView: View {
    // ViewModel
    @StateObject private var viewModel: RepoCodeSearchViewModel

    // 点击代码片段后的跳转回调
    var onJumpToCode: ((_ filePath: String, _ lineNumber: Int) -> Void)?

    // 初始化
    init(
        owner: String,
        repo: String,
        branch: String,
        onJumpToCode: ((_ filePath: String, _ lineNumber: Int) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: RepoCodeSearchViewModel(
            owner: owner,
            repo: repo,
            branch: branch
        ))
        self.onJumpToCode = onJumpToCode
    }

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            // 状态内容
            content
        }
        .navigationTitle("仓库代码搜索")
        .navigationBarTitleDisplayMode(.inline)
        // 使用.sheet(item:)替代.isPresented+if let，避免item为nil时白屏
        .sheet(item: $viewModel.selectedResult) { result in
            CodeSnippetView(
                result: result,
                viewModel: viewModel,
                onJumpToCode: onJumpToCode
            )
        }
        .onDisappear {
            // 视图消失时取消所有任务，防止内存泄漏
            viewModel.cancel()
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)  // 这是左侧内边距，控制搜索图标左方与边缘的空白距离，单位是pt；改大左方留白更宽图标更靠右，改小左方留白更窄图标更靠左；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边

            TextField("输入关键词搜索代码...", text: $viewModel.query)
                .textFieldStyle(.plain)  // 使用iOS16+推荐简写样式
                .textInputAutocapitalization(.never)  // 关闭自动大写，搜索代码时避免首字母大写影响准确性
                .autocorrectionDisabled()  // 关闭自动拼写纠错，避免搜索词被自动修改
                .padding(.vertical, 8)  // 这是垂直内边距，控制输入框上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽输入框更高，改小上下留白更窄输入框更矮；还能改成.top/.bottom单独控制某一侧
                // 使用iOS14+兼容的单参数onChange（双参数版本仅iOS17+可用）
                .onChange(of: viewModel.query) { newValue in
                    viewModel.search(with: newValue)
                }

            // 清空按钮（输入框非空时显示）
            if !viewModel.query.isEmpty {
                Button(action: {
                    viewModel.clearSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)  // 这是右侧内边距，控制清空按钮右方与边缘的空白距离，单位是pt；改大右方留白更宽按钮更靠左，改小右方留白更窄按钮更靠右；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(8)  // 这是圆角半径尺寸，控制搜索框四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
        .padding(.horizontal)
        .padding(.vertical, 8)  // 这是垂直内边距，控制搜索框上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽搜索框更靠中间，改小上下留白更窄搜索框更靠边；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 状态内容（状态机）

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle:
            idleView
        case .searching:
            loadingView
        case .success:
            resultsListView
        case .empty:
            emptyView
        case .error(let message):
            errorView(message)
        }
    }

    // MARK: - 初始状态视图

    private var idleView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))  // 这是字体大小尺寸，控制放大镜图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.gray)
            Text("在当前仓库中搜索代码")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("支持搜索代码内容、文件名等")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 4)  // 这是顶部内边距，控制提示文字上方与标题的空白距离，单位是pt；改大上方留白更宽两行间距更大，改小上方留白更窄两行间距更小；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - 加载中视图

    private var loadingView: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView("搜索中...")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - 搜索结果列表视图

    private var resultsListView: some View {
        VStack(spacing: 0) {
            // 搜索结果统计栏
            searchStatsBar

            // 搜索结果列表
            List {
                ForEach(viewModel.results) { result in
                    Button(action: {
                        viewModel.selectResult(result)
                    }) {
                        searchResultRow(result)
                    }
                    .buttonStyle(.plain)  // 使用iOS16+推荐简写样式
                    .listRowInsets(EdgeInsets())  // 移除List默认行内边距，由searchResultRow统一控制
                }
            }
            .listStyle(.plain)  // 使用iOS16+推荐简写样式
        }
    }

    // MARK: - 搜索结果统计栏

    private var searchStatsBar: some View {
        HStack {
            // 修正文案：results.count是文件数，不是匹配数
            Text("共找到 \(viewModel.results.count) 个文件包含匹配")
                .font(.system(size: 12))  // 这是字体大小尺寸，控制统计文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制统计栏左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 6)  // 这是垂直内边距，控制统计栏上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    // MARK: - 搜索结果行

    private func searchResultRow(_ result: CodeSearchResult) -> some View {
        HStack(spacing: 12) {
            // 文件图标
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
                .font(.system(size: 20))  // 这是字体大小尺寸，控制文件图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .frame(width: 28)  // 这是视图宽度尺寸，控制文件图标区域的水平显示宽度，单位是pt；改大区域横向更宽，改小区域横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            VStack(alignment: .leading, spacing: 4) {
                // 文件名
                Text(result.fileName)
                    .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制文件名的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.primary)
                    .lineLimit(1)

                // 文件路径（长路径中间截断）
                Text(result.filePath)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文件路径的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)  // 长路径中间截断，保留首尾关键信息

                // 匹配提示
                Text("点击查看匹配的代码片段")
                    .font(.system(size: 11))  // 这是字体大小尺寸，控制提示文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)
                    .lineLimit(1)
            }

            Spacer()

            // 右箭头
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.system(size: 12))  // 这是字体大小尺寸，控制右箭头的显示大小，单位是pt；改大箭头更醒目易读但占空间，改小箭头更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制搜索结果行左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 12)  // 这是垂直内边距，控制搜索结果行上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .contentShape(Rectangle())
    }

    // MARK: - 空结果视图

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))  // 这是字体大小尺寸，控制空结果图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.gray)
            Text("未找到匹配的代码")
                .font(.system(size: 14))  // 这是字体大小尺寸，控制空结果文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - 错误视图

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))  // 这是字体大小尺寸，控制错误图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 14))  // 这是字体大小尺寸，控制错误文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("重试") {
                viewModel.retry()
            }
            .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制重试按钮文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
            .foregroundColor(.blue)
            .padding(.horizontal, 24)  // 这是水平内边距，控制重试按钮左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽按钮更宽，改小左右留白更窄按钮更窄；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 10)  // 这是垂直内边距，控制重试按钮上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽按钮更高，改小上下留白更窄按钮更矮；还能改成.top/.bottom单独控制某一侧
            .background(Color(.systemGray6))
            .cornerRadius(8)  // 这是圆角半径尺寸，控制重试按钮四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            Spacer()
        }
        .padding(.horizontal, 24)  // 这是水平内边距，控制错误视图左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - 代码片段显示页面

/// 代码片段显示页面，获取文件内容并显示包含关键词的代码片段
struct CodeSnippetView: View {
    let result: CodeSearchResult
    @ObservedObject var viewModel: RepoCodeSearchViewModel
    var onJumpToCode: ((_ filePath: String, _ lineNumber: Int) -> Void)?

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
        }
    }

    // MARK: - 文件信息头部

    private var fileHeader: some View {
        HStack {
            Image(systemName: "doc.text")
                .foregroundColor(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text(result.fileName)
                    .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制文件名的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                // 文件路径（长路径中间截断）
                Text(result.filePath)
                    .font(.system(size: 12))  // 这是字体大小尺寸，控制文件路径的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)  // 长路径中间截断，保留首尾关键信息
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 12)  // 这是垂直内边距，控制文件信息头上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    // MARK: - 代码片段内容

    @ViewBuilder
    private var snippetContent: some View {
        if viewModel.snippetLoading {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)  // 这是视图缩放比例，控制加载指示器整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大指示器放大更醒目，改小指示器缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
                Text("加载文件内容...")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制加载文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if let error = viewModel.snippetError {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制错误图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.orange)
                Text(error)
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制错误文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button("重试") {
                    viewModel.loadSnippets(for: result)
                }
                .font(.system(size: 15, weight: .medium))  // 这是字体大小尺寸，控制重试按钮文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.blue)
                .padding(.horizontal, 24)  // 这是水平内边距，控制重试按钮左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽按钮更宽，改小左右留白更窄按钮更窄；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 10)  // 这是垂直内边距，控制重试按钮上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽按钮更高，改小上下留白更窄按钮更矮；还能改成.top/.bottom单独控制某一侧
                .background(Color(.systemGray6))
                .cornerRadius(8)  // 这是圆角半径尺寸，控制重试按钮四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }
            .padding(.horizontal, 24)  // 这是水平内边距，控制错误视图左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else if viewModel.snippets.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 40))  // 这是字体大小尺寸，控制空结果图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Text("未找到包含关键词的代码片段")
                    .font(.system(size: 14))  // 这是字体大小尺寸，控制空结果文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        } else {
            // 代码片段列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.snippets) { snippet in
                        snippetRow(snippet)
                        if snippet.id != viewModel.snippets.last?.id {
                            Divider()
                                .padding(.leading, 40)  // 这是左侧内边距，控制分隔线左方与边缘的空白距离，单位是pt；改大左方留白更宽分隔线更短，改小左方留白更窄分隔线更长；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
                        }
                    }
                }
                .padding(.vertical, 8)  // 这是垂直内边距，控制片段列表上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
            .background(Color(.systemBackground))
        }
    }

    // MARK: - 代码片段行（整个行可点击跳转，包括代码区域）

    private func snippetRow(_ snippet: CodeSnippet) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // 片段位置信息
            HStack {
                Image(systemName: "number")
                    .font(.system(size: 10))  // 这是字体大小尺寸，控制行号图标的显示大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Text("第 \(snippet.startLine)-\(snippet.endLine) 行")
                    .font(.system(size: 11))  // 这是字体大小尺寸，控制行号文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                Spacer()
                Text("点击跳转")
                    .font(.system(size: 11))  // 这是字体大小尺寸，控制跳转提示文字的显示大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))  // 这是字体大小尺寸，控制右箭头的显示大小，单位是pt；改大箭头更醒目易读但占空间，改小箭头更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.gray)
                    .padding(.leading, 4)  // 这是左侧内边距，控制右箭头左方与文字的空白距离，单位是pt；改大左方留白更宽箭头更靠右，改小左方留白更窄箭头更靠左；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制位置信息栏左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 6)  // 这是垂直内边距，控制位置信息栏上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            .background(Color(.systemGray6))

            // 代码内容（高亮关键词）- 整个行可点击，包括代码区域
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(snippet.lines) { line in
                        codeLineView(line)
                    }
                }
                .padding(.horizontal, 16)  // 这是水平内边距，控制代码内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 8)  // 这是垂直内边距，控制代码内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
        }
        .contentShape(Rectangle())
        // 修复：整个行（包括代码区域）都可点击跳转，与"点击跳转"提示语义一致
        .onTapGesture {
            // 跳转到第一个匹配行
            let jumpLine = snippet.matchLineNumbers.first ?? snippet.startLine
            onJumpToCode?(result.filePath, jumpLine)
            dismiss()
        }
    }

    // MARK: - 代码行视图（带行号和高亮）

    private func codeLineView(_ line: CodeLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // 行号
            Text("\(line.lineNumber)")
                .font(.system(size: 11, design: .monospaced))  // 这是字体大小尺寸，控制行号的显示大小，单位是pt；改大行号更醒目易读但占空间，改小行号更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .trailing)  // 这是视图宽度尺寸，控制行号区域的水平显示宽度，单位是pt；改大区域横向更宽行号更靠右，改小区域横向更窄行号更靠左；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            // 代码内容（高亮关键词）
            highlightedLine(line)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 高亮关键词（使用AttributedString）

    private func highlightedLine(_ line: CodeLine) -> Text {
        let attributed = buildHighlightedAttributedString(line.content)
        return Text(attributed)
    }

    // 构建高亮富文本（使用原始字符串range(of:options:)，避免小写字符串长度不匹配崩溃）
    // 注意：AttributedString的font/backgroundColor/foregroundColor需使用UIKit类型（UIFont/UIColor）
    private func buildHighlightedAttributedString(_ code: String) -> AttributedString {
        var result = AttributedString(code)
        // 使用UIFont设置AttributedString字体（UIKit类型，非SwiftUI Font）
        let normalFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let boldFont = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        result.font = normalFont

        // 修复：空查询时直接返回，避免range(of:)死循环
        let trimmedQuery = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return result
        }

        // 直接在原始字符串上使用不区分大小写搜索，返回的range即为原始字符串范围
        // 避免对小写字符串使用Range去索引原始字符串导致的Unicode长度不匹配崩溃
        var searchRange = code.startIndex..<code.endIndex

        while let range = code.range(of: trimmedQuery, options: .caseInsensitive, range: searchRange) {
            // 转换为AttributedString的范围
            if let attrRange = Range(range, in: result) {
                // 使用UIColor设置背景色和前景色（UIKit类型）
                result[attrRange].font = boldFont
                result[attrRange].backgroundColor = UIColor.yellow.withAlphaComponent(0.5)
                result[attrRange].foregroundColor = UIColor.red
            }

            // 继续搜索剩余部分（防止空匹配导致死循环）
            if range.upperBound == searchRange.lowerBound {
                break
            }
            searchRange = range.upperBound..<code.endIndex
        }

        return result
    }
}
