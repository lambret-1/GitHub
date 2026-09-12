import SwiftUI
import UIKit

// ==============================================================================
// CachedImageView 带缓存的图片视图
// 功能：使用ImageCache加载和缓存图片，支持内存缓存和磁盘缓存
// 优势：减少网络请求，提升加载速度，缓存保留1天自动清理
// ==============================================================================

struct CachedImageView: View {
    let urlString: String
    let placeholder: Image
    let contentMode: ContentMode

    @State private var image: UIImage?
    @State private var isLoading: Bool = false

    init(urlString: String, placeholder: Image = Image(systemName: "person.circle.fill"), contentMode: ContentMode = .fill) {
        self.urlString = urlString
        self.placeholder = placeholder
        self.contentMode = contentMode
    }

    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            loadImage()
        }
        .onChange(of: urlString) { _ in
            image = nil
            loadImage()
        }
    }

    private func loadImage() {
        guard !urlString.isEmpty else { return }

        // 先检查缓存
        if let cachedImage = ImageCache.shared.getImage(for: urlString) {
            image = cachedImage
            return
        }

        isLoading = true

        // 下载并缓存图片
        ImageCache.shared.loadImage(from: urlString, cacheKey: urlString) { downloadedImage in
            DispatchQueue.main.async {
                isLoading = false
                if let downloadedImage = downloadedImage {
                    image = downloadedImage
                }
            }
        }
    }
}
