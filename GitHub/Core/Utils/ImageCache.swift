import Foundation
import UIKit

// ==============================================================================
// ImageCache 图片缓存管理
// 功能：缓存下载的图片缩略图，减少网络请求，缓存保留1天自动清理
// 注意：缓存内容不包含任何token或敏感信息
// ==============================================================================

class ImageCache {
    static let shared = ImageCache()

    private let cacheDirectory: URL
    private let cacheDuration: TimeInterval = 24 * 60 * 60 // 1天
    private let memoryCache = NSCache<NSString, UIImage>()

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("ImageCache", isDirectory: true)

        // 创建缓存目录
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        // 启动时清理过期缓存
        cleanupExpiredCache()

        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clearMemoryCache),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 缓存键

    private func cacheKey(for url: String) -> String {
        // 使用URL的哈希值作为文件名，避免特殊字符问题
        return url.hashValue.description
    }

    private func cacheFileURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).png")
    }

    // MARK: - 读取缓存

    func getImage(for url: String) -> UIImage? {
        let key = cacheKey(for: url)

        // 先从内存缓存读取
        if let image = memoryCache.object(forKey: key as NSString) {
            return image
        }

        // 从磁盘缓存读取
        let fileURL = cacheFileURL(for: key)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        // 检查缓存是否过期
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }

        if Date().timeIntervalSince(modificationDate) > cacheDuration {
            // 缓存过期，删除
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }

        // 读取图片
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        // 存入内存缓存
        memoryCache.setObject(image, forKey: key as NSString)

        return image
    }

    // MARK: - 写入缓存

    func setImage(_ image: UIImage, for url: String) {
        let key = cacheKey(for: url)

        // 存入内存缓存
        memoryCache.setObject(image, forKey: key as NSString)

        // 存入磁盘缓存
        let fileURL = cacheFileURL(for: key)
        guard let data = image.pngData() else {
            return
        }

        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - 下载并缓存图片

    func loadImage(from urlString: String, completion: @escaping (UIImage?) -> Void) {
        loadImage(from: urlString, cacheKey: urlString, completion: completion)
    }

    /// 下载并缓存图片（支持自定义缓存键）
    /// - Parameters:
    ///   - urlString: 下载URL
    ///   - cacheKey: 缓存键（用于镜像加速场景，使用原始URL作为缓存键）
    ///   - completion: 完成回调
    func loadImage(from urlString: String, cacheKey: String, completion: @escaping (UIImage?) -> Void) {
        // 先检查缓存（使用自定义缓存键）
        if let cachedImage = getImage(for: cacheKey) {
            DispatchQueue.main.async {
                completion(cachedImage)
            }
            return
        }

        // 判断是否是GitHub相关URL，如果是则应用镜像加速转换
        let isGitHubURL = urlString.contains("github.com") || urlString.contains("githubusercontent.com")
        let convertedURL = isGitHubURL ? AppSettings.shared.convertAvatarURL(urlString) : urlString

        // 下载图片
        guard let url = URL(string: convertedURL) else {
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        // GitHub相关URL使用镜像专用URLSession（允许无效证书），其他URL使用普通URLSession
        let session = isGitHubURL ? URLSession.mirrorSession : URLSession.shared

        session.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }

            // 存入缓存（使用自定义缓存键）
            self.setImage(image, for: cacheKey)

            DispatchQueue.main.async {
                completion(image)
            }
        }.resume()
    }

    // MARK: - 清理过期缓存

    func cleanupExpiredCache() {
        DispatchQueue.global(qos: .background).async {
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey], options: []) else {
                return
            }

            for fileURL in fileURLs {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                      let modificationDate = attributes[.modificationDate] as? Date else {
                    continue
                }

                if Date().timeIntervalSince(modificationDate) > self.cacheDuration {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }

    // MARK: - 清空内存缓存

    @objc private func clearMemoryCache() {
        memoryCache.removeAllObjects()
    }

    // MARK: - 清空所有缓存

    func clearAllCache() {
        memoryCache.removeAllObjects()
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 缓存大小

    var cacheSize: Int64 {
        guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }

        var totalSize: Int64 = 0
        for fileURL in fileURLs {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
}
