import Foundation

// ==============================================================================
// ShareFileManager 分享文件管理器
// 功能：检测从Share Extension传递过来的待上传文件，提供文件列表和清理功能
// 位置：主应用端，处理分享扩展接收的文件
// 设计原则：单例模式，统一管理共享目录文件，与主应用上传逻辑解耦
// ==============================================================================

class ShareFileManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = ShareFileManager()

    private init() {}

    // MARK: - App Group配置

    /// App Group标识（必须与Share Extension一致）
    private let appGroupIdentifier = "group.com.github.client"

    /// 共享目录下的待上传文件夹
    private var pendingUploadDirectory: URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        return containerURL?.appendingPathComponent("PendingUploads", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    // MARK: - 发布属性

    /// 待上传文件列表
    @Published var pendingFiles: [PendingFile] = []

    /// 是否有待上传文件
    @Published var hasPendingFiles: Bool = false

    // MARK: - 数据模型

    struct PendingFile: Identifiable {
        let id = UUID()
        let fileURL: URL
        let originalName: String
        let fileSize: Int64
        let receivedDate: Date
    }

    // MARK: - 公共方法

    /// 扫描待上传目录，加载文件列表
    func scanPendingFiles() {
        do {
            // 确保目录存在
            try FileManager.default.createDirectory(at: pendingUploadDirectory, withIntermediateDirectories: true, attributes: nil)

            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: pendingUploadDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
                options: [.skipsHiddenFiles]
            )

            var files: [PendingFile] = []
            for url in fileURLs {
                // 跳过元数据文件
                guard url.lastPathComponent != "upload_metadata.json" else { continue }

                let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                let fileSize = Int64(resources.fileSize ?? 0)
                let creationDate = resources.creationDate ?? Date()

                // 从文件名中提取原始文件名（格式：timestamp_originalName）
                let originalName = extractOriginalName(from: url.lastPathComponent)

                files.append(PendingFile(
                    fileURL: url,
                    originalName: originalName,
                    fileSize: fileSize,
                    receivedDate: creationDate
                ))
            }

            // 按接收时间排序，最新的在前面
            files.sort { $0.receivedDate > $1.receivedDate }

            DispatchQueue.main.async {
                self.pendingFiles = files
                self.hasPendingFiles = !files.isEmpty
            }
        } catch {
            print("扫描待上传文件失败: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.pendingFiles = []
                self.hasPendingFiles = false
            }
        }
    }

    /// 删除指定的待上传文件
    func removeFile(_ file: PendingFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            scanPendingFiles()
        } catch {
            print("删除文件失败: \(error.localizedDescription)")
        }
    }

    /// 清空所有待上传文件
    func clearAllPendingFiles() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: pendingUploadDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for url in fileURLs {
                try FileManager.default.removeItem(at: url)
            }
            scanPendingFiles()
        } catch {
            print("清空待上传文件失败: \(error.localizedDescription)")
        }
    }

    /// 格式化文件大小
    func formattedFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    // MARK: - 私有方法

    /// 从带时间戳的文件名中提取原始文件名
    private func extractOriginalName(from fileName: String) -> String {
        // 格式：timestamp_originalName
        if let underscoreRange = fileName.range(of: "_") {
            let originalName = String(fileName[underscoreRange.upperBound...])
            return originalName
        }
        return fileName
    }
}
