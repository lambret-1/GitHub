import Foundation
import UIKit

// ==============================================================================
// FileDownloadManager 文件下载管理工具类
// 功能：下载GitHub文件、保存到本地临时目录、分享/导出文件
// ==============================================================================

class FileDownloadManager {
    static let shared = FileDownloadManager()

    private init() {}

    // MARK: - 下载文件

    /// 下载文件并保存到临时目录
    /// - Parameters:
    ///   - url: 文件下载URL
    ///   - fileName: 保存的文件名
    ///   - progress: 下载进度回调（0.0 ~ 1.0）
    ///   - completion: 完成回调，返回本地文件URL
    func downloadFile(
        from url: String,
        fileName: String,
        progress: ((Double) -> Void)? = nil,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        // 应用镜像加速转换
        let convertedURL = AppSettings.shared.convertDownloadURL(url)

        guard let urlObj = URL(string: convertedURL) else {
            completion(.failure(NSError(domain: "FileDownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的下载URL"])))
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)

        // 如果已存在同名文件，先删除
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config, delegate: DownloadDelegate(progress: progress, fileURL: fileURL, completion: completion), delegateQueue: .main)

        var request = URLRequest(url: urlObj)
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }

        let task = session.downloadTask(with: request)
        task.resume()
    }

    // MARK: - 分享文件

    /// 分享文件（使用UIActivityViewController）
    /// - Parameter fileURL: 本地文件URL
    func shareFile(at fileURL: URL, from viewController: UIViewController) {
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
    }

    /// 下载文件并自动弹出分享面板
    /// - Parameters:
    ///   - url: 文件下载URL
    ///   - fileName: 保存的文件名
    ///   - progress: 下载进度回调
    ///   - completion: 完成回调
    func downloadAndShare(
        from url: String,
        fileName: String,
        progress: ((Double) -> Void)? = nil,
        completion: ((Result<Void, Error>) -> Void)? = nil
    ) {
        downloadFile(from: url, fileName: fileName, progress: progress) { result in
            switch result {
            case .success(let fileURL):
                DispatchQueue.main.async {
                    if let topVC = Self.getTopViewController() {
                        self.shareFile(at: fileURL, from: topVC)
                        completion?(.success(()))
                    } else {
                        completion?(.failure(NSError(domain: "FileDownloadManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "无法获取当前视图控制器"])))
                    }
                }
            case .failure(let error):
                completion?(.failure(error))
            }
        }
    }

    /// 获取当前最顶层的视图控制器
    static func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topVC = window.rootViewController
        while let presentedVC = topVC?.presentedViewController {
            topVC = presentedVC
        }
        return topVC
    }

    // MARK: - 保存到文件App

    /// 保存文件到"文件"App（使用UIDocumentPickerViewController导出）
    /// - Parameter fileURL: 本地文件URL
    func exportToFilesApp(at fileURL: URL, from viewController: UIViewController) {
        let documentPicker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        documentPicker.delegate = ExportDelegate()
        viewController.present(documentPicker, animated: true)
    }

    // MARK: - 清理临时文件

    /// 清理下载的临时文件
    func cleanupTempFiles() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            for file in files {
                let fileURL = tempDir.appendingPathComponent(file)
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("清理临时文件失败: \(error)")
        }
    }

    // MARK: - 获取文件大小

    /// 获取本地文件大小（字节）
    func fileSize(at url: URL) -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int
        } catch {
            return nil
        }
    }

    /// 格式化文件大小
    func formattedFileSize(_ bytes: Int) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else if bytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(bytes) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - 下载任务代理

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let progress: ((Double) -> Void)?
    let fileURL: URL
    let completion: (Result<URL, Error>) -> Void

    init(progress: ((Double) -> Void)?, fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.progress = progress
        self.fileURL = fileURL
        self.completion = completion
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            // 移动下载的文件到目标位置
            try FileManager.default.moveItem(at: location, to: fileURL)
            DispatchQueue.main.async {
                self.completion(.success(self.fileURL))
            }
        } catch {
            DispatchQueue.main.async {
                self.completion(.failure(error))
            }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progressValue = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.progress?(progressValue)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.completion(.failure(error))
            }
        }
    }
}

// MARK: - 导出代理

private class ExportDelegate: NSObject, UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 文件导出成功
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 用户取消导出
    }
}
