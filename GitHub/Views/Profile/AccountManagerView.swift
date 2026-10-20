import SwiftUI

// ==============================================================================
// AccountManagerView 账号管理页面
// 功能：管理多个GitHub账号，支持添加、删除、切换账号
// ==============================================================================

struct AccountManagerView: View {
    @StateObject private var accountManager = AccountManager.shared
    @State private var showAddAccount = false
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
        // 使用sheet显示添加账号页面，确保验证按钮正常显示
        .sheet(isPresented: $showAddAccount) {
            AddAccountView { account in
                // 添加账号成功
                AccountManager.shared.addAccount(account)
                AccountManager.shared.switchTo(account)
                showAddAccount = false
            } onCancel: {
                showAddAccount = false
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
}
