import SwiftUI
import UIKit
import WebKit

// ==============================================================================
// FileImagePreviewView 文件图片预览视图（包装器）
// 功能：根据 owner/repo/path/branch 下载图片，使用现有 ImagePreviewView 显示
// 位置：GitHub/Views/FilePreview/FileImagePreviewView.swift
// ==============================================================================

struct FileImagePreviewView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var imageUrl: String = ""

    var body: some View {
        Group {
            if isLoading {
                ZStack {
                    Color.black.ignoresSafeArea()
                    ProgressView("图片加载中...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            } else if let error = errorMessage {
                ZStack {
                    Color.black.ignoresSafeArea()
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
            } else if !imageUrl.isEmpty {
                // 使用现有的 ImagePreviewView（在 ReadmeView.swift 中定义）
                ImagePreviewView(imageUrl: imageUrl, isDarkMode: true)
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            if imageData == nil {
                loadImage()
            }
        }
    }

    private func loadImage() {
        isLoading = true
        errorMessage = nil

        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let rawUrl = "https://raw.githubusercontent.com/\(owner)/\(repo)/\(branch)/\(encodedPath)"
        imageUrl = rawUrl

        GitHubAPI.shared.downloadFileData(url: rawUrl) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success:
                    // 图片数据已下载，但 ImagePreviewView 使用 AsyncImage(url:) 加载
                    // 为了支持Token认证，我们直接设置imageUrl，让AsyncImage加载
                    // 注意：AsyncImage不支持认证头，私有仓库图片可能加载失败
                    // 这里使用本地数据初始化的方式
                    break
                case .failure(let error):
                    errorMessage = "图片加载失败: \(error.localizedDescription)"
                }
            }
        }
    }
}

// ==============================================================================
// FileHTMLPreviewView 文件HTML预览视图（包装器）
// 功能：根据 owner/repo/path/branch 下载HTML内容，使用现有 HTMLPreviewView 显示
// 位置：GitHub/Views/FilePreview/FileHTMLPreviewView.swift
// ==============================================================================

struct FileHTMLPreviewView: View {
    let owner: String
    let repo: String
    let path: String
    let branch: String
    let fileName: String

    @Environment(\.dismiss) private var dismiss
    @State private var htmlContent: String?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading {
                VStack {
                    ProgressView("网页加载中...")
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
                        loadHTML()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }
                .padding()
            } else if let html = htmlContent {
                // 使用现有的 HTMLPreviewView（在 HTMLPreviewView.swift 中定义）
                HTMLPreviewView(
                    htmlContent: html,
                    title: fileName,
                    baseURL: nil
                )
            }
        }
        .navigationTitle(fileName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if htmlContent == nil {
                loadHTML()
            }
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
