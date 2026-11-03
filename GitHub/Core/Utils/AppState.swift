import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.environment["UI_TESTING"] == "1"
    }

    /// UI 测试专用的已登录入口，用于验证主界面导航，不加载真实账号或凭据。
    static var isUITestingAuthenticated: Bool {
        isUITesting && ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated")
    }
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: GitHubUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // 暗黑模式状态
    @Published var isDarkMode: Bool = false
    
    // 更新推送相关状态
    @Published var showUpdateAlert: Bool = false
    @Published var latestRelease: AppVersion.ReleaseInfo?
    @Published var isDownloadingUpdate: Bool = false
    @Published var updateDownloadProgress: Double = 0
    
    // AccountManager的cancellable，用于监听账号切换
    private var accountCancellable: AnyCancellable?
    
    // 稍后提醒的时间戳（UserDefaults键名）
    private let laterReminderKey = "laterReminderTimestamp"
    
    private init() {
        // UI 测试必须在读取任何持久化状态前退出初始化，避免真实账号和用户偏好污染测试。
        guard !Self.isUITesting else {
            isDarkMode = false
            isLoggedIn = Self.isUITestingAuthenticated
            if Self.isUITestingAuthenticated,
               ProcessInfo.processInfo.arguments.contains("-ui-testing-profile-fixtures") {
                currentUser = Self.uiTestingProfile
            }
            return
        }

        // 正常运行时读取用户的暗黑模式设置。
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        checkLoginStatus()

        // 监听AccountManager的currentAccount变化，账号切换时自动加载新用户信息
        accountCancellable = AccountManager.shared.$currentAccount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] account in
                guard self != nil, account != nil else { return }
                // 账号切换时，自动加载新用户信息
                self?.loadUserInfo()
            }
    }
    
    /// 固定个人资料仅用于 UI 自动化，避免读取账号凭据或请求 GitHub API。
    private static let uiTestingProfile = GitHubUser(
        id: 9001,
        login: "ui-tester",
        name: "UI Test User",
        avatarUrl: "",
        bio: "本地 UI 自动化测试账号",
        company: "Example Labs",
        location: "San Francisco",
        blog: "https://example.invalid",
        publicRepos: 12,
        followers: 34,
        following: 5,
        htmlUrl: "https://example.invalid/ui-tester",
        createdAt: nil
    )

    /// 切换暗黑模式
    func toggleDarkMode() {
        isDarkMode.toggle()
        guard !Self.isUITesting else { return }
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    func checkLoginStatus() {
        guard !Self.isUITesting else {
            isLoggedIn = false
            return
        }
        isLoggedIn = TokenKeychain.shared.hasToken
        if isLoggedIn {
            // 修复：Token 存在但 AccountManager 中账号信息丢失时，自动从网络恢复账号
            if AccountManager.shared.currentAccount == nil {
                loadUserInfo { user in
                    guard let user = user else { return }
                    let account = GitHubAccount(
                        id: String(user.id),
                        username: user.login,
                        token: TokenKeychain.shared.getToken() ?? "",
                        avatarUrl: user.avatarUrl,
                        displayName: user.name
                    )
                    AccountManager.shared.addAccount(account)
                    AccountManager.shared.switchTo(account)
                }
            } else {
                loadUserInfo()
            }
        }
    }
    
    func login(token: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil

        // UI 测试禁止访问真实 GitHub API，确保测试 Token 不会触发网络或凭据写入。
        if Self.isUITesting {
            let message = "UI 测试模式已拦截真实登录请求"
            isLoading = false
            errorMessage = message
            completion(false, message)
            return
        }

        // 使用候选 Token 独立验证，不覆盖当前已登录账号的凭据
        GitHubAPI.shared.getUserInfo(token: token) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.isLoggedIn = true

                    // 将账号添加到AccountManager
                    let account = GitHubAccount(
                        id: String(user.id),
                        username: user.login,
                        token: token,
                        avatarUrl: user.avatarUrl,
                        displayName: user.name
                    )
                    AccountManager.shared.addAccount(account)
                    AccountManager.shared.switchTo(account)

                    completion(true, nil)
                case .failure(let error):
                    // 验证失败时保留原有账号与 Token，避免错误输入导致当前会话丢失
                    self?.isLoggedIn = TokenKeychain.shared.hasToken
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func logout() {
        if Self.isUITesting {
            currentUser = nil
            isLoggedIn = false
            return
        }

        // 从AccountManager中删除当前账号
        if let currentAccount = AccountManager.shared.currentAccount {
            AccountManager.shared.deleteAccount(currentAccount)
        }

        TokenKeychain.shared.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }
    
    func loadUserInfo(completion: ((GitHubUser?) -> Void)? = nil) {
        guard !Self.isUITesting else {
            completion?(nil)
            return
        }
        GitHubAPI.shared.getUserInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    completion?(user)
                case .failure:
                    completion?(nil)
                }
            }
        }
    }
    
    // MARK: - 更新推送功能
    
    /// 检查更新并推送通知
    /// - Parameter force: 是否强制检查（忽略稍后提醒）
    func checkForUpdatesAndNotify(force: Bool = false) {
        guard !Self.isUITesting else { return }

        // 如果不是强制检查，检查是否在稍后提醒时间内
        if !force {
            if let laterTimestamp = UserDefaults.standard.object(forKey: laterReminderKey) as? TimeInterval {
                let currentTime = Date().timeIntervalSince1970
                // 稍后提醒有效期为1小时
                if currentTime - laterTimestamp < 60 * 60 {
                    return
                }
            }
        }
        
        AppVersion.checkForUpdates { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if case .updateAvailable(let release) = result {
                    self.latestRelease = release
                    self.showUpdateAlert = true
                }
            }
        }
    }
    
    /// 稍后提醒更新
    func remindLater() {
        showUpdateAlert = false
        guard !Self.isUITesting else { return }
        // 记录当前时间戳，1小时内不再提醒（应用启动时强制检查会忽略此限制）
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: laterReminderKey)
    }
    
    /// 立即下载更新
    func downloadUpdateNow() {
        guard !Self.isUITesting, let release = latestRelease else { return }
        showUpdateAlert = false
        isDownloadingUpdate = true
        updateDownloadProgress = 0
        
        // 找到IPA文件的下载链接
        let ipaAsset = release.assets.first { $0.name.hasSuffix(".ipa") }
        guard let asset = ipaAsset else {
            isDownloadingUpdate = false
            return
        }
        
        // 下载更新并自动弹出分享面板
        // 使用API端点URL（url字段），支持私有仓库，需要认证头
        // API端点会返回302重定向到实际下载地址，URLSession自动跟随
        FileDownloadManager.shared.downloadAndShare(
            from: asset.url,
            fileName: asset.name,
            progress: { [weak self] progress in
                DispatchQueue.main.async {
                    self?.updateDownloadProgress = progress
                }
            }
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isDownloadingUpdate = false
                if case .failure = result {
                    // 下载失败，可以在这里添加错误处理
                }
            }
        }
    }
}
