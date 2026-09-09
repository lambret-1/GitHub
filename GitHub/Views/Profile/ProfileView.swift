import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false

    // 页面导航状态（用于隐藏NavigationLink的>符号）
    @State private var showAbout = false
    @State private var showAccountManager = false

    // 检查更新相关状态
    @State private var isCheckingUpdate = false
    @State private var showUpdateResult = false
    @State private var updateResultTitle = ""
    @State private var updateResultMessage = ""
    @State private var latestRelease: AppVersion.ReleaseInfo?
    @State private var showDownloadConfirm = false
    
    var body: some View {
        NavigationView {
            List {
                if let user = appState.currentUser {
                    // 用户信息卡片
                    Section {
                        VStack(spacing: 16) {
                            // 头像（双击切换暗黑模式）
                            AsyncImage(url: URL(string: user.avatarUrl)) { image in
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                ProgressView()
                            }
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .shadow(radius: 4)
                            .onTapGesture(count: 2) {
                                // 双击头像切换暗黑模式
                                appState.toggleDarkMode()
                            }
                            
                            // 姓名和用户名
                            VStack(spacing: 4) {
                                Text(user.displayName)
                                    .font(.title2.bold())
                                Text("@\(user.login)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            // 简介
                            if let bio = user.bio, !bio.isEmpty {
                                Text(bio)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // 统计数据
                            HStack(spacing: 30) {
                                StatView(number: user.publicRepos, label: "仓库")
                                StatView(number: user.followers, label: "粉丝")
                                StatView(number: user.following, label: "关注")
                            }
                            .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    }
                    
                    // 详细信息
                    Section("个人信息") {
                        if let company = user.company, !company.isEmpty {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("公司")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(company)
                            }
                        }
                        
                        if let location = user.location, !location.isEmpty {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("位置")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(location)
                            }
                        }
                        
                        if let blog = user.blog, !blog.isEmpty {
                            HStack {
                                Image(systemName: "link")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)
                                Text("博客")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(blog)
                                    .lineLimit(1)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.gray)
                                .frame(width: 30)
                            Text("注册时间")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(user.formattedDate)
                        }
                    }
                    
                    // 账号设置
                    Section("账号") {
                        Button(action: {
                            showAccountManager = true
                        }) {
                            HStack {
                                Image(systemName: "person.2.circle")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("账号管理")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(AccountManager.shared.accounts.count) 个账号")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                        }
                        .background(
                            NavigationLink(destination: AccountManagerView(), isActive: $showAccountManager) {
                                EmptyView()
                            }
                            .hidden()
                        )

                        Button(action: {
                            if let url = URL(string: user.htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("在 GitHub 查看主页")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        // 检查更新
                        Button(action: {
                            checkForUpdates()
                        }) {
                            HStack {
                                if isCheckingUpdate {
                                    ProgressView()
                                        .frame(width: 30)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)
                                }
                                Text(isCheckingUpdate ? "正在检查更新..." : "检查更新")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                        .disabled(isCheckingUpdate)

                        Button(action: {
                            showAbout = true
                        }) {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)
                                Text("关于")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("v\(AppVersion.currentVersion)")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                            }
                        }
                        .background(
                            NavigationLink(destination: AboutView(), isActive: $showAbout) {
                                EmptyView()
                            }
                            .hidden()
                        )

                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                    .frame(width: 30)
                                Text("退出登录")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("加载中...")
                            Spacer()
                        }
                        .padding(.vertical, 40)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("我的")
            // 检查更新结果alert
            .alert(isPresented: $showUpdateResult) {
                Alert(
                    title: Text(updateResultTitle),
                    message: Text(updateResultMessage),
                    dismissButton: .default(Text("确定"))
                )
            }
            // 发现新版本，确认下载alert
            .alert("发现新版本", isPresented: $showDownloadConfirm) {
                if let release = latestRelease {
                    Button("立即下载") {
                        // 跳转到AboutView页面进行下载
                        // 这里可以直接打开GitHub Release页面
                        if let url = URL(string: release.htmlUrl) {
                            UIApplication.shared.open(url)
                        }
                    }
                    Button("稍后再说", role: .cancel) {}
                }
            } message: {
                if let release = latestRelease {
                    Text("新版本 \(release.tagName)\n发布时间: \(AppVersion.formattedDate(from: release.publishedAt))\n\n\(release.body ?? "暂无更新说明")")
                }
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("确认退出"),
                message: Text("退出后需要重新输入 Token 才能登录"),
                primaryButton: .destructive(Text("退出")) {
                    appState.logout()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - 检查更新

    private func checkForUpdates() {
        isCheckingUpdate = true

        AppVersion.checkForUpdates { result in
            DispatchQueue.main.async {
                isCheckingUpdate = false
                switch result {
                case .upToDate:
                    updateResultTitle = "已是最新版本"
                    updateResultMessage = "当前版本 v\(AppVersion.currentVersion) 已是最新版本"
                    showUpdateResult = true
                case .updateAvailable(let release):
                    latestRelease = release
                    showDownloadConfirm = true
                case .checkFailed(let error):
                    updateResultTitle = "检查失败"
                    updateResultMessage = "检查更新失败: \(error.localizedDescription)"
                    showUpdateResult = true
                }
            }
        }
    }
}

struct StatView: View {
    let number: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(number)")
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AppState.shared)
    }
}
