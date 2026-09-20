import Foundation

// ==============================================================================
// ShareFileManager 分享文件管理器
// 功能：检测从Share Extension传递过来的待上传文件（文件夹隔离），提供文件列表和清理功能
// 位置：主应用端，处理分享扩展接收的文件
// 设计原则：单例模式，文件夹隔离（每次分享一个独立目录），上传完成后删除对应文件夹
// ==============================================================================

class ShareFileManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = ShareFileManager()

    private init() {}

    // MARK: - App Group配置

    /// App Group标识（必须与Share Extension一致）
    private let appGroupIdentifier = "group.com.github.client"

    /// 共享目录下的待上传根文件夹
    private var pendingUploadRootDirectory: URL {
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
        let fileName: String
        let fileSize: Int64
        let receivedDate: Date
        let sessionID: String  // 所属会话文件夹ID，用于上传完成后删除对应文件夹
    }

    // MARK: - 公共方法

    /// 扫描待上传根目录，加载所有会话文件夹中的文件
    func scanPendingFiles() {
        do {
            // 确保根目录存在
            try FileManager.default.createDirectory(at: pendingUploadRootDirectory, withIntermediateDirectories: true, attributes: nil)

            // 清理根目录中的旧文件（不在会话文件夹中的文件，兼容旧版本数据）
            let rootItems = try FileManager.default.contentsOfDirectory(
                at: pendingUploadRootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            for item in rootItems {
                let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey])
                // 如果不是目录（是旧版本的文件），则删除
                if resourceValues.isDirectory != true {
                    try FileManager.default.removeItem(at: item)
                }
            }

            // 获取所有会话文件夹（每个文件夹是一次分享会话）
            let sessionDirectories = try FileManager.default.contentsOfDirectory(
                at: pendingUploadRootDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                // 只处理目录（会话文件夹）
                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                return isDirectory.boolValue
            }

            var files: [PendingFile] = []
            for sessionDir in sessionDirectories {
                let sessionID = sessionDir.lastPathComponent

                // 读取会话文件夹中的所有文件
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: sessionDir,
                    includingPropertiesForKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for url in fileURLs {
                    // 跳过元数据文件
                    guard url.lastPathComponent != "upload_metadata.json" else { continue }

                    let resources = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey])

                    // 跳过目录（只处理文件）
                    if resources.isDirectory == true { continue }

                    let fileSize = Int64(resources.fileSize ?? 0)
                    // 跳过0字节文件（无效文件）
                    guard fileSize > 0 else { continue }

                    let creationDate = resources.creationDate ?? Date()

                    files.append(PendingFile(
                        fileURL: url,
                        fileName: url.lastPathComponent,
                        fileSize: fileSize,
                        receivedDate: creationDate,
                        sessionID: sessionID
                    ))
                }

                // 检查会话文件夹是否已空（只有元数据文件或已空），如果已空则删除整个文件夹
                cleanupEmptySessionDirectory(sessionID: sessionID)
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

    /// 删除指定的待上传文件（如果该会话文件夹已空，则删除整个文件夹）
    func removeFile(_ file: PendingFile) {
        do {
            try FileManager.default.removeItem(at: file.fileURL)
            // 检查该会话文件夹是否已空，如果已空则删除整个文件夹
            cleanupEmptySessionDirectory(sessionID: file.sessionID)
            scanPendingFiles()
        } catch {
            print("删除文件失败: \(error.localizedDescription)")
        }
    }

    /// 清空所有待上传文件（删除所有会话文件夹）
    func clearAllPendingFiles() {
        do {
            let sessionDirectories = try FileManager.default.contentsOfDirectory(
                at: pendingUploadRootDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for dir in sessionDirectories {
                try FileManager.default.removeItem(at: dir)
            }
            scanPendingFiles()
        } catch {
            print("清空待上传文件失败: \(error.localizedDescription)")
        }
    }

    /// 上传完成后，删除指定会话文件夹（该次分享的所有文件都已处理）
    func removeSessionDirectory(sessionID: String) {
        let sessionDir = pendingUploadRootDirectory.appendingPathComponent(sessionID, isDirectory: true)
        do {
            try FileManager.default.removeItem(at: sessionDir)
            scanPendingFiles()
        } catch {
            print("删除会话目录失败: \(error.localizedDescription)")
        }
    }

    /// 检查并清理空的会话文件夹
    func cleanupEmptySessionDirectory(sessionID: String) {
        let sessionDir = pendingUploadRootDirectory.appendingPathComponent(sessionID, isDirectory: true)
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: sessionDir,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            // 如果文件夹中只有元数据文件或已空，则删除整个文件夹
            let actualFiles = files.filter { $0.lastPathComponent != "upload_metadata.json" }
            if actualFiles.isEmpty {
                try FileManager.default.removeItem(at: sessionDir)
            }
        } catch {
            // 文件夹不存在或清理失败，忽略错误
        }
    }

    /// 格式化文件大小
    func formattedFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
