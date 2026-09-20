import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    @State private var showLogoutAlert = false

    // 页面导航状态（用于隐藏NavigationLink的>符号）
    @State private var showAbout = false
    @State private var showAccountManager = false
    @State private var showCrashLogs = false
    @State private var showDebugLogs = false

    // 检查更新相关状态
    @State private var isCheckingUpdate = false
    @State private var showUpdateResult = false
    @State private var updateResultTitle = ""
    @State private var updateResultMessage = ""
    @State private var latestRelease: AppVersion.ReleaseInfo?
    @State private var showDownloadConfirm = false

    // 下载更新相关状态
    @State private var isDownloadingUpdate = false
    @State private var downloadProgress: Double = 0
    @State private var downloadErrorMessage: String?
    @State private var showDownloadError = false

    var body: some View {
        NavigationStack {
            List {
                if let user = appState.currentUser {
                    // 用户信息卡片（还原初始状态）
                    Section {
                        VStack(spacing: 16) {
                            // 头像（双击切换暗黑模式）
                            CachedImageView(urlString: user.avatarUrl, placeholder: Image(systemName: "person.circle.fill"))
                                .frame(width: 80, height: 80)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .shadow(radius: 4)
                                .onTapGesture(count: 2) {
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
                                StatView(number: user.publicRepos ?? 0, label: "仓库")
                                StatView(number: user.followers ?? 0, label: "粉丝")
                                StatView(number: user.following ?? 0, label: "关注")
                            }
                            .padding(.top, 8)  // 这是顶部内边距，控制内容上方与边缘的空白距离，单位是pt；改大上方留白更宽，改小上方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    }
                    
                    // 详细信息
                    Section("个人信息") {
                        if let company = user.company, !company.isEmpty {
                            HStack {
                                Image(systemName: "building.2")
                                    .foregroundColor(.gray)
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                                Text("账号管理")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(AccountManager.shared.accounts.count) 个账号")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: {
                            if let url = URL(string: user.htmlUrl) {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                    .foregroundColor(.blue)
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                        .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(.blue)
                                        .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                                Text("关于")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("v\(AppVersion.currentVersion)")
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        // 崩溃日志
                        Button(action: {
                            showCrashLogs = true
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                                Text("崩溃日志")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        // 调试日志
                        Button(action: {
                            showDebugLogs = true
                        }) {
                            HStack {
                                Image(systemName: "ladybug")
                                    .foregroundColor(.purple)
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                                Text("调试日志")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }

                        Button(action: {
                            showLogoutAlert = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.square")
                                    .foregroundColor(.red)
                                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                        .padding(.vertical, 40)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
                        // 应用内下载更新，下载完成后自动弹出分享面板
                        downloadUpdate(release: release)
                    }
                    Button("稍后再说", role: .cancel) {}
                }
            } message: {
                if let release = latestRelease {
                    Text("新版本 \(release.tagName) 已发布，点击立即下载，下载完成后将自动弹出分享面板进行安装。")
                }
            }
            // 下载失败alert
            .alert("下载失败", isPresented: $showDownloadError) {
                Button("确定") {}
            } message: {
                Text(downloadErrorMessage ?? "未知错误")
            }
            // 下载中全屏覆盖层
            .overlay {
                if isDownloadingUpdate {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView(value: downloadProgress)
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(1.5)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置

                            Text("正在下载更新...")
                                .font(.headline)
                                .foregroundColor(.black)

                            Text(String(format: "%.0f%%", downloadProgress * 100))
                                .font(.subheadline)
                                .foregroundColor(.black)

                            Text("下载完成后将自动弹出分享面板")
                                .font(.caption)
                                .foregroundColor(.black.opacity(0.7))
                        }
                        .padding(32)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                        .background(Color.white)
                        .cornerRadius(16)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                }
            }
            .navigationDestination(isPresented: $showAccountManager) {
                AccountManagerView()
            }
            .navigationDestination(isPresented: $showAbout) {
                AboutView()
            }
            .navigationDestination(isPresented: $showCrashLogs) {
                CrashLogListView()
            }
            .navigationDestination(isPresented: $showDebugLogs) {
                DebugLogView()
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

    // MARK: - 下载更新

    private func downloadUpdate(release: AppVersion.ReleaseInfo) {
        // 找到IPA文件的下载链接
        let ipaAsset = release.assets.first { $0.name.hasSuffix(".ipa") }

        guard let asset = ipaAsset else {
            downloadErrorMessage = "未找到IPA安装包"
            showDownloadError = true
            return
        }

        isDownloadingUpdate = true
        downloadProgress = 0

        // 使用API端点URL（url字段），支持私有仓库，需要认证头
        // API端点会返回302重定向到实际下载地址，URLSession自动跟随
        FileDownloadManager.shared.downloadAndShare(
            from: asset.url,
            fileName: asset.name,
            progress: { progress in
                self.downloadProgress = progress
            }
        ) { result in
            self.isDownloadingUpdate = false

            switch result {
            case .success:
                // 分享面板已自动弹出
                break
            case .failure(let error):
                self.downloadErrorMessage = "下载失败: \(error.localizedDescription)"
                self.showDownloadError = true
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
