import UIKit
import Social
import UniformTypeIdentifiers

// ==============================================================================
// ShareViewController 分享扩展主视图控制器
// 功能：接收系统分享的文件，暂存到App Group共享目录，通知主应用上传
// 位置：Share Extension入口
// 设计原则：轻量级处理，只做文件接收和暂存，上传逻辑交给主应用
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
        view.backgroundColor = .systemBackground
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        handleSharedFiles()
    }

    // MARK: - UI设置

    private func setupUI() {
        let indicatorView = UIActivityIndicatorView(style: .large)
        indicatorView.center = view.center
        indicatorView.startAnimating()
        view.addSubview(indicatorView)

        let label = UILabel()
        label.text = "正在处理文件..."
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.sizeToFit()
        label.center = CGPoint(x: view.center.x, y: view.center.y + 40)
        view.addSubview(label)
    }

    // MARK: - 处理分享的文件

    private func handleSharedFiles() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeWithError()
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
                self.completeWithError()
            } else {
                self.saveUploadMetadata(fileCount: savedFileURLs.count)
                self.completeWithSuccess(fileCount: savedFileURLs.count)
            }
        }
    }

    // MARK: - 文件保存

    private func saveFileToSharedDirectory(_ sourceURL: URL) -> URL? {
        do {
            // 确保待上传目录存在
            try FileManager.default.createDirectory(at: pendingUploadDirectory, withIntermediateDirectories: true, attributes: nil)

            // 生成唯一文件名，避免冲突
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

    // MARK: - 完成回调

    private func completeWithSuccess(fileCount: Int) {
        // 分享成功后直接打开主应用，不显示弹窗
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.openMainApp()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
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

    private func completeWithError() {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "分享失败",
                message: "无法识别该文件类型，请尝试其他文件",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "好的", style: .default) { _ in
                self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            })
            self?.present(alert, animated: true)
        }
    }
}
