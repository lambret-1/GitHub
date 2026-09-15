import SwiftUI

// MARK: - iOS14兼容的异步图片视图
// 替代iOS15+的AsyncImage，使用URLSession实现异步图片加载

struct iOS14AsyncImage<Content: View>: View {
    @State private var image: UIImage?
    @State private var isLoading = true

    private let url: URL?
    private let scale: CGFloat
    private let content: (AsyncImagePhase) -> Content

    init(
        url: URL?,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    var body: some View {
        content(phase)
            .onAppear(perform: loadImage)
    }

    private var phase: AsyncImagePhase {
        if let image = image {
            return .success(Image(uiImage: image))
        } else if isLoading {
            return .empty
        } else {
            return .failure(NSError(domain: "iOS14AsyncImage", code: -1, userInfo: nil))
        }
    }

    private func loadImage() {
        guard let url = url else {
            isLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                isLoading = false
                if let data = data, let loadedImage = UIImage(data: data, scale: scale) {
                    image = loadedImage
                }
            }
        }.resume()
    }
}

// MARK: - 便捷初始化方法

extension iOS14AsyncImage where Content == AnyView {
    init(url: URL?) {
        self.init(url: url) { phase in
            AnyView(
                Group {
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
        }
    }
}

// MARK: - 异步图片加载阶段（与iOS15+的AsyncImagePhase保持一致）

enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)

    var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
