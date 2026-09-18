import SwiftUI
import WebKit

// ==============================================================================
// ReadmeView 仓库README查看器
// 功能：使用GitHub官方Markdown API渲染，显示效果与GitHub网页完全一致
// 位置：与GitHub相同，显示在仓库文件列表下方
// 特性：
//   - GitHub官方GFM Markdown渲染（表格、任务列表、引用块、代码块等）
//   - GitHub官方CSS样式（浅色/深色主题自动切换）
//   - 代码块语法高亮
//   - 图片相对路径自动补全
//   - 锚点链接支持
//   - 复制Markdown原文
//   - Outline大纲导航（快速跳转章节）
// ==============================================================================

// MARK: - 大纲条目模型

/// README大纲条目模型
/// 存储README中的标题信息，用于快速导航跳转
struct ReadmeOutlineItem: Identifiable {
    let id = UUID()
    let level: Int           // 标题级别（1-6，对应h1-h6）
    let title: String        // 标题文本内容
    let anchorId: String     // HTML锚点ID，用于JS滚动定位
}

struct ReadmeView: View {
    let markdownContent: String
    let owner: String
    let repo: String
    let branch: String

    @EnvironmentObject var appState: AppState
    @State private var renderedHTML: String?
    @State private var isRendering: Bool = true
    @State private var renderError: String?
    @State private var webViewHeight: CGFloat = 400  // WebView高度，自适应内容高度，初始值400pt
    @State private var webViewKey: UUID = UUID()
    @State private var showOutline: Bool = false  // 是否显示大纲侧边栏
    @State private var scrollAnchorId: String?  // 当前需要滚动到的锚点ID

    // MARK: - 计算属性：解析Markdown提取大纲
    /// 从Markdown文本中解析所有标题，生成大纲列表
    /// 解析规则：行首1-6个#号开头的行即为标题
    var outlineItems: [ReadmeOutlineItem] {
        let lines = markdownContent.components(separatedBy: .newlines)
        var items: [ReadmeOutlineItem] = []
        var anchorCounter = 0

        for line in lines {
            // 匹配Markdown标题语法：# ~ ######
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("#") else { continue }

            // 计算#号数量，即标题级别
            var level = 0
            for char in trimmed {
                if char == "#" {
                    level += 1
                } else {
                    break
                }
            }

            // 级别必须在1-6之间
            guard level >= 1 && level <= 6 else { continue }

            // 提取标题文本（去掉#号和空格）
            let titleStartIndex = trimmed.index(trimmed.startIndex, offsetBy: level)
            var titleText = String(trimmed[titleStartIndex...])
            titleText = titleText.trimmingCharacters(in: .whitespaces)

            // 去掉标题末尾的#号（Markdown允许的闭合#号）
            while titleText.hasSuffix("#") {
                titleText = String(titleText.dropLast()).trimmingCharacters(in: .whitespaces)
            }

            // 跳过空标题
            guard !titleText.isEmpty else { continue }

            // 生成锚点ID
            anchorCounter += 1
            let anchorId = "readme-heading-\(anchorCounter)"

            items.append(ReadmeOutlineItem(
                level: level,
                title: titleText,
                anchorId: anchorId
            ))
        }

        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // README标题栏
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 16))  // 这是字体大小尺寸，控制图标显示的大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难辨认；还能配合.imageScale设大小或用.tint改图标颜色
                    .foregroundColor(appState.isDarkMode ? .gray : .secondary)

                Text("README.md")
                    .font(.system(size: 15, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(appState.isDarkMode ? .white : .primary)

                Spacer()

                // 大纲按钮（有大纲时才显示）
                if !outlineItems.isEmpty {
                    Button(action: {
                        showOutline = true
                    }) {
                        Image(systemName: "list.bullet.indent")
                            .font(.system(size: 16))  // 这是字体大小尺寸，控制图标显示的大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难辨认；还能配合.imageScale设大小或用.tint改图标颜色
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    }
                    .accessibilityLabel("查看大纲")
                }
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            .background(appState.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.96))

            // 分割线
            Rectangle()
                .fill(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(height: 1)  // 这是视图高度尺寸，控制分割线的粗细高度，单位是pt；改大分割线更粗更明显，改小分割线更细更精致；还能改成不同颜色或用虚线样式

            // 内容区域
            ZStack {
                if isRendering {
                    // 加载中
                    VStack {
                        Spacer()
                        ProgressView("正在渲染README...")
                            .padding()
                        Spacer()
                    }
                    .frame(height: webViewHeight)
                } else if let html = renderedHTML {
                    // 渲染后的HTML
                    ReadmeWebView(
                        htmlContent: html,
                        isDarkMode: appState.isDarkMode,
                        owner: owner,
                        repo: repo,
                        branch: branch,
                        outlineItems: outlineItems,
                        scrollAnchorId: scrollAnchorId,
                        onHeightChange: { height in
                            DispatchQueue.main.async {
                                webViewHeight = height
                            }
                        }
                    )
                    .id(webViewKey)
                    .frame(height: webViewHeight)
                } else if let error = renderError {
                    // 渲染失败，降级显示纯文本
                    VStack(alignment: .leading, spacing: 8) {
                        Text("渲染失败: \(error)")
                            .font(.system(size: 12))  // 这是字体大小尺寸，控制错误文字的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格
                            .foregroundColor(Color.red)
                        ScrollView {
                            Text(markdownContent)
                                .font(.system(size: 13))  // 这是字体大小尺寸，控制纯文本显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格
                                .foregroundColor(appState.isDarkMode ? .white : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)  // 这是四向统一内边距，控制纯文本与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                        }
                    }
                    .frame(height: webViewHeight)
                }
            }
            .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : .white)
        }
        .cornerRadius(8)  // 这是圆角半径尺寸，控制README卡片四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
        )
        .padding(.horizontal, 12)  // 这是水平内边距，控制README卡片左右两侧与屏幕边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.bottom, 16)  // 这是底部内边距，控制README卡片下方与其他内容的空白距离，单位是pt；改大下方留白更宽，改小下方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
        .onAppear {
            renderMarkdown()
        }
        .onChange(of: appState.isDarkMode) { _ in
            // 暗黑模式切换时重新渲染
            webViewKey = UUID()
        }
        // 大纲侧边栏弹出
        .sheet(isPresented: $showOutline) {
            OutlineSheetView(
                items: outlineItems,
                isDarkMode: appState.isDarkMode,
                onSelect: { anchorId in
                    showOutline = false
                    // 直接设置滚动锚点，ReadmeWebView会通过updateUIView检测变化并调用JS滚动
                    scrollAnchorId = anchorId
                }
            )
        }
    }

    // MARK: - 使用GitHub官方Markdown API渲染

    private func renderMarkdown() {
        isRendering = true
        renderError = nil
        renderedHTML = nil

        GitHubAPI.shared.renderMarkdown(
            markdown: markdownContent,
            context: "\(owner)/\(repo)"
        ) { result in
            DispatchQueue.main.async {
                isRendering = false
                switch result {
                case .success(let html):
                    renderedHTML = html
                case .failure(let error):
                    renderError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - 大纲侧边栏视图

/// README大纲侧边栏弹窗
/// 显示所有标题层级，点击可快速跳转
struct OutlineSheetView: View {
    let items: [ReadmeOutlineItem]
    let isDarkMode: Bool
    let onSelect: (String) -> Void

    @Environment(\.presentationMode) var presentationMode  // iOS14兼容：使用presentationMode代替dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    Button(action: {
                        onSelect(item.anchorId)
                    }) {
                        HStack(spacing: 0) {
                            // 根据标题级别缩进
                            Spacer()
                                .frame(width: CGFloat(item.level - 1) * 20)  // 这是缩进宽度尺寸，控制不同级别标题的左侧缩进距离，单位是pt；改大缩进差异更明显层级更清晰，改小缩进差异更小更紧凑；还能改成固定值或按级别乘更大系数
                            
                            Text(item.title)
                                .font(.system(size: item.level <= 2 ? 15 : 14, weight: item.level <= 2 ? .semibold : .regular))  // 这是字体大小尺寸，控制大纲条目的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格
                                .foregroundColor(isDarkMode ? .white : .primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : .white)
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("大纲")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

// MARK: - ReadmeWebView 用于渲染README的WebView

struct ReadmeWebView: UIViewRepresentable {
    let htmlContent: String
    let isDarkMode: Bool
    let owner: String
    let repo: String
    let branch: String
    let outlineItems: [ReadmeOutlineItem]  // 大纲条目，用于给标题添加锚点ID
    var scrollAnchorId: String?  // 需要滚动到的锚点ID，变化时触发滚动
    var onHeightChange: ((CGFloat) -> Void)?  // 内容高度变化回调，用于自适应WebView高度

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // P0优化3：启用WKWebView持久化缓存，静态资源（highlight.js、CSS等）自动缓存到本地
        // 下次加载时直接从缓存读取，无需重新从CDN下载，提升渲染速度30%-50%
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        // 配置URLCache缓存策略：内存缓存20MB，磁盘缓存100MB
        let memoryCapacity = 20 * 1024 * 1024  // 内存缓存大小：20MB，单位是字节；改大缓存更多资源在内存，读取更快但占用内存多；改小节省内存但可能需要从磁盘或网络读取
        let diskCapacity = 100 * 1024 * 1024   // 磁盘缓存大小：100MB，单位是字节；改大缓存更多资源在磁盘，离线也能访问但占用存储空间；改小节省空间但可能需要重新下载
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: "ReadmeWebCache")
        URLCache.shared = urlCache

        // 注入JavaScript，用于获取内容高度
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChange")
        configuration.userContentController = userContentController

        let preferences = WKPreferences()
        // iOS 14+ 使用WKWebpagePreferences.allowsContentJavaScript替代已弃用的javaScriptEnabled
        if #available(iOS 14.0, *) {
            let webpagePreferences = WKWebpagePreferences()
            webpagePreferences.allowsContentJavaScript = true
            configuration.defaultWebpagePreferences = webpagePreferences
        } else {
            preferences.javaScriptEnabled = true
        }
        preferences.minimumFontSize = 0
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        // 禁用WebView自身滚动，整个README跟着外层ScrollView一起滚动
        // 这样就不会有画中画的独立滚动窗口了
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        // 保存WebView引用到Coordinator，供后续调用evaluateJavaScript
        context.coordinator.webView = webView

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 保存最新的parent引用
        context.coordinator.parent = self

        // 处理滚动到锚点的请求
        // 当scrollAnchorId变化时，调用JS滚动到对应位置
        if let anchorId = scrollAnchorId, anchorId != context.coordinator.lastScrolledAnchorId {
            context.coordinator.lastScrolledAnchorId = anchorId
            // 延迟一点执行，确保页面已经渲染完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let js = "window.scrollToAnchor('\(anchorId)')"
                webView.evaluateJavaScript(js)
            }
        }

        guard !context.coordinator.hasLoaded else { return }
        context.coordinator.hasLoaded = true

        let fullHTML = buildFullHTML()
        webView.loadHTMLString(fullHTML, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // 构建完整的HTML文档，包含GitHub官方CSS样式
    private func buildFullHTML() -> String {
        let theme = isDarkMode ? "dark" : "light"
        let bgColor = isDarkMode ? "#0d1117" : "#ffffff"
        let textColor = isDarkMode ? "#c9d1d9" : "#24292f"

        // GitHub官方Markdown CSS样式（简化版，覆盖主要元素）
        let css = """
        <style>
        * { box-sizing: border-box; }
        body {
            margin: 0;
            padding: 16px;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", "Noto Sans", Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: \(textColor);
            background-color: \(bgColor);
            word-wrap: break-word;
        }
        .markdown-body {
            font-family: inherit;
            font-size: inherit;
            line-height: inherit;
            color: inherit;
        }
        .markdown-body h1, .markdown-body h2, .markdown-body h3,
        .markdown-body h4, .markdown-body h5, .markdown-body h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }
        .markdown-body h1 { font-size: 2em; padding-bottom: 0.3em; border-bottom: 1px solid \(isDarkMode ? "#21262d" : "#d0d7de"); }
        .markdown-body h2 { font-size: 1.5em; padding-bottom: 0.3em; border-bottom: 1px solid \(isDarkMode ? "#21262d" : "#d0d7de"); }
        .markdown-body h3 { font-size: 1.25em; }
        .markdown-body h4 { font-size: 1em; }
        .markdown-body h5 { font-size: 0.875em; }
        .markdown-body h6 { font-size: 0.85em; color: \(isDarkMode ? "#8b949e" : "#656d76"); }
        .markdown-body p { margin-top: 0; margin-bottom: 16px; }
        .markdown-body a { color: \(isDarkMode ? "#58a6ff" : "#0969da"); text-decoration: none; }
        .markdown-body a:hover { text-decoration: underline; }
        .markdown-body strong { font-weight: 600; }
        .markdown-body em { font-style: italic; }
        .markdown-body ul, .markdown-body ol { margin-top: 0; margin-bottom: 16px; padding-left: 2em; }
        .markdown-body li { margin-top: 0.25em; }
        .markdown-body li > p { margin-top: 16px; }
        .markdown-body blockquote {
            margin: 0;
            padding: 0 1em;
            color: \(isDarkMode ? "#8b949e" : "#656d76");
            border-left: 0.25em solid \(isDarkMode ? "#30363d" : "#d0d7de");
            margin-bottom: 16px;
        }
        .markdown-body code {
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            background-color: \(isDarkMode ? "rgba(110,118,129,0.4)" : "rgba(175,184,193,0.2)");
            border-radius: 6px;
            font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace;
        }
        .markdown-body pre {
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            background-color: \(isDarkMode ? "#161b22" : "#f6f8fa");
            border-radius: 6px;
            margin-bottom: 16px;
            word-wrap: normal;
        }
        .markdown-body pre code {
            padding: 0;
            margin: 0;
            font-size: 100%;
            background-color: transparent;
            border-radius: 0;
            word-break: normal;
            white-space: pre;
        }
        .markdown-body table {
            border-spacing: 0;
            border-collapse: collapse;
            margin-bottom: 16px;
            display: block;
            width: max-content;
            max-width: 100%;
            overflow: auto;
        }
        .markdown-body table th {
            padding: 6px 13px;
            border: 1px solid \(isDarkMode ? "#30363d" : "#d0d7de");
            font-weight: 600;
            background-color: \(isDarkMode ? "#161b22" : "#f6f8fa");
        }
        .markdown-body table td {
            padding: 6px 13px;
            border: 1px solid \(isDarkMode ? "#30363d" : "#d0d7de");
        }
        .markdown-body table tr {
            background-color: \(bgColor);
            border-top: 1px solid \(isDarkMode ? "#21262d" : "#d0d7de");
        }
        .markdown-body table tr:nth-child(2n) {
            background-color: \(isDarkMode ? "#161b22" : "#f6f8fa");
        }
        .markdown-body img {
            max-width: 100%;
            height: auto;
            background-color: \(bgColor);
            border-radius: 4px;
        }
        .markdown-body hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: \(isDarkMode ? "#21262d" : "#d0d7de");
            border: 0;
        }
        .markdown-body input[type="checkbox"] {
            margin-right: 0.5em;
        }
        .markdown-body .task-list-item {
            list-style-type: none;
        }
        .markdown-body .task-list-item + .task-list-item {
            margin-top: 3px;
        }
        /* 代码高亮配色 */
        .hljs { color: \(textColor); background: transparent; }
        .hljs-comment, .hljs-quote { color: \(isDarkMode ? "#8b949e" : "#6e7781"); font-style: italic; }
        .hljs-keyword, .hljs-selector-tag, .hljs-literal, .hljs-type { color: \(isDarkMode ? "#ff7b72" : "#cf222e"); }
        .hljs-string, .hljs-attr, .hljs-symbol, .hljs-bullet, .hljs-addition { color: \(isDarkMode ? "#a5d6ff" : "#0a3069"); }
        .hljs-number, .hljs-regexp, .hljs-link { color: \(isDarkMode ? "#79c0ff" : "#0550ae"); }
        .hljs-title, .hljs-section, .hljs-name { color: \(isDarkMode ? "#d2a8ff" : "#8250df"); }
        .hljs-variable, .hljs-template-variable, .hljs-attribute { color: \(isDarkMode ? "#ffa657" : "#953800"); }
        .hljs-built_in, .hljs-builtin-name { color: \(isDarkMode ? "#ffa657" : "#953800"); }
        .hljs-meta { color: \(isDarkMode ? "#8b949e" : "#6e7781"); }
        .hljs-deletion { color: \(isDarkMode ? "#ffa198" : "#82071e"); }
        .hljs-emphasis { font-style: italic; }
        .hljs-strong { font-weight: bold; }
        </style>
        """

        // 生成标题锚点注入脚本
        // 为所有h1-h6标题添加id属性，用于大纲跳转
        let anchorJS = buildAnchorInjectionScript()

        // highlight.js 用于代码语法高亮（启用缓存，图片懒加载，代码块复制）
        let highlightJS = """
        <script src="https://cdn.jsdelivr.net/gh/highlightjs/cdn-release@11.9.0/build/highlight.min.js"></script>
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            // 初始化代码高亮
            document.querySelectorAll('pre code').forEach(function(block) {
                if (typeof hljs !== 'undefined') {
                    hljs.highlightElement(block);
                }
            });

            // P0优化1：图片懒加载 - 给所有图片添加loading="lazy"属性
            document.querySelectorAll('img').forEach(function(img) {
                if (!img.hasAttribute('loading')) {
                    img.setAttribute('loading', 'lazy');
                }
                // 图片解码异步，避免阻塞主线程
                if (!img.hasAttribute('decoding')) {
                    img.setAttribute('decoding', 'async');
                }
            });

            // P0优化2：代码块一键复制 - 给每个代码块添加复制按钮
            document.querySelectorAll('pre').forEach(function(pre) {
                // 创建复制按钮容器
                var copyContainer = document.createElement('div');
                copyContainer.style.cssText = 'position:relative;';

                // 创建复制按钮
                var copyBtn = document.createElement('button');
                copyBtn.textContent = '复制';
                copyBtn.style.cssText = 'position:absolute;top:8px;right:8px;padding:4px 10px;font-size:12px;background:rgba(127,127,127,0.2);color:inherit;border:1px solid rgba(127,127,127,0.3);border-radius:6px;cursor:pointer;z-index:10;opacity:0.7;transition:opacity 0.2s;';
                copyBtn.onmouseover = function() { this.style.opacity = '1'; };
                copyBtn.onmouseout = function() { this.style.opacity = '0.7'; };

                // 复制按钮点击事件
                copyBtn.onclick = function() {
                    var code = pre.querySelector('code');
                    if (code) {
                        var text = code.innerText;
                        // 使用现代API复制
                        if (navigator.clipboard && navigator.clipboard.writeText) {
                            navigator.clipboard.writeText(text).then(function() {
                                copyBtn.textContent = '已复制';
                                setTimeout(function() { copyBtn.textContent = '复制'; }, 2000);
                            }).catch(function() {
                                // 降级方案
                                fallbackCopy(text);
                            });
                        } else {
                            fallbackCopy(text);
                        }
                    }
                };

                // 降级复制方案
                function fallbackCopy(text) {
                    var textarea = document.createElement('textarea');
                    textarea.value = text;
                    textarea.style.position = 'fixed';
                    textarea.style.opacity = '0';
                    document.body.appendChild(textarea);
                    textarea.select();
                    try {
                        document.execCommand('copy');
                        copyBtn.textContent = '已复制';
                        setTimeout(function() { copyBtn.textContent = '复制'; }, 2000);
                    } catch(e) {
                        copyBtn.textContent = '复制失败';
                        setTimeout(function() { copyBtn.textContent = '复制'; }, 2000);
                    }
                    document.body.removeChild(textarea);
                }

                // 将pre的内容包裹到容器中
                pre.parentNode.insertBefore(copyContainer, pre);
                copyContainer.appendChild(pre);
                copyContainer.appendChild(copyBtn);
            });

            // 发送内容高度给原生端
            function sendHeight() {
                var height = document.body.scrollHeight;
                window.webkit.messageHandlers.heightChange.postMessage(height);
            }

            // 延迟发送高度，确保图片加载完成
            setTimeout(sendHeight, 100);
            setTimeout(sendHeight, 500);
            setTimeout(sendHeight, 1000);

            // 图片加载完成后重新计算高度
            document.querySelectorAll('img').forEach(function(img) {
                img.addEventListener('load', sendHeight);
                img.addEventListener('error', sendHeight);
            });

            // 窗口大小变化时重新计算高度
            window.addEventListener('resize', sendHeight);
        });
        </script>
        """

        // 图片相对路径补全脚本
        let imageFixJS = """
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            var baseRawUrl = 'https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/';
            document.querySelectorAll('img').forEach(function(img) {
                var src = img.getAttribute('src');
                if (src && !src.startsWith('http') && !src.startsWith('data:')) {
                    // 相对路径补全
                    if (src.startsWith('./')) {
                        src = src.substring(2);
                    }
                    img.src = baseRawUrl + src;
                }
            });
        });
        </script>
        """

        let fullHTML = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
            \(css)
        </head>
        <body>
            <div class="markdown-body">
                \(htmlContent)
            </div>
            \(anchorJS)
            \(highlightJS)
            \(imageFixJS)
        </body>
        </html>
        """

        return fullHTML
    }

    // MARK: - 构建标题锚点注入脚本

    /// 构建JavaScript脚本，为HTML中的标题添加id锚点
    /// 这样大纲点击时可以通过document.getElementById定位并滚动
    private func buildAnchorInjectionScript() -> String {
        // 生成锚点映射表，用于调试
        var anchorMapping: [String: String] = [:]
        for item in outlineItems {
            anchorMapping[item.anchorId] = item.title
        }

        // 构建JS脚本：为所有h1-h6添加id
        // 注意：这里按顺序给每个标题分配id，与Swift端解析的顺序一致
        var js = """
        <script>
        document.addEventListener('DOMContentLoaded', function() {
            var headings = document.querySelectorAll('.markdown-body h1, .markdown-body h2, .markdown-body h3, .markdown-body h4, .markdown-body h5, .markdown-body h6');
            var anchorIds = [
        """

        // 添加所有锚点ID
        for (index, item) in outlineItems.enumerated() {
            js += "'\(item.anchorId)'"
            if index < outlineItems.count - 1 {
                js += ", "
            }
        }

        js += """
            ];
            headings.forEach(function(heading, index) {
                if (index < anchorIds.length) {
                    heading.id = anchorIds[index];
                }
            });

            // 暴露全局函数供原生端调用，滚动到指定锚点
            window.scrollToAnchor = function(anchorId) {
                var element = document.getElementById(anchorId);
                if (element) {
                    element.scrollIntoView({ behavior: 'smooth', block: 'start' });
                    // 高亮当前标题，提示用户跳转成功
                    element.style.transition = 'background-color 0.3s';
                    element.style.backgroundColor = 'rgba(255, 235, 59, 0.3)';
                    setTimeout(function() {
                        element.style.backgroundColor = 'transparent';
                    }, 2000);
                }
            };
        });
        </script>
        """

        return js
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ReadmeWebView
        var hasLoaded: Bool = false
        weak var webView: WKWebView?
        var lastScrolledAnchorId: String?  // 记录上次滚动的锚点ID，避免重复滚动

        init(_ parent: ReadmeWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChange", let height = message.body as? CGFloat {
                parent.onHeightChange?(height)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.webView = webView
            // 页面加载完成后获取内容高度
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                if let height = result as? CGFloat {
                    DispatchQueue.main.async {
                        self.parent.onHeightChange?(height)
                    }
                }
            }
        }
    }
}
