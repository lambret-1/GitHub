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
    
    private init() {
        // 从UserDefaults读取暗黑模式设置
        isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
        checkLoginStatus()
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
}
