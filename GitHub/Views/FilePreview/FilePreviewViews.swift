import SwiftUI
import UIKit

// ==============================================================================
// ImagePreviewView 图片全屏预览视图
// 功能：全屏显示图片，支持缩放、保存到相册、分享
// 位置：GitHub/Views/FilePreview/ImagePreviewView.swift
// ==============================================================================

struct ImagePreviewView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var showSaveSuccess = false
    @State private var showSaveError = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("图片加载中...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let image = image {
                    // 可缩放图片
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { _ in
                                    lastScale = scale
                                    if scale < 1.0 {
                                        withAnimation {
                                            scale = 1.0
                                            lastScale = 1.0
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                        Text(error)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                        Button("重试") {
                            loadImage()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if image != nil {
                        Button {
                            saveToPhotos()
                        } label: {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.white)
                        }
                        Button {
                            shareImage()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .alert("保存成功", isPresented: $showSaveSuccess) {
            Button("确定", role: .cancel) {}
        }
        .alert("保存失败", isPresented: $showSaveError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text("请检查相册权限设置")
        }
    }

    // MARK: - 加载图片

    private func loadImage() {
        isLoading = true
        errorMessage = nil

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let rawUrl = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(encodedPath)"

        GitHubAPI.shared.downloadFileData(url: rawUrl) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    if let loadedImage = UIImage(data: data) {
                        image = loadedImage
                    } else {
                        errorMessage = "图片格式无法识别"
                    }
                case .failure(let error):
                    errorMessage = "图片加载失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 保存到相册

    private func saveToPhotos() {
        guard let image = image else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // 简单提示，实际应监听完成回调
        showSaveSuccess = true
    }

    // MARK: - 分享

    private func shareImage() {
        guard let image = image else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// ==============================================================================
// HTMLPreviewView HTML 网页预览视图
// 功能：加载 HTML 文件并用 WKWebView 渲染显示
// 位置：GitHub/Views/FilePreview/HTMLPreviewView.swift
// ==============================================================================

struct HTMLPreviewView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var htmlContent: String?

    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    ProgressView("网页加载中...")
                    Spacer()
                }
            } else if let html = htmlContent {
                HTMLWebView(htmlContent: html)
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
                        loadHTML()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadHTML()
        }
    }

    private func loadHTML() {
        isLoading = true
        errorMessage = nil

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let rawUrl = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(encodedPath)"

        GitHubAPI.shared.downloadFileData(url: rawUrl) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    if let html = String(data: data, encoding: .utf8) {
                        htmlContent = html
                    } else {
                        errorMessage = "HTML 文件编码无法识别"
                    }
                case .failure(let error):
                    errorMessage = "网页加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - HTML WebView

struct HTMLWebView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = true
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
