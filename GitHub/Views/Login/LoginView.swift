import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenText: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showTokenHelp: Bool = false

    var body: some View {
        ZStack {
            // 暗黑渐变背景（简化，避免复杂动画导致闪退）
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color(red: 0.0, green: 0.1, blue: 0.0),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 30) {
                    // 顶部Logo区域
                    VStack(spacing: 16) {
                        // 头像（简化发光效果）
                        Image("AppIconImage")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                            )
                            .shadow(color: Color.green.opacity(0.4), radius: 8, x: 0, y: 0)

                        Text("GitHub 中文客户端")
                            .font(.largeTitle.bold())
                            .foregroundColor(.green)
                            .shadow(color: Color.green.opacity(0.8), radius: 10, x: 0, y: 0)

                        Text("Token 安全登录 · 代码随时管理")
                            .font(.subheadline)
                            .foregroundColor(.green.opacity(0.7))
                    }
                    .padding(.top, 60)

                    // 登录表单
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Personal Access Token")
                            .font(.headline)
                            .foregroundColor(.green)

                        SecureField("请输入 GitHub 个人访问令牌", text: $tokenText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 14, design: .monospaced))
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .colorScheme(.dark)

                        Button(action: {
                            showTokenHelp.toggle()
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                Text("如何获取 Token？")
                            }
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.8))
                        }

                        if showTokenHelp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("获取步骤：")
                                    .font(.caption.bold())
                                    .foregroundColor(.green)
                                Text("1. 打开 GitHub → Settings → Developer settings")
                                Text("2. 选择 Personal access tokens → Tokens (classic)")
                                Text("3. 点击 Generate new token，勾选 repo 和 user 权限")
                                Text("4. 复制生成的 Token 粘贴到上方")
                            }
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.7))
                            .padding(10)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal)

                    // 错误提示
                    if showError {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.subheadline)
                        }
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.5), lineWidth: 1)
                        )
                        .padding(.horizontal)
                    }

                    // 登录按钮（黑客风格）
                    Button(action: loginAction) {
                        HStack {
                            if appState.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .green))
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .foregroundColor(.green)
                            }
                            Text(appState.isLoading ? "登录中..." : "立即登录")
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.black)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                        )
                        .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 0)
                    }
                    .disabled(appState.isLoading || tokenText.isEmpty)
                    .padding(.horizontal)

                    Spacer(minLength: 40)

                    // 底部说明
                    VStack(spacing: 8) {
                        Text("安全说明")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("Token 仅存储在本机 Keychain 中，不会上传到任何第三方服务器")
                            .font(.caption)
                            .foregroundColor(.green.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func loginAction() {
        guard !tokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请输入有效的 Token"
            showError = true
            return
        }

        showError = false
        appState.login(token: tokenText.trimmingCharacters(in: .whitespacesAndNewlines)) { success, error in
            if !success {
                errorMessage = error ?? "登录失败，请检查 Token 是否正确"
                showError = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AppState.shared)
    }
}
