import UIKit
import Social
import UniformTypeIdentifiers

// ==============================================================================
// ShareViewController 分享扩展主视图控制器
// 功能：接收系统分享的文件，暂存到App Group共享目录，自动跳转到主应用上传
// 位置：Share Extension入口
// 设计原则：无界面处理，直接保存文件并跳转，不显示任何加载界面或弹窗
// ==============================================================================

class ShareViewController: UIViewController {

    // App Group标识（必须与主应用一致）
    private let appGroupIdentifier = "group.com.github.client"

    // 共享目录下的待上传文件夹
    private var pendingUploadDirectory: URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        return containerURL?.appendingPathComponent("PendingUploads", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // 无界面处理：设置透明背景，不显示任何加载界面
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 页面出现后立即处理分享文件，不延迟
        handleSharedFiles()
    }

    // MARK: - 处理分享的文件

    private func handleSharedFiles() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithErrorAndDismiss()
            return
        }

        // 每次分享前清空待上传目录，确保只显示当前分享的文件（避免旧文件累积）
        clearPendingUploadDirectory()

        var savedFileURLs: [URL] = []
        let group = DispatchGroup()

        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                // 支持所有文件类型（TRUEPREDICATE已激活所有类型）
                // 优先尝试data类型（通用文件），其次text类型
                let supportedTypes: [UTType] = [
                    .data, .text, .plainText,
                    .image, .png, .jpeg, .gif,
                    .pdf, .zip, .json, .xml,
                    .sourceCode, .swiftSource, .cSource, .objectiveCSource,
                    .pythonScript, .javaScript, .html
                ]

                for type in supportedTypes {
                    if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                        group.enter()
                        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { [weak self] url, error in
                            defer { group.leave() }
                            guard let self = self, let fileURL = url else { return }
                            if let savedURL = self.saveFileToSharedDirectory(fileURL) {
                                savedFileURLs.append(savedURL)
                            }
                        }
                        break
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            if savedFileURLs.isEmpty {
                self.completeWithErrorAndDismiss()
            } else {
                self.saveUploadMetadata(fileCount: savedFileURLs.count)
                self.completeWithSuccessAndJump()
            }
        }
    }

    // MARK: - 清空待上传目录

    /// 清空待上传目录，确保每次分享只显示当前分享的文件
    private func clearPendingUploadDirectory() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: pendingUploadDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            for url in fileURLs {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // 目录不存在或清空失败，忽略错误（后续会创建目录）
        }
    }

    // MARK: - 文件保存

    private func saveFileToSharedDirectory(_ sourceURL: URL) -> URL? {
        do {
            // 确保待上传目录存在
            try FileManager.default.createDirectory(at: pendingUploadDirectory, withIntermediateDirectories: true, attributes: nil)

            // 生成唯一文件名，避免冲突（使用时间戳+原始文件名）
            let timestamp = Int(Date().timeIntervalSince1970)
            let originalName = sourceURL.lastPathComponent
            let uniqueName = "\(timestamp)_\(originalName)"
            let destinationURL = pendingUploadDirectory.appendingPathComponent(uniqueName)

            // 复制文件到共享目录
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("保存文件失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 元数据保存

    private func saveUploadMetadata(fileCount: Int) {
        let metadata: [String: Any] = [
            "fileCount": fileCount,
            "timestamp": Date().timeIntervalSince1970,
            "source": "ShareExtension"
        ]
        let metadataURL = pendingUploadDirectory.appendingPathComponent("upload_metadata.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: metadataURL)
        } catch {
            print("保存元数据失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 完成回调（成功：直接跳转主应用）

    private func completeWithSuccessAndJump() {
        // 分享成功后直接打开主应用，不显示任何弹窗
        openMainApp()
        // 延迟一下再关闭分享扩展，确保主应用能被打开
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - 完成回调（失败：直接关闭，不显示弹窗）

    private func completeWithErrorAndDismiss() {
        // 失败时直接关闭分享扩展，不显示错误弹窗（避免打扰用户）
        DispatchQueue.main.async { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }

    // MARK: - 打开主应用

    /// 通过Responder Chain获取UIApplication实例，使用URL Scheme打开主应用
    /// Share Extension中不能直接访问UIApplication.shared，需要通过Responder Chain获取
    private func openMainApp() {
        guard let url = URL(string: "githubclient://share") else { return }
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                application.open(url)
                break
            }
            responder = currentResponder.next
        }
    }
}
