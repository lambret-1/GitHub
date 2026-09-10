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
