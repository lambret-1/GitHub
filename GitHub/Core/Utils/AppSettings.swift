import Foundation
import Combine

// MARK: - 应用设置管理器

/// 应用设置管理器，用于保存和读取用户设置
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // 设置键名
    private enum Keys {
        static let useMirrorAcceleration = "useMirrorAcceleration"
        static let customMirrorURL = "customMirrorURL"
        static let selectedMirrorIndex = "selectedMirrorIndex"
    }

    // 镜像加速相关设置
    @Published var useMirrorAcceleration: Bool {
        didSet {
            defaults.set(useMirrorAcceleration, forKey: Keys.useMirrorAcceleration)
            // 发送设置变更通知
            NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
        }
    }

    var customMirrorURL: String? {
        didSet {
            defaults.set(customMirrorURL, forKey: Keys.customMirrorURL)
        }
    }

    // 用户选择的预设镜像索引（1=ghproxy, 2=gh-proxy, 3=kkgithub）
    // 0=官方API（未开启镜像加速时使用）
    var selectedMirrorIndex: Int {
        didSet {
            defaults.set(selectedMirrorIndex, forKey: Keys.selectedMirrorIndex)
            // 发送设置变更通知
            NotificationCenter.default.post(name: .appSettingsDidChange, object: nil)
        }
    }

    // 预设的镜像地址列表
    // 注意：这些公共镜像站主要用于下载热门开源项目的Release文件
    // 它们只镜像了部分热门项目，不一定包含所有项目
    // 如果需要代理所有GitHub请求，请使用自定义镜像（如gh-proxy.com类型的代理）
    let presetMirrors: [MirrorOption] = [
        MirrorOption(name: "官方 API", url: "https://api.github.com", isOfficial: true),
        MirrorOption(name: "清华大学镜像", url: "https://mirrors.tuna.tsinghua.edu.cn/github-release", isOfficial: false),
        MirrorOption(name: "中科大镜像", url: "https://mirrors.ustc.edu.cn/github-release", isOfficial: false),
        MirrorOption(name: "华为云镜像", url: "https://mirrors.huaweicloud.com/repo", isOfficial: false),
        MirrorOption(name: "阿里云镜像", url: "https://developer.aliyun.com/mirror", isOfficial: false)
    ]

    // 当前选中的镜像
    var currentMirror: MirrorOption {
        if useMirrorAcceleration {
            // 如果有自定义镜像URL且不是预设镜像，使用自定义的
            if let customURL = customMirrorURL, !customURL.isEmpty {
                // 检查是否是预设镜像
                if let index = presetMirrors.firstIndex(where: { $0.url == customURL }) {
                    return presetMirrors[index]
                }
                return MirrorOption(name: "自定义镜像", url: customURL, isOfficial: false)
            }
            // 否则使用用户选择的预设镜像
            let index = max(1, min(selectedMirrorIndex, presetMirrors.count - 1))
            return presetMirrors[index]
        } else {
            // 使用官方 API
            return presetMirrors[0]
        }
    }

    // 当前 API 基础 URL
    var currentBaseURL: String {
        currentMirror.url
    }

    // MARK: - URL 镜像转换

    /// 将 GitHub 相关 URL 转换为镜像 URL
    /// - Parameter url: 原始 GitHub URL
    /// - Returns: 转换后的镜像 URL，如果未开启镜像加速则返回原始 URL
    func convertURL(_ url: String) -> String {
        // 未开启镜像加速，直接返回原始 URL
        guard useMirrorAcceleration else { return url }

        let mirror = currentMirror

        // 判断是否是公共镜像站（清华大学、中科大、华为云、阿里云）
        let isPublicMirror = mirror.url.contains("mirrors.tuna.tsinghua.edu.cn") ||
                             mirror.url.contains("mirrors.ustc.edu.cn") ||
                             mirror.url.contains("mirrors.huaweicloud.com") ||
                             mirror.url.contains("developer.aliyun.com")

        if isPublicMirror {
            // 公共镜像站只支持 Release 下载
            // 对于 raw 文件、HTML 预览等，直接返回原始 URL（使用官方服务器）
            if isReleaseDownloadURL(url) {
                return convertReleaseURLToPublicMirror(url: url, mirrorURL: mirror.url)
            }
            return url
        }

        // 自定义镜像：尝试使用代理前缀方式
        // 代理型镜像（如 gh-proxy.com）可以代理所有 GitHub 请求
        if let customURL = customMirrorURL, !customURL.isEmpty {
            return convertWithProxyPrefix(url: url, mirrorURL: customURL)
        }

        // 其他情况，直接返回原始 URL
        return url
    }

    /// 判断是否是 Release 下载 URL
    private func isReleaseDownloadURL(_ url: String) -> Bool {
        // Release 下载 URL 格式：https://github.com/owner/repo/releases/download/version/file
        return url.contains("github.com") && url.contains("/releases/download/")
    }

    /// 将 Release 下载 URL 转换为公共镜像站 URL
    private func convertReleaseURLToPublicMirror(url: String, mirrorURL: String) -> String {
        // 原始 URL 格式：https://github.com/owner/repo/releases/download/version/file.ipa
        // 目标 URL 格式：https://mirrors.tuna.tsinghua.edu.cn/github-release/owner/repo/version/file.ipa

        // 提取 owner/repo/version/file 部分
        guard let range = url.range(of: "github.com/") else { return url }
        let pathPart = String(url[range.upperBound...])

        // pathPart 格式：owner/repo/releases/download/version/file.ipa
        // 需要转换为：owner/repo/version/file.ipa
        let components = pathPart.components(separatedBy: "/")
        guard components.count >= 6 else { return url }

        let owner = components[0]
        let repo = components[1]
        // components[2] = "releases"
        // components[3] = "download"
        let version = components[4]
        let fileName = components[5...].joined(separator: "/")

        // 构建镜像 URL
        let mirrorBase = mirrorURL.hasSuffix("/") ? String(mirrorURL.dropLast()) : mirrorURL
        return "\(mirrorBase)/\(owner)/\(repo)/\(version)/\(fileName)"
    }

    /// 使用代理前缀方式转换 URL
    private func convertWithProxyPrefix(url: String, mirrorURL: String) -> String {
        // 从镜像 URL 中提取代理前缀（去掉 /https://api.github.com 部分）
        let proxyPrefix: String
        if let range = mirrorURL.range(of: "/https://") {
            proxyPrefix = String(mirrorURL[..<range.lowerBound])
        } else if let range = mirrorURL.range(of: "/http://") {
            proxyPrefix = String(mirrorURL[..<range.lowerBound])
        } else {
            // 如果镜像 URL 不包含 /https://，则整个 URL 作为代理前缀
            proxyPrefix = mirrorURL.hasSuffix("/") ? String(mirrorURL.dropLast()) : mirrorURL
        }

        // 只转换 GitHub 相关域名
        if url.contains("github.com") || url.contains("githubusercontent.com") {
            return "\(proxyPrefix)/\(url)"
        }

        return url
    }

    /// 转换文件下载 URL（raw.githubusercontent.com）
    func convertDownloadURL(_ url: String) -> String {
        convertURL(url)
    }

    /// 转换头像 URL
    func convertAvatarURL(_ url: String) -> String {
        // 头像域名比较特殊，很多镜像不支持头像代理
        // 而且头像文件通常较小，直接从官方加载即可
        // 这里不进行镜像转换，避免出现"未找到主机名"错误
        return url
    }

    /// 转换网页 URL（用于在浏览器中打开）
    func convertWebURL(_ url: String) -> String {
        convertURL(url)
    }

    private init() {
        self.useMirrorAcceleration = defaults.bool(forKey: Keys.useMirrorAcceleration)
        self.customMirrorURL = defaults.string(forKey: Keys.customMirrorURL)
        // 默认选择 ghproxy 镜像（索引1）
        let savedIndex = defaults.integer(forKey: Keys.selectedMirrorIndex)
        self.selectedMirrorIndex = savedIndex > 0 ? savedIndex : 1
    }
}

// MARK: - 镜像选项

struct MirrorOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: String
    let isOfficial: Bool
}

// MARK: - 通知名称

extension Notification.Name {
    static let appSettingsDidChange = Notification.Name("appSettingsDidChange")
}
