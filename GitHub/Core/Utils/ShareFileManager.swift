import Foundation

// ==============================================================================
// ShareFileManager 分享文件管理器
// 功能：管理通过"打开方式"功能接收到的待上传文件（文件夹隔离），提供文件列表和清理功能
// 位置：主应用端，处理系统分享/打开方式接收的文件
// 设计原则：单例模式，文件夹隔离（每次接收一个独立目录），上传完成后删除对应文件夹
// ==============================================================================

class ShareFileManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = ShareFileManager()

    private init() {}

    // MARK: - 目录配置

    /// 待上传文件根目录（Documents/PendingUploads）
    private var pendingUploadRootDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("PendingUploads", isDirectory: true)
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

    /// 接收从"打开方式"功能传递过来的文件
    /// 将文件从系统Inbox目录移动到PendingUploads目录（文件夹隔离）
    /// - Parameter sourceURL: 系统传递过来的文件URL
    /// - Returns: 是否接收成功
    @discardableResult
    func receiveFile(from sourceURL: URL) -> Bool {
        do {
            // 创建本次接收的独立文件夹（文件夹隔离）
            let sessionID = UUID().uuidString
            let sessionDirectory = pendingUploadRootDirectory.appendingPathComponent(sessionID, isDirectory: true)
            try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true, attributes: nil)

            // 移动文件到会话目录
            let destinationURL = sessionDirectory.appendingPathComponent(sourceURL.lastPathComponent)

            // 如果目标文件已存在，先删除
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }

            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

            DebugLogger.share("✅ 文件接收成功: \(sourceURL.lastPathComponent) -> 会话: \(sessionID)")

            // 重新扫描文件列表
            scanPendingFiles()

            return true
        } catch {
            DebugLogger.share("❌ 文件接收失败: \(error.localizedDescription)")
            return false
        }
    }
        DebugLogger.share("=== scanPendingFiles 开始扫描 ===")
        DebugLogger.share("待上传目录: \(pendingUploadRootDirectory.path)")
        do {
            // 确保根目录存在
            try FileManager.default.createDirectory(at: pendingUploadRootDirectory, withIntermediateDirectories: true, attributes: nil)

            // 获取所有会话文件夹（每个文件夹是一次接收会话）
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

            // 同步更新@Published属性（必须同步，否则调用方立即检查hasPendingFiles时还是旧值false）
            // 此方法本来就在主线程调用，不需要DispatchQueue.main.async
            self.pendingFiles = files
            self.hasPendingFiles = !files.isEmpty
            DebugLogger.share("✅ 扫描完成，找到 \(files.count) 个文件")
            for file in files {
                DebugLogger.share("   - \(file.fileName) (\(file.fileSize)字节) 会话: \(file.sessionID)")
            }
        } catch {
            DebugLogger.share("❌ 扫描失败: \(error.localizedDescription)")
            // 同步更新失败状态
            self.pendingFiles = []
            self.hasPendingFiles = false
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
