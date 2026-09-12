import Foundation
import UIKit

// ==============================================================================
// FileDownloadManager 文件下载管理工具类
// 功能：下载GitHub文件、保存到本地临时目录、分享/导出文件
// ==============================================================================

class FileDownloadManager {
    static let shared = FileDownloadManager()

    private init() {}

    // MARK: - 下载文件夹路径

    /// 获取临时下载文件夹路径（tmp目录）
    /// - Returns: 临时下载文件夹URL
    func downloadDirectoryURL() -> URL {
        // 使用系统临时目录，下载完成后通过分享面板导出
        return FileManager.default.temporaryDirectory
    }

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
        guard let urlObj = URL(string: url) else {
            completion(.failure(NSError(domain: "FileDownloadManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的下载URL"])))
            return
        }

        // 保存到临时目录
        let downloadDir = downloadDirectoryURL()
        let fileURL = downloadDir.appendingPathComponent(fileName)

        // 如果已存在同名文件，先删除
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }

        let config = URLSessionConfiguration.default
        // 禁用缓存，确保每次都从服务器下载最新文件
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        let session = URLSession(configuration: config, delegate: DownloadDelegate(progress: progress, fileURL: fileURL, completion: completion), delegateQueue: .main)

        var request = URLRequest(url: urlObj)
        // 按照GitHub官方规范设置请求头
        // 1. Authorization: 使用Token认证，支持私有仓库
        // 2. Accept: application/octet-stream，告诉API返回文件内容而不是JSON
        // 3. User-Agent: GitHub要求所有API请求必须有User-Agent
        if let token = TokenKeychain.shared.getToken() {
            request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
        request.setValue("GitHub-iOS-Client", forHTTPHeaderField: "User-Agent")

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

    // MARK: - 清理下载文件

    /// 清理"下载"文件夹中的所有文件
    func cleanupDownloadFiles() {
        let downloadDir = downloadDirectoryURL()
        do {
            let files = try FileManager.default.contentsOfDirectory(atPath: downloadDir.path)
            for file in files {
                let fileURL = downloadDir.appendingPathComponent(file)
                try? FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("清理下载文件失败: \(error)")
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

private class DownloadDelegate: NSObject, URLSessionDownloadDelegate, URLSessionDelegate {
    let progress: ((Double) -> Void)?
    let fileURL: URL
    let completion: (Result<URL, Error>) -> Void

    init(progress: ((Double) -> Void)?, fileURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.progress = progress
        self.fileURL = fileURL
        self.completion = completion
    }

    // 处理SSL证书挑战，允许自签名证书
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
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

    // 处理HTTP重定向（GitHub Releases下载URL会302重定向到实际文件地址）
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // 允许重定向，使用新的请求继续下载
        completionHandler(request)
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
