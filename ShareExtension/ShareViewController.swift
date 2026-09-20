import UIKit
import Social
import UniformTypeIdentifiers

// ==============================================================================
// ShareViewController 分享扩展主视图控制器
// 功能：接收系统分享的文件，保存到独立文件夹（文件夹隔离），自动跳转到主应用上传
// 位置：Share Extension入口
// 设计原则：无界面处理，文件夹隔离（每次分享一个独立目录），避免文件互相污染
// ==============================================================================

class ShareViewController: UIViewController {

    // App Group标识（必须与主应用一致）
    private let appGroupIdentifier = "group.com.github.client"

    // 共享目录下的待上传根文件夹
    private var pendingUploadRootDirectory: URL {
        let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
        return containerURL?.appendingPathComponent("PendingUploads", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    // 本次分享的独立文件夹（使用UUID命名，实现文件夹隔离）
    private lazy var sessionDirectory: URL = {
        let sessionID = UUID().uuidString
        return pendingUploadRootDirectory.appendingPathComponent(sessionID, isDirectory: true)
    }()

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

        // 创建本次分享的独立文件夹（文件夹隔离）
        do {
            try FileManager.default.createDirectory(at: sessionDirectory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("创建会话目录失败: \(error.localizedDescription)")
            completeWithErrorAndDismiss()
            return
        }

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
                            if let savedURL = self.saveFileToSessionDirectory(fileURL) {
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
                // 失败时清理本次会话目录
                self.cleanupSessionDirectory()
                self.completeWithErrorAndDismiss()
            } else {
                self.saveUploadMetadata(fileCount: savedFileURLs.count)
                self.completeWithSuccessAndJump()
            }
        }
    }

    // MARK: - 文件保存（保存到本次会话的独立文件夹）

    private func saveFileToSessionDirectory(_ sourceURL: URL) -> URL? {
        do {
            // 直接使用原始文件名，不添加时间戳前缀（因为已经在独立文件夹中，不会冲突）
            let destinationURL = sessionDirectory.appendingPathComponent(sourceURL.lastPathComponent)

            // 如果文件已存在，添加数字后缀
            var finalURL = destinationURL
            var counter = 1
            while FileManager.default.fileExists(atPath: finalURL.path) {
                let fileName = sourceURL.deletingPathExtension().lastPathComponent
                let fileExtension = sourceURL.pathExtension
                let newName = "\(fileName)_\(counter).\(fileExtension)"
                finalURL = sessionDirectory.appendingPathComponent(newName)
                counter += 1
            }

            // 复制文件到会话目录
            try FileManager.default.copyItem(at: sourceURL, to: finalURL)
            return finalURL
        } catch {
            print("保存文件失败: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - 元数据保存（保存到本次会话目录）

    private func saveUploadMetadata(fileCount: Int) {
        let metadata: [String: Any] = [
            "fileCount": fileCount,
            "timestamp": Date().timeIntervalSince1970,
            "source": "ShareExtension",
            "sessionID": sessionDirectory.lastPathComponent
        ]
        let metadataURL = sessionDirectory.appendingPathComponent("upload_metadata.json")
        do {
            let data = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try data.write(to: metadataURL)
        } catch {
            print("保存元数据失败: \(error.localizedDescription)")
        }
    }

    // MARK: - 清理本次会话目录

    private func cleanupSessionDirectory() {
        do {
            try FileManager.default.removeItem(at: sessionDirectory)
        } catch {
            // 清理失败，忽略错误
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
