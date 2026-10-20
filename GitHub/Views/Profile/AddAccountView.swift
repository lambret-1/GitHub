import SwiftUI

// ==============================================================================
// AddAccountView 添加账号页面
// 功能：输入GitHub Token，验证并添加新账号，使用sheet替代alert确保按钮正常显示
// Token输入框使用普通TextField，支持剪切板粘贴和第三方输入法
// ==============================================================================

struct AddAccountView: View {
    @State private var token = ""
    @State private var isVerifying = false
    @State private var verifyError: String?
    @State private var showToken = false
    var onSuccess: (GitHubAccount) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 提示信息
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                    Text("添加 GitHub 账号")
                        .font(.headline)
                    Text("请输入具有 repo 权限的 GitHub Personal Access Token")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .padding(.horizontal)

                Divider()

                // Token输入区域
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GitHub Token")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            // 使用普通TextField，支持剪切板粘贴和第三方输入法
                            if showToken {
                                TextField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .textContentType(.none)
                            } else {
                                SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }

                            // 显示/隐藏按钮
                            Button(action: {
                                showToken.toggle()
                            }) {
                                Image(systemName: showToken ? "eye.slash.fill" : "eye.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 30, height: 30)
                            }
                        }

                        // 粘贴按钮
                        Button(action: {
                            if let pasteboardString = UIPasteboard.general.string {
                                token = pasteboardString
                            }
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("从剪贴板粘贴")
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                    }

                    if let error = verifyError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)

                Spacer()

                // 底部按钮区域
                VStack(spacing: 12) {
                    Button(action: {
                        verifyAndAddAccount()
                    }) {
                        HStack {
                            if isVerifying {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                            }
                            Text(isVerifying ? "验证中..." : "验证并添加")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isVerifying)

                    Button(action: {
                        onCancel()
                    }) {
                        Text("取消")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(.systemGray6))
                            .foregroundColor(.primary)
                            .cornerRadius(10)
                    }
                    .disabled(isVerifying)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - 验证并添加账号

    private func verifyAndAddAccount() {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else { return }

        isVerifying = true
        verifyError = nil

        // 临时保存Token用于验证
        TokenKeychain.shared.saveToken(trimmedToken)

        GitHubAPI.shared.getUserInfo { result in
            DispatchQueue.main.async {
                isVerifying = false
                switch result {
                case .success(let user):
                    // 创建账号
                    let account = GitHubAccount(
                        id: String(user.id),
                        username: user.login,
                        token: trimmedToken,
                        avatarUrl: user.avatarUrl,
                        displayName: user.name
                    )

                    // 检查是否已存在
                    if AccountManager.shared.hasAccount(withId: account.id) {
                        verifyError = "该账号已添加"
                        // 恢复原来的Token
                        if let current = AccountManager.shared.currentAccount {
                            TokenKeychain.shared.saveToken(current.token)
                        } else {
                            TokenKeychain.shared.deleteToken()
                        }
                    } else {
                        onSuccess(account)
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
