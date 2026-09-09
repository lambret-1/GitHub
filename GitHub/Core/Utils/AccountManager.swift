import Foundation
import SwiftUI
import Combine

// ==============================================================================
// AccountManager 账号管理器
// 功能：管理多个GitHub账号，支持添加、删除、切换账号，使用UserDefaults持久化
// ==============================================================================

class AccountManager: ObservableObject {
    static let shared = AccountManager()

    @Published private(set) var accounts: [GitHubAccount] = []
    @Published private(set) var currentAccount: GitHubAccount?

    private let accountsKey = "github_accounts"
    private let currentAccountIdKey = "github_current_account_id"

    private init() {
        loadAccounts()
        loadCurrentAccount()
    }

    // MARK: - 账号管理

    /// 添加账号
    func addAccount(_ account: GitHubAccount) {
        // 检查是否已存在相同账号
        if !accounts.contains(where: { $0.id == account.id }) {
            accounts.append(account)
            saveAccounts()
        }
        // 如果是第一个账号，自动设为当前账号
        if currentAccount == nil {
            switchTo(account)
        }
    }

    /// 删除账号
    func deleteAccount(_ account: GitHubAccount) {
        accounts.removeAll { $0.id == account.id }
        saveAccounts()

        // 如果删除的是当前账号，切换到第一个账号
        if currentAccount?.id == account.id {
            if let firstAccount = accounts.first {
                switchTo(firstAccount)
            } else {
                currentAccount = nil
                saveCurrentAccountId(nil)
            }
        }
    }

    /// 切换到指定账号
    func switchTo(_ account: GitHubAccount) {
        currentAccount = account
        saveCurrentAccountId(account.id)

        // 更新TokenKeychain中的Token
        TokenKeychain.shared.saveToken(account.token)
    }

    /// 获取所有账号
    func getAllAccounts() -> [GitHubAccount] {
        return accounts
    }

    /// 检查账号是否已存在
    func hasAccount(withId id: String) -> Bool {
        return accounts.contains { $0.id == id }
    }

    // MARK: - 持久化

    private func saveAccounts() {
        if let encoded = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(encoded, forKey: accountsKey)
        }
    }

    private func loadAccounts() {
        if let data = UserDefaults.standard.data(forKey: accountsKey),
           let decoded = try? JSONDecoder().decode([GitHubAccount].self, from: data) {
            accounts = decoded
        }
    }

    private func saveCurrentAccountId(_ id: String?) {
        UserDefaults.standard.set(id, forKey: currentAccountIdKey)
    }

    private func loadCurrentAccount() {
        if let accountId = UserDefaults.standard.string(forKey: currentAccountIdKey),
           let account = accounts.first(where: { $0.id == accountId }) {
            currentAccount = account
        } else if let firstAccount = accounts.first {
            // 如果没有保存当前账号，自动使用第一个账号
            switchTo(firstAccount)
        }
    }
}
