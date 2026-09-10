import Foundation

// MARK: - 应用设置管理器

/// 应用设置管理器，用于保存和读取用户设置
class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // 设置键名
    private enum Keys {
        static let useMirrorAcceleration = "useMirrorAcceleration"
        static let customMirrorURL = "customMirrorURL"
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

    // 预设的镜像地址列表
    let presetMirrors: [MirrorOption] = [
        MirrorOption(name: "官方 API", url: "https://api.github.com", isOfficial: true),
        MirrorOption(name: "ghproxy 镜像", url: "https://mirror.ghproxy.com/https://api.github.com", isOfficial: false),
        MirrorOption(name: "gh-proxy 镜像", url: "https://gh-proxy.com/https://api.github.com", isOfficial: false),
        MirrorOption(name: "kkgithub 镜像", url: "https://api.kkgithub.com", isOfficial: false)
    ]

    // 当前选中的镜像
    var currentMirror: MirrorOption {
        if useMirrorAcceleration {
            // 如果有自定义镜像URL，使用自定义的
            if let customURL = customMirrorURL, !customURL.isEmpty {
                return MirrorOption(name: "自定义镜像", url: customURL, isOfficial: false)
            }
            // 否则使用第一个预设镜像（ghproxy）
            return presetMirrors[1]
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

        // 根据不同镜像类型使用不同的转换方式
        if mirror.url.contains("mirror.ghproxy.com") || mirror.url.contains("gh-proxy.com") {
            // ghproxy / gh-proxy 类型：镜像前缀 + 原始URL
            return convertWithProxyPrefix(url: url, mirrorURL: mirror.url)
        } else if mirror.url.contains("kkgithub.com") {
            // kkgithub 类型：域名替换
            return convertWithDomainReplacement(url: url)
        } else if let customURL = customMirrorURL, !customURL.isEmpty {
            // 自定义镜像：尝试使用代理前缀方式
            return convertWithProxyPrefix(url: url, mirrorURL: customURL)
        }

        // 其他情况，尝试通用代理前缀方式
        return convertWithProxyPrefix(url: url, mirrorURL: mirror.url)
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
            // 无法提取代理前缀，直接返回原始 URL
            return url
        }

        // 只转换 GitHub 相关域名
        if url.contains("github.com") || url.contains("githubusercontent.com") {
            return "\(proxyPrefix)/\(url)"
        }

        return url
    }

    /// 使用域名替换方式转换 URL（kkgithub 类型）
    private func convertWithDomainReplacement(url: String) -> String {
        var converted = url
        // 替换 API 域名
        converted = converted.replacingOccurrences(of: "api.github.com", with: "api.kkgithub.com")
        // 替换 raw 域名
        converted = converted.replacingOccurrences(of: "raw.githubusercontent.com", with: "raw.kkgithub.com")
        // 替换网页域名
        converted = converted.replacingOccurrences(of: "github.com", with: "kkgithub.com")
        // 替换头像域名（kkgithub 可能不支持头像，这里先尝试替换）
        converted = converted.replacingOccurrences(of: "avatars.githubusercontent.com", with: "avatars.kkgithub.com")
        return converted
    }

    /// 转换文件下载 URL（raw.githubusercontent.com）
    func convertDownloadURL(_ url: String) -> String {
        convertURL(url)
    }

    /// 转换头像 URL
    func convertAvatarURL(_ url: String) -> String {
        // 头像域名比较特殊，很多镜像不支持
        // 这里先尝试转换，如果失败则返回原始 URL
        let converted = convertURL(url)
        return converted
    }

    /// 转换网页 URL（用于在浏览器中打开）
    func convertWebURL(_ url: String) -> String {
        convertURL(url)
    }

    private init() {
        self.useMirrorAcceleration = defaults.bool(forKey: Keys.useMirrorAcceleration)
        self.customMirrorURL = defaults.string(forKey: Keys.customMirrorURL)
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
