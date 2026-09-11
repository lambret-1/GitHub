import Foundation

// ==============================================================================
// LastCommitCache 文件最后编辑时间缓存
// 功能：缓存文件最后提交信息，减少API调用，缓存保留1天自动清理
// ==============================================================================

class LastCommitCache {
    static let shared = LastCommitCache()

    private let cacheDirectory: URL
    private let cacheDuration: TimeInterval = 5 * 60 // 5分钟，确保时间显示与官方一致

    private init() {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        cacheDirectory = paths[0].appendingPathComponent("LastCommitCache", isDirectory: true)

        // 创建缓存目录
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        // 启动时清理过期缓存
        cleanupExpiredCache()
    }

    // MARK: - 缓存键

    private func cacheKey(owner: String, repo: String, path: String, branch: String) -> String {
        return "\(owner)_\(repo)_\(branch)_\(path)".replacingOccurrences(of: "/", with: "_")
    }

    private func cacheFileURL(for key: String) -> URL {
        return cacheDirectory.appendingPathComponent("\(key).json")
    }

    // MARK: - 读取缓存

    func getLastCommit(owner: String, repo: String, path: String, branch: String) -> Commit? {
        let key = cacheKey(owner: owner, repo: repo, path: path, branch: branch)
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

        // 读取缓存
        guard let data = try? Data(contentsOf: fileURL),
              let commit = try? JSONDecoder().decode(Commit.self, from: data) else {
            return nil
        }

        return commit
    }

    // MARK: - 写入缓存

    func setLastCommit(_ commit: Commit, owner: String, repo: String, path: String, branch: String) {
        let key = cacheKey(owner: owner, repo: repo, path: path, branch: branch)
        let fileURL = cacheFileURL(for: key)

        guard let data = try? JSONEncoder().encode(commit) else {
            return
        }

        try? data.write(to: fileURL, options: .atomic)
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

    // MARK: - 清空所有缓存

    func clearAllCache() {
        try? FileManager.default.removeItem(at: cacheDirectory)
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - 清除指定仓库和分支的缓存（用于下拉刷新）

    func clearCacheForRepo(owner: String, repo: String, branch: String) {
        DispatchQueue.global(qos: .background).async {
            guard let fileURLs = try? FileManager.default.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: []) else {
                return
            }

            let prefix = "\(owner)_\(repo)_\(branch)_"
            for fileURL in fileURLs {
                if fileURL.lastPathComponent.hasPrefix(prefix) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
    }
}
