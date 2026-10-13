import SwiftUI
import WebKit

// MARK: - 通用文件编辑器视图
// 功能：查看文件内容、编辑文件、搜索内容、保存提交到仓库
// 注意：本视图未被实际使用，实际文件查看器为 CodeEditorView

struct FileEditorView: View {
    let owner: String
    let repo: String
    let filePath: String
    let branch: String

    // 文件内容相关状态
    @State private var fileContent: String = ""
    @State private var originalContent: String = ""
    @State private var fileSha: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var showCopySuccess: Bool = false

    // 编辑模式相关状态
    @State private var isEditing: Bool = false
    @State private var showSaveAlert: Bool = false
    @State private var commitMessage: String = ""
    @State private var isSaving: Bool = false
    @State private var saveErrorMessage: String?
    @State private var showSaveSuccess: Bool = false

    // 搜索相关状态
    @State private var showSearch: Bool = false
    @State private var searchText: String = ""
    @State private var currentMatchIndex: Int = 0
    @State private var totalMatches: Int = 0

    // 视图模式相关状态
    @State private var 当前视图模式: 文件视图模式 = .code

    // Preview 预览相关状态
    @State private var 预览渲染HTML: String?
    @State private var 预览渲染中: Bool = false
    @State private var 预览渲染错误: String?
    @State private var 预览WebView高度: CGFloat = 400

    // Blame 追溯相关状态
    @State private var blame提交列表: [Commit] = []
    @State private var blame加载中: Bool = false
    @State private var blame错误: String?

    // 环境对象
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            if showSearch {
                searchBar
            }

            // 视图模式切换器（Preview / Code / Blame）
            视图模式切换器

            // 文件内容区域
            fileContentSection
        }
        .navigationTitle((filePath as NSString).lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    // 搜索按钮
                    Button(action: {
                        showSearch.toggle()
                        if !showSearch {
                            searchText = ""
                            currentMatchIndex = 0
                            totalMatches = 0
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                    }

                    // 复制按钮
                    Button(action: {
                        UIPasteboard.general.string = fileContent
                        showCopySuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopySuccess = false
                        }
                    }) {
                        Image(systemName: "doc.on.doc")
                    }

                    // 编辑/完成按钮（仅 Code 模式显示）
                    if 当前视图模式 == .code {
                        Button(action: {
                            if isEditing {
                                // 完成编辑，检查是否有修改
                                if fileContent != originalContent {
                                    showSaveAlert = true
                                } else {
                                    isEditing = false
                                }
                            } else {
                                isEditing = true
                            }
                        }) {
                            Text(isEditing ? "完成" : "编辑")
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .alert("保存修改", isPresented: $showSaveAlert) {
            TextField("提交信息", text: $commitMessage)
            Button("保存") {
                saveFile()
            }
            Button("取消", role: .cancel) {
                isEditing = false
                fileContent = originalContent
            }
        } message: {
            Text("输入提交信息，将修改保存到仓库")
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("确定") {
                isEditing = false
            }
        } message: {
            Text("文件已成功提交到仓库")
        }
        .alert("保存失败", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("确定") {}
        } message: {
            Text(saveErrorMessage ?? "未知错误")
        }
        .overlay {
            if showCopySuccess {
                VStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.green)
                    Text("已复制到剪贴板")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(24)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(12)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                .shadow(radius: 8)
            }

            if isSaving {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
                        Text("正在保存...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(32)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                    .background(Color(.systemGray6))
                    .cornerRadius(16)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
            }
        }
        .onAppear {
            loadFileContent()
        }
    }

    // MARK: - 视图模式切换器

    private var 视图模式切换器: some View {
        HStack(spacing: 0) {
            ForEach(文件视图模式.allCases) { mode in
                Button(action: {
                    当前视图模式 = mode
                    // 切换到对应模式时按需加载数据
                    if mode == .blame && blame提交列表.isEmpty && !blame加载中 {
                        加载Blame数据()
                    }
                    if mode == .preview && 预览渲染HTML == nil && !预览渲染中 {
                        渲染预览内容()
                    }
                }) {
                    Text(mode.rawValue)
                        .font(.system(size: 15, weight: 当前视图模式 == mode ? .semibold : .regular))
                        .foregroundColor(当前视图模式 == mode ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            if 当前视图模式 == mode {
                                Rectangle()
                                    .fill(Color.accentColor)
                                    .frame(height: 2)
                            }
                        }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .background(Color(.systemGray6))
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }

    // MARK: - 搜索栏

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索内容", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _ in
                    calculateMatches()
                }
            if !searchText.isEmpty {
                Text("\(currentMatchIndex + 1)/\(totalMatches)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button(action: {
                    findPrevious()
                }) {
                    Image(systemName: "chevron.up")
                        .foregroundColor(.blue)
                }
                Button(action: {
                    findNext()
                }) {
                    Image(systemName: "chevron.down")
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    // MARK: - 文件内容区域

    private var fileContentSection: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("加载文件中...")
                    Spacer()
                }
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadFileContent()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else {
                switch 当前视图模式 {
                case .preview:
                    预览视图内容
                case .code:
                    代码视图内容
                case .blame:
                    Blame视图内容
                }
            }
        }
    }

    // MARK: - Code 代码视图内容

    private var 代码视图内容: some View {
        Group {
            if isEditing {
                // 编辑模式：使用TextEditor
                TextEditor(text: $fileContent)
                    .font(.system(.body, design: .monospaced))
                    .padding(4)
                    .background(Color(.systemBackground))
            } else {
                // 查看模式：使用ScrollView+Text
                ScrollView {
                    if totalMatches > 0 && !searchText.isEmpty {
                        // 有搜索结果时，显示高亮内容
                        highlightedContent
                    } else {
                        Text(fileContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
            }
        }
    }

    // MARK: - Preview 预览视图内容

    private var 预览视图内容: some View {
        Group {
            if 预览渲染中 {
                VStack {
                    Spacer()
                    ProgressView("渲染预览中...")
                    Spacer()
                }
            } else if let error = 预览渲染错误 {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        渲染预览内容()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if 文件是图片类型 {
                // 图片文件：显示图片
                ScrollView {
                    图片预览视图
                }
            } else if let html = 预览渲染HTML {
                // Markdown 或已渲染的 HTML：用 WebView 显示
                文件预览WebView(html内容: html, 高度: $预览WebView高度, owner: owner, repo: repo, branch: branch)
                    .frame(height: 预览WebView高度)
            } else {
                // 纯文本文件：直接显示
                ScrollView {
                    Text(fileContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
        }
    }

    // MARK: - 图片预览视图

    private var 图片预览视图: some View {
        AsyncImage(url: URL(string: 图片原始URL)) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(8)
            case .failure:
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("图片加载失败")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - Blame 追溯视图内容

    private var Blame视图内容: some View {
        Group {
            if blame加载中 {
                VStack {
                    Spacer()
                    ProgressView("加载追溯信息中...")
                    Spacer()
                }
            } else if let error = blame错误 {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        加载Blame数据()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if blame提交列表.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("暂无提交记录")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(blame提交列表) { commit in
                        Blame提交行(commit: commit)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }

    // MARK: - Blame 提交行视图

    private struct Blame提交行: View {
        let commit: Commit
        @EnvironmentObject var appState: AppState

        var body: some View {
            HStack(alignment: .top, spacing: 12) {
                // 作者头像
                AsyncImage(url: URL(string: commit.author?.avatarUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        Color.gray
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                // 提交信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(commit.message)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(commit.authorName)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text(commit.formattedDate)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // 提交 SHA
                Text(String(commit.sha.prefix(7)))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
    }

    // MARK: - 文件预览 WebView

    private struct 文件预览WebView: UIViewRepresentable {
        let html内容: String
        @Binding var 高度: CGFloat
        let owner: String
        let repo: String
        let branch: String
        @EnvironmentObject var appState: AppState

        func makeCoordinator() -> Coordinator {
            Coordinator(高度: $高度)
        }

        func makeUIView(context: Context) -> WKWebView {
            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = context.coordinator
            webView.scrollView.isScrollEnabled = false
            webView.isOpaque = false
            return webView
        }

        func updateUIView(_ webView: WKWebView, context: Context) {
            let 完整HTML = 构建完整HTML(内容: html内容)
            webView.loadHTMLString(完整HTML, baseURL: nil)
        }

        private func 构建完整HTML(内容: String) -> String {
            let 主题类名 = appState.isDarkMode ? "markdown-body dark" : "markdown-body"
            return """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body { margin: 0; padding: 16px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
                    .markdown-body { max-width: 100%; word-wrap: break-word; }
                    .markdown-body.dark { background-color: #0d1117; color: #c9d1d9; }
                    .markdown-body pre { background-color: #f6f8fa; padding: 16px; border-radius: 6px; overflow-x: auto; }
                    .markdown-body.dark pre { background-color: #161b22; }
                    .markdown-body code { background-color: rgba(175,184,193,0.2); padding: 2px 6px; border-radius: 4px; font-size: 85%; }
                    .markdown-body pre code { background-color: transparent; padding: 0; }
                    .markdown-body img { max-width: 100%; height: auto; }
                    .markdown-body table { border-collapse: collapse; width: 100%; }
                    .markdown-body th, .markdown-body td { border: 1px solid #d0d7de; padding: 6px 13px; }
                    .markdown-body.dark th, .markdown-body.dark td { border-color: #30363d; }
                    .markdown-body blockquote { border-left: 4px solid #d0d7de; padding-left: 16px; color: #57606a; margin: 0; }
                    .markdown-body.dark blockquote { border-color: #30363d; color: #8b949e; }
                    .markdown-body a { color: #0969da; text-decoration: none; }
                    .markdown-body.dark a { color: #58a6ff; }
                    .markdown-body h1, .markdown-body h2 { border-bottom: 1px solid #d0d7de; padding-bottom: 0.3em; }
                    .markdown-body.dark h1, .markdown-body.dark h2 { border-color: #21262d; }
                </style>
            </head>
            <body class="\(主题类名)">
                <div class="\(主题类名)">
                    \(内容)
                </div>
            </body>
            </html>
            """
        }

        class Coordinator: NSObject, WKNavigationDelegate {
            @Binding var 高度: CGFloat

            init(高度: Binding<CGFloat>) {
                _高度 = 高度
            }

            func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
                webView.evaluateJavaScript("document.documentElement.scrollHeight") { result, _ in
                    if let height = result as? CGFloat {
                        DispatchQueue.main.async {
                            self.高度 = height
                        }
                    }
                }
            }
        }
    }

    // MARK: - 高亮搜索内容

    private var highlightedContent: some View {
        let lines = fileContent.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    // 行号
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    // 内容（高亮匹配项）
                    highlightText(in: line)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 1)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .padding(.horizontal, 4)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .background(isLineMatch(line) ? Color.yellow.opacity(0.2) : Color.clear)
            }
        }
        .padding(8)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
    }

    @ViewBuilder
    private func highlightText(in line: String) -> some View {
        if searchText.isEmpty {
            Text(line)
        } else {
            // 使用AttributedString实现高亮
            if let attributedString = createHighlightedAttributedString(from: line) {
                Text(attributedString)
            } else {
                Text(line)
            }
        }
    }

    private func createHighlightedAttributedString(from line: String) -> AttributedString? {
        guard !searchText.isEmpty else { return nil }
        var attributed = AttributedString(line)
        guard let range = attributed.range(of: searchText, options: .caseInsensitive) else {
            return attributed
        }
        attributed[range].backgroundColor = .yellow
        attributed[range].foregroundColor = .black
        return attributed
    }

    private func isLineMatch(_ line: String) -> Bool {
        return line.range(of: searchText, options: .caseInsensitive) != nil
    }

    // MARK: - 搜索功能

    private func calculateMatches() {
        guard !searchText.isEmpty else {
            totalMatches = 0
            currentMatchIndex = 0
            return
        }
        let lines = fileContent.components(separatedBy: .newlines)
        totalMatches = lines.filter { isLineMatch($0) }.count
        currentMatchIndex = 0
    }

    private func findNext() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex + 1) % totalMatches
    }

    private func findPrevious() {
        guard totalMatches > 0 else { return }
        currentMatchIndex = (currentMatchIndex - 1 + totalMatches) % totalMatches
    }

    // MARK: - 加载文件内容

    private func loadFileContent() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getFileContent(
            owner: owner,
            repo: repo,
            path: filePath,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let fileContent):
                    let content = fileContent.decodedContent
                    if !content.isEmpty {
                        self.fileContent = content
                        self.originalContent = content
                        self.fileSha = fileContent.sha
                    } else {
                        self.errorMessage = "无法解码文件内容"
                    }
                case .failure(let error):
                    self.errorMessage = "加载文件失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 保存文件

    private func saveFile() {
        guard !commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            saveErrorMessage = "请输入提交信息"
            return
        }

        isSaving = true
        saveErrorMessage = nil

        GitHubAPI.shared.updateFile(
            owner: owner,
            repo: repo,
            path: filePath,
            content: fileContent,
            sha: fileSha,
            message: commitMessage,
            branch: branch
        ) { result in
            DispatchQueue.main.async {
                isSaving = false
                switch result {
                case .success:
                    self.originalContent = self.fileContent
                    self.commitMessage = ""
                    self.showSaveSuccess = true
                    // 重新加载文件内容以获取新的sha
                    self.loadFileContent()
                case .failure(let error):
                    self.saveErrorMessage = "保存失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 文件类型判断

    /// 文件扩展名（小写，不含点号）
    private var 文件扩展名: String {
        let nsString = filePath as NSString
        let ext = nsString.pathExtension.lowercased()
        return ext
    }

    /// 是否为图片文件
    private var 文件是图片类型: Bool {
        let 图片扩展名集合: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "svg", "webp", "ico", "tiff", "tif"]
        return 图片扩展名集合.contains(文件扩展名)
    }

    /// 是否为 Markdown 文件
    private var 文件是Markdown类型: Bool {
        let markdown扩展名集合: Set<String> = ["md", "markdown", "mkd", "mdown", "mdx"]
        return markdown扩展名集合.contains(文件扩展名)
    }

    /// 图片原始 URL（用于图片预览）
    private var 图片原始URL: String {
        let 编码路径 = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filePath
        return "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(编码路径)"
    }

    // MARK: - 渲染预览内容

    private func 渲染预览内容() {
        // 图片文件不需要渲染，直接显示
        guard !文件是图片类型 else { return }

        预览渲染中 = true
        预览渲染错误 = nil

        if 文件是Markdown类型 {
            // Markdown 文件：调用 GitHub 官方 Markdown API 渲染
            GitHubAPI.shared.renderMarkdown(markdown: fileContent, context: "\(owner)/\(repo)") { result in
                DispatchQueue.main.async {
                    预览渲染中 = false
                    switch result {
                    case .success(let html):
                        预览渲染HTML = html
                    case .failure(let error):
                        预览渲染错误 = "Markdown 渲染失败: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            // 其他文本文件：直接显示纯文本，无需渲染
            预览渲染中 = false
            预览渲染HTML = nil
        }
    }

    // MARK: - 加载 Blame 数据

    private func 加载Blame数据() {
        blame加载中 = true
        blame错误 = nil

        GitHubAPI.shared.getCommits(owner: owner, repo: repo, path: filePath, branch: branch, perPage: 50) { result in
            DispatchQueue.main.async {
                blame加载中 = false
                switch result {
                case .success(let commits):
                    blame提交列表 = commits
                case .failure(let error):
                    blame错误 = "加载追溯信息失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
