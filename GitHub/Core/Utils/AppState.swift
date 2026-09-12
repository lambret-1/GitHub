import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    
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
        // 从UserDefaults读取暗黑模式设置
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        checkLoginStatus()
        
        // 监听AccountManager的currentAccount变化，账号切换时自动加载新用户信息
        accountCancellable = AccountManager.shared.$currentAccount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] account in
                guard let self = self, let account = account else { return }
                // 账号切换时，自动加载新用户信息
                self.loadUserInfo()
            }
    }
    
    /// 切换暗黑模式
    func toggleDarkMode() {
        isDarkMode.toggle()
        UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
    }
    
    func checkLoginStatus() {
        isLoggedIn = TokenKeychain.shared.hasToken
        if isLoggedIn {
            loadUserInfo()
        }
    }
    
    func login(token: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        errorMessage = nil

        // 先临时保存token用于验证
        TokenKeychain.shared.saveToken(token)

        GitHubAPI.shared.getUserInfo { [weak self] result in
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
                    // 验证失败，删除token
                    TokenKeychain.shared.deleteToken()
                    self?.isLoggedIn = false
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func logout() {
        // 从AccountManager中删除当前账号
        if let currentAccount = AccountManager.shared.currentAccount {
            AccountManager.shared.deleteAccount(currentAccount)
        }

        TokenKeychain.shared.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }
    
    func loadUserInfo() {
        GitHubAPI.shared.getUserInfo { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let user):
                    self?.currentUser = user
                case .failure:
                    break
                }
            }
        }
    }
    
    // MARK: - 更新推送功能
    
    /// 检查更新并推送通知
    /// - Parameter force: 是否强制检查（忽略稍后提醒）
    func checkForUpdatesAndNotify(force: Bool = false) {
        // 如果不是强制检查，检查是否在稍后提醒时间内
        if !force {
            if let laterTimestamp = UserDefaults.standard.object(forKey: laterReminderKey) as? TimeInterval {
                let currentTime = Date().timeIntervalSince1970
                // 稍后提醒有效期为24小时
                if currentTime - laterTimestamp < 24 * 60 * 60 {
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
        // 记录当前时间戳，24小时内不再提醒
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: laterReminderKey)
    }
    
    /// 立即下载更新
    func downloadUpdateNow() {
        guard let release = latestRelease else { return }
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
        // 使用浏览器下载URL（browser_download_url），公开访问，URLSession自动处理重定向
        // 不使用镜像加速，因为GitHub Releases的下载URL涉及重定向，镜像无法正确代理
        FileDownloadManager.shared.downloadAndShare(
            from: asset.browserDownloadUrl,
            fileName: asset.name,
            useMirror: false,
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
