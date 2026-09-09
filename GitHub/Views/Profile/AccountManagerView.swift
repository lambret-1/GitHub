import SwiftUI

// ==============================================================================
// AccountManagerView 账号管理页面
// 功能：管理多个GitHub账号，支持添加、删除、切换账号
// ==============================================================================

struct AccountManagerView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var showAddAccount = false
    @State private var newToken = ""
    @State private var isVerifying = false
    @State private var verifyError: String?
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        List {
            Section("当前账号") {
                if let current = accountManager.currentAccount {
                    accountRow(account: current, isCurrent: true)
                } else {
                    Text("未登录")
                        .foregroundColor(.gray)
                }
            }

            Section("所有账号") {
                ForEach(accountManager.accounts) { account in
                    if account.id != accountManager.currentAccount?.id {
                        accountRow(account: account, isCurrent: false)
                    }
                }

                Button(action: {
                    showAddAccount = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.blue)
                        Text("添加新账号")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("账号管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert("添加账号", isPresented: $showAddAccount) {
            SecureField("请输入 GitHub Token", text: $newToken)
            Button("取消", role: .cancel) {
                newToken = ""
                verifyError = nil
            }
            Button("验证并添加") {
                verifyAndAddAccount()
            }
            .disabled(newToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)
        } message: {
            if let error = verifyError {
                Text(error)
                    .foregroundColor(.red)
            } else {
                Text("请输入具有 repo 权限的 GitHub Personal Access Token")
            }
        }
        .overlay {
            if isVerifying {
                ProgressView("正在验证 Token...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }

    // MARK: - 账号行

    private func accountRow(account: GitHubAccount, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            // 头像
            AsyncImage(url: URL(string: account.avatarUrl ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            // 账号信息
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName ?? account.username)
                    .font(.headline)
                Text("@\(account.username)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 当前账号标记或切换按钮
            if isCurrent {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button(action: {
                    accountManager.switchTo(account)
                }) {
                    Text("切换")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            if !isCurrent {
                Button(role: .destructive, action: {
                    accountManager.deleteAccount(account)
                }) {
                    Label("删除账号", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - 验证并添加账号

    private func verifyAndAddAccount() {
        let token = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }

        isVerifying = true
        verifyError = nil

        // 临时设置Token用于验证
        TokenKeychain.shared.saveToken(token)

        GitHubAPI.shared.getUserInfo { result in
            DispatchQueue.main.async {
                isVerifying = false
                switch result {
                case .success(let user):
                    // 创建账号
                    let account = GitHubAccount(
                        id: String(user.id),
                        username: user.login,
                        token: token,
                        avatarUrl: user.avatarUrl,
                        displayName: user.name
                    )

                    // 检查是否已存在
                    if AccountManager.shared.hasAccount(withId: account.id) {
                        verifyError = "该账号已添加"
                    } else {
                        AccountManager.shared.addAccount(account)
                        AccountManager.shared.switchTo(account)
                        showAddAccount = false
                        newToken = ""
                    }
                case .failure(let error):
                    verifyError = "Token 验证失败: \(error.localizedDescription)"
                    // 恢复原来的Token
                    if let current = AccountManager.shared.currentAccount {
                        TokenKeychain.shared.saveToken(current.token)
                    } else {
                        TokenKeychain.shared.deleteToken()
                    }
                }
            }
        }
    }
}
