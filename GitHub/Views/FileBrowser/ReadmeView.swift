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
// ==============================================================================

struct ReadmeView: View {
    let markdownContent: String
    let owner: String
    let repo: String
    let branch: String

    @EnvironmentObject var appState: AppState
    @State private var renderedHTML: String?
    @State private var isRendering: Bool = true
    @State private var renderError: String?
    @State private var webViewHeight: CGFloat = 400
    @State private var webViewKey: UUID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // README标题栏
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(appState.isDarkMode ? .gray : .secondary)

                Text("README.md")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appState.isDarkMode ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(appState.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.96))

            // 分割线
            Rectangle()
                .fill(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(height: 1)

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
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                        ScrollView {
                            Text(markdownContent)
                                .font(.system(size: 13))
                                .foregroundColor(appState.isDarkMode ? .white : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(16)
                        }
                    }
                    .frame(height: webViewHeight)
                }
            }
            .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : .white)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
        .onAppear {
            renderMarkdown()
        }
        .onChange(of: appState.isDarkMode) { _ in
            // 暗黑模式切换时重新渲染
            webViewKey = UUID()
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

// MARK: - ReadmeWebView 用于渲染README的WebView

struct ReadmeWebView: UIViewRepresentable {
    let htmlContent: String
    let isDarkMode: Bool
    let owner: String
    let repo: String
    let branch: String
    var onHeightChange: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // 注入JavaScript，用于获取内容高度
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChange")
        configuration.userContentController = userContentController

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.minimumFontSize = 0
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard !context.coordinator.hasLoaded else { return }
        context.coordinator.hasLoaded = true
        context.coordinator.parent = self

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

        // highlight.js 用于代码语法高亮（内联简化版）
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
            \(highlightJS)
            \(imageFixJS)
        </body>
        </html>
        """

        return fullHTML
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: ReadmeWebView
        var hasLoaded: Bool = false

        init(_ parent: ReadmeWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChange", let height = message.body as? CGFloat {
                parent.onHeightChange?(height)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
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
