import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var tokenText: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showTokenHelp: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // 顶部Logo区域
                VStack(spacing: 16) {
                    // 使用APP图标
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(16)
                        .shadow(radius: 5)

                    Text("GitHub 中文客户端")
                        .font(.largeTitle.bold())

                    Text("Token 安全登录 · 代码随时管理")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 60)
                
                // 登录表单
                VStack(alignment: .leading, spacing: 12) {
                    Text("Personal Access Token")
                        .font(.headline)
                    
                    SecureField("请输入 GitHub 个人访问令牌", text: $tokenText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 14, design: .monospaced))
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Button(action: {
                        showTokenHelp.toggle()
                    }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("如何获取 Token？")
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                    
                    if showTokenHelp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("获取步骤：")
                                .font(.caption.bold())
                            Text("1. 打开 GitHub → Settings → Developer settings")
                            Text("2. 选择 Personal access tokens → Tokens (classic)")
                            Text("3. 点击 Generate new token，勾选 repo 和 user 权限")
                            Text("4. 复制生成的 Token 粘贴到上方")
                        }
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(10)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
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
                    .padding(.horizontal)
                }
                
                // 登录按钮
                Button(action: loginAction) {
                    HStack {
                        if appState.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text(appState.isLoading ? "登录中..." : "立即登录")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .disabled(appState.isLoading || tokenText.isEmpty)
                .padding(.horizontal)
                
                Spacer(minLength: 40)
                
                // 底部说明
                VStack(spacing: 8) {
                    Text("安全说明")
                        .font(.caption.bold())
                    Text("Token 仅存储在本机 Keychain 中，不会上传到任何第三方服务器")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
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
