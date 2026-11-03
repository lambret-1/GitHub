import Foundation
import SwiftUI
import Combine

class AppState: ObservableObject {
    static let shared = AppState()
    static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
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
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")

        // UI 测试使用固定的未登录状态，避免读取 Keychain、恢复账号或触发网络请求。
        guard !Self.isUITesting else { return }

        checkLoginStatus()

        // 监听AccountManager的currentAccount变化，账号切换时自动加载新用户信息
        accountCancellable = AccountManager.shared.$currentAccount
            .receive(on: DispatchQueue.main)
            .sink { [weak self] account in
                guard let self, account != nil else { return }
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
            // Token 存在但账号信息丢失时，从网络恢复账号。
            if AccountManager.shared.currentAccount == nil {
                loadUserInfo { user in
                    guard let user else { return }
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

        GitHubAPI.shared.getUserInfo(token: token) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                switch result {
                case .success(let user):
                    self?.currentUser = user
                    self?.isLoggedIn = true
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
                    self?.isLoggedIn = TokenKeychain.shared.hasToken
                    self?.errorMessage = error.localizedDescription
                    completion(false, error.localizedDescription)
                }
            }
        }
    }

    func logout() {
        if let currentAccount = AccountManager.shared.currentAccount {
            AccountManager.shared.deleteAccount(currentAccount)
        }
        TokenKeychain.shared.deleteToken()
        currentUser = nil
        isLoggedIn = false
    }

    func loadUserInfo(completion: ((GitHubUser?) -> Void)? = nil) {
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
        if !force,
           let laterTimestamp = UserDefaults.standard.object(forKey: laterReminderKey) as? TimeInterval {
            let currentTime = Date().timeIntervalSince1970
            if currentTime - laterTimestamp < 60 * 60 {
                return
            }
        }

        AppVersion.checkForUpdates { [weak self] result in
            guard let self else { return }
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
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: laterReminderKey)
    }

    /// 立即下载更新
    func downloadUpdateNow() {
        guard let release = latestRelease else { return }
        showUpdateAlert = false
        isDownloadingUpdate = true
        updateDownloadProgress = 0

        guard let asset = release.assets.first(where: { $0.name.hasSuffix(".ipa") }) else {
            isDownloadingUpdate = false
            return
        }

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
                    // 下载失败时由界面状态结束下载覆盖层。
                }
            }
        }
    }
}
