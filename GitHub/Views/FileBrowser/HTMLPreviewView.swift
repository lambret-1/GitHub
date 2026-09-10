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
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("加载网页中...")
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
                }
                .padding()
                Spacer()
            } else {
                WebView(htmlContent: htmlContent, baseURL: baseURL)
                    .edgesIgnoringSafeArea(.bottom)
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

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // 加载HTML内容
        if let baseURL = baseURL {
            webView.loadHTMLString(htmlContent, baseURL: baseURL)
        } else {
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // 页面加载完成
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            // 页面加载失败
        }
    }
}
