import SwiftUI
import WebKit

// ==============================================================================
// HTMLPreviewView HTML网页预览器
// 功能：使用WKWebView渲染HTML文件内容，支持本地HTML字符串和远程URL加载
// 优势：原生WKWebView性能好，支持JavaScript、CSS、图片等完整HTML渲染
// ==============================================================================

struct HTMLPreviewView: View {
    let htmlContent: String
    let title: String
    let baseURL: URL?

    @State private var isLoading: Bool = true
    @State private var errorMessage: String?

    init(htmlContent: String, title: String, baseURL: URL? = nil) {
        self.htmlContent = htmlContent
        self.title = title
        self.baseURL = baseURL
    }

    var body: some View {
        ZStack {
            // WebView始终创建，避免死循环（isLoading=true导致WebView不创建，WebView不创建导致onLoadingChange永远不调用）
            WebView(
                htmlContent: htmlContent,
                baseURL: baseURL,
                onLoadingChange: { loading in
                    DispatchQueue.main.async {
                        isLoading = loading
                    }
                },
                onError: { error in
                    DispatchQueue.main.async {
                        errorMessage = error
                        isLoading = false
                    }
                }
            )
            .edgesIgnoringSafeArea(.bottom)

            // 加载指示器叠加在WebView上面
            if isLoading {
                ZStack {
                    Color(.systemBackground).opacity(0.9)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                        Text("加载网页中...")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 错误提示
            if let error = errorMessage, !isLoading {
                ZStack {
                    Color(.systemBackground)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WebView UIViewRepresentable

struct WebView: UIViewRepresentable {
    let htmlContent: String
    let baseURL: URL?
    var onLoadingChange: ((Bool) -> Void)?
    var onError: ((String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        // 优化WKWebView配置，提升加载速度
        let configuration = WKWebViewConfiguration()

        // 启用进程池，复用进程
        configuration.processPool = WKProcessPool()

        // 启用数据检测器
        configuration.dataDetectorTypes = [.phoneNumber, .link, .address]

        // 启用媒体自动播放
        configuration.mediaTypesRequiringUserActionForPlayback = []

        // 允许内联媒体播放
        configuration.allowsInlineMediaPlayback = true

        // 忽略视口缩放限制，提升渲染性能
        configuration.ignoresViewportScaleLimits = true

        // 优化首屏渲染性能
        if #available(iOS 15.0, *) {
            // iOS 15+ 可以使用更高效的渲染模式
        }

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        preferences.javaScriptCanOpenWindowsAutomatically = true
        // 最小化字体大小，提升渲染速度
        preferences.minimumFontSize = 0
        configuration.preferences = preferences

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        // 优化滚动性能
        webView.scrollView.decelerationRate = .normal
        webView.scrollView.isScrollEnabled = true

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 避免重复加载
        guard !context.coordinator.hasLoaded else { return }
        context.coordinator.hasLoaded = true

        // 立即通知开始加载
        onLoadingChange?(true)

        // 加载HTML内容
        if let baseURL = baseURL {
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
        } else {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }

        // 本地HTML内容应该很快渲染完成，延迟0.3秒后关闭加载状态
        // 给WKWebView一点时间渲染基本内容，然后立即显示，不等待外部资源加载完成
        // 解决loadHTMLString加载本地内容时didFinish回调延迟触发（等待外部资源）的问题
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.onLoadingChange?(false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var hasLoaded: Bool = false

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.onLoadingChange?(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完成
            parent.onLoadingChange?(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // 忽略-999错误（NSURLErrorCancelled，请求被主动取消）
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else {
                parent.onLoadingChange?(false)
                return
            }
            // 页面加载失败
            parent.onLoadingChange?(false)
            parent.onError?(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            // 忽略-999错误（NSURLErrorCancelled，请求被主动取消）
            let nsError = error as NSError
            guard nsError.code != NSURLErrorCancelled else {
                parent.onLoadingChange?(false)
                return
            }
            // 页面加载失败（临时导航）
            parent.onLoadingChange?(false)
            parent.onError?(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            // 允许所有响应
            decisionHandler(.allow)
        }
    }
}
