import SwiftUI

@main
struct GitHubApp: App {
    @StateObject private var appState = AppState.shared
    // 分享文件上传视图的展示请求。
    // 用 item 而不是 Bool：Bool 一旦遇到一次"弹窗没真正弹出来"就会一直停在 true，
    // 之后每次分享都会被 `guard !showShareUpload` 拦掉，表现为"分享好几次才进待传区"。
    @State private var shareUploadRequest: ShareUploadRequest?
    // 记录最近一次请求时间和页面是否真的出现，用于识别"请求了但系统没弹出"的失败情况
    @State private var shareUploadRequestedAt: Date?
    @State private var isShareUploadVisible: Bool = false
    @State private var shareUploadRetryCount: Int = 0
    // 监听APP前后台状态，确保从后台唤起时也能检测分享文件
    @Environment(\.scenePhase) private var scenePhase

    private struct ShareUploadRequest: Identifiable {
        let id = UUID()
    }

    init() {
        // 安装崩溃日志记录器（使用Signal Handler和NSException Handler双机制捕获崩溃）
        // 必须在App启动最早期调用，确保能够捕获所有崩溃
        if !AppState.isUITesting {
            CrashLogger.shared.install()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(appState)
            // 全局启用文本选择，所有视图中的Text都可以长按选择、复制、分享
            .textSelection(.enabled)
            // 根据暗黑模式状态设置应用配色方案
            .preferredColorScheme(appState.isDarkMode ? .dark : .light)
            // 应用启动时自动检查更新（强制检查，忽略稍后提醒）
            .onAppear {
                guard !AppState.isUITesting else { return }
                // 延迟2秒检查更新，避免影响启动速度
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    appState.checkForUpdatesAndNotify(force: true)
                }
                // 检测从Share Extension传递过来的待上传文件（启动时检测）
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showShareUploadIfNeeded()
                }
            }
            // 监听APP前后台状态变化，从后台回到前台时也检测分享文件（解决onOpenURL不触发的问题）
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && !AppState.isUITesting {
                    // 延迟一下确保界面准备就绪
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showShareUploadIfNeeded()
                    }
                }
            }
            // 分享文件上传视图（item 驱动：每次分享都会生成新的请求，关闭后自动清空）
            .sheet(item: $shareUploadRequest, onDismiss: {
                shareUploadRequest = nil
                shareUploadRequestedAt = nil
                isShareUploadVisible = false
                shareUploadRetryCount = 0
            }) { _ in
                ShareUploadView()
                    .environmentObject(appState)
                    .onAppear {
                        isShareUploadVisible = true
                    }
                    .onDisappear {
                        isShareUploadVisible = false
                    }
            }
            // 处理URL打开事件（包括"打开方式"传递的文件和URL Scheme）
            .onOpenURL { url in
                DebugLogger.share("onOpenURL接收到URL: \(url.absoluteString)")
                DebugLogger.share("URL scheme: \(url.scheme ?? "nil")")

                // 情况1：通过"打开方式"传递的文件URL
                if url.scheme == "file" {
                    DebugLogger.share("检测到文件URL，开始接收文件...")
                    // 接收文件到待上传目录
                    let success = ShareFileManager.shared.receiveFile(from: url)
                    if success {
                        // 延迟一下确保界面准备就绪，然后弹出上传确认界面
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showShareUploadIfNeeded()
                        }
                    }
                    return
                }

                // 情况2：URL Scheme（保留备用）
                if url.scheme == "githubclient" && url.host == "share" {
                    // 延迟一下确保App完全启动和界面准备就绪
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showShareUploadIfNeeded()
                    }
                }
            }
            // 更新推送对话框
            .alert("发现新版本", isPresented: $appState.showUpdateAlert) {
                if appState.latestRelease != nil {
                    Button("立即更新") {
                        appState.downloadUpdateNow()
                    }
                    Button("稍后提醒", role: .cancel) {
                        appState.remindLater()
                    }
                }
            } message: {
                if let release = appState.latestRelease {
                    Text("新版本 \(release.tagName) 已发布，点击立即更新，下载完成后将自动弹出分享面板进行安装。")
                }
            }
            // 下载更新进度覆盖层
            .overlay {
                if appState.isDownloadingUpdate {
                    ZStack {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView(value: appState.updateDownloadProgress)
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
                            
                            Text("正在下载更新...")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Text(String(format: "%.0f%%", appState.updateDownloadProgress * 100))
                                .font(.subheadline)
                                .foregroundColor(.white)
                            
                            Text("下载完成后将自动弹出分享面板")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(32)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .cornerRadius(16)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    }
                }
            }
        }
    }

    // MARK: - 分享上传辅助方法

    /// 检测并显示分享文件上传视图
    /// 使用 item 驱动 + 每次分享生成新的请求，关闭后自动清空，避免状态卡死
    private func showShareUploadIfNeeded() {
        DebugLogger.share("=== showShareUploadIfNeeded 被调用 ===")
        ShareFileManager.shared.scanPendingFiles()
        DebugLogger.share("待上传文件数: \(ShareFileManager.shared.pendingFiles.count)")
        DebugLogger.share("hasPendingFiles: \(ShareFileManager.shared.hasPendingFiles)")
        DebugLogger.share("isLoggedIn: \(appState.isLoggedIn)")
        DebugLogger.share("shareUploadRequest: \(shareUploadRequest == nil ? "nil" : "已存在")")

        guard ShareFileManager.shared.hasPendingFiles && appState.isLoggedIn else {
            DebugLogger.share("❌ 条件不满足，不弹出sheet")
            if !ShareFileManager.shared.hasPendingFiles {
                DebugLogger.share("   原因：没有待上传文件（文件可能未保存成功）")
            }
            if !appState.isLoggedIn {
                DebugLogger.share("   原因：用户未登录")
            }
            return
        }

        // 如果sheet已经在显示/待显示中，不重复设置
        if shareUploadRequest != nil {
            // 页面已经真正出现，忽略重复请求
            if isShareUploadVisible {
                DebugLogger.share("⚠️ 分享上传页正在显示，忽略重复请求")
                return
            }

            // 请求后 2 秒内仍未出现，可能仍在转场中，先不打断
            if let requestedAt = shareUploadRequestedAt,
               Date().timeIntervalSince(requestedAt) < 2.0 {
                DebugLogger.share("⏳ 分享上传页呈现中，等待转场完成")
                return
            }

            // 请求存在但页面始终没出现：说明系统丢弃了这次 presentation，重置后重试
            guard shareUploadRetryCount < 3 else {
                DebugLogger.share("❌ 分享上传页多次呈现失败，释放状态等待下次分享")
                shareUploadRequest = nil
                shareUploadRequestedAt = nil
                shareUploadRetryCount = 0
                return
            }
            DebugLogger.share("⚠️ 上次分享上传页未真正显示，重置后重试")
            shareUploadRequest = nil
            shareUploadRequestedAt = nil
        }

        guard shareUploadRequest == nil else { return }

        // 生成一次新的展示请求，保证每次分享都能重新呈现
        DebugLogger.share("✅ 条件满足，弹出sheet")
        shareUploadRequest = ShareUploadRequest()
        shareUploadRequestedAt = Date()
        shareUploadRetryCount += 1

        // 2.2 秒后回查：只在"请求还在但页面没出现"时继续重试，避免用户手动关掉后被自动重新弹开
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard shareUploadRequest != nil && !isShareUploadVisible else { return }
            showShareUploadIfNeeded()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    // 使用@State绑定当前选中的tab，防止TabView状态混乱导致底部菜单栏消失
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RepoListView()
                .tabItem {
                    Image(systemName: "folder.fill")
                    Text("仓库")
                }
                .tag(0)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle.fill")
                    Text("我的")
                }
                .tag(1)
        }
        // 根据暗黑模式自动切换强调色，浅色模式用黑色，暗黑模式用白色
        .accentColor(appState.isDarkMode ? .white : .black)
        // 使用id()强制TabView在登录状态或暗黑模式变化时重新渲染，防止底部菜单栏消失
        .id("MainTabView-\(appState.isLoggedIn)-\(appState.isDarkMode)")
        // 监听tab切换，强制恢复TabBar显示，防止编辑模式下返回导致TabBar一直隐藏
        .onChange(of: selectedTab) { _ in
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    var responder: UIResponder? = window.rootViewController
                    while let next = responder {
                        if let tabBarController = next as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                            break
                        }
                        responder = next.next
                    }
                }
            }
        }
        // 强制设置TabView的背景色，防止在某些情况下背景透明导致菜单栏"消失"
        .onAppear {
            // iOS 15+ 需要设置UITabBar的外观
            let appearance = UITabBarAppearance()
            appearance.configureWithDefaultBackground()
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
            // 页面出现时强制恢复TabBar显示
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    var responder: UIResponder? = window.rootViewController
                    while let next = responder {
                        if let tabBarController = next as? UITabBarController {
                            tabBarController.tabBar.isHidden = false
                            break
                        }
                        responder = next.next
                    }
                }
            }
        }
    }
}
