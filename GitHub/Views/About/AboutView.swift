import SwiftUI

// ==============================================================================
// AboutView 关于页面
// 功能：显示应用版本信息、检查更新、应用内下载更新、自动分享至签名工具
// ==============================================================================

struct AboutView: View {
    @State private var isCheckingUpdate = false
    @State private var isDownloadingUpdate = false
    @State private var downloadProgress: Double = 0
    @State private var updateCheckResult: AppVersion.UpdateCheckResult?
    @State private var latestRelease: AppVersion.ReleaseInfo?
    @State private var showDownloadConfirm = false
    @State private var downloadErrorMessage: String?
    @State private var showDownloadError = false

    // 镜像加速相关状态
    @State private var useMirrorAcceleration: Bool = AppSettings.shared.useMirrorAcceleration
    @State private var showMirrorPicker: Bool = false
    @ObservedObject private var appSettings = AppSettings.shared

    var body: some View {
        List {
            // 应用图标和名称
            Section {
                VStack(spacing: 12) {
                    // 应用图标 - 使用APP图标
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .cornerRadius(18)
                        .shadow(radius: 6)

                    // 应用名称
                    Text(AppVersion.appName)
                        .font(.title2.bold())

                    // 版本号
                    Text(AppVersion.fullVersionDescription)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // 镜像加速设置
            Section("网络设置") {
                // 镜像加速开关
                Toggle(isOn: $useMirrorAcceleration) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("镜像加速")
                                .foregroundColor(.primary)
                            Text("国内访问 GitHub 加速")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onChange(of: useMirrorAcceleration) { newValue in
                    AppSettings.shared.useMirrorAcceleration = newValue
                }

                // 当前镜像信息
                if useMirrorAcceleration {
                    Button(action: {
                        showMirrorPicker = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("当前镜像")
                                    .foregroundColor(.primary)
                                Text(appSettings.currentMirror.name)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }

                    // 安全说明
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("账号安全保护")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Text("API 请求（账号、仓库、文件读写）始终使用官方服务器，仅文件下载、网页预览、头像加载使用镜像加速，确保账号信息安全。")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 4)
                }
            }

            // 版本信息
            Section("版本信息") {
                versionInfoRow(icon: "number", color: .blue, title: "版本号", value: "v\(AppVersion.currentVersion)")
                versionInfoRow(icon: "hammer", color: .orange, title: "构建号", value: AppVersion.buildNumber)
                versionInfoRow(icon: "apple.logo", color: .gray, title: "部署目标", value: "iOS 15.0+")
            }

            // 检查更新
            Section("更新") {
                updateButton

                // 显示检查结果
                if let result = updateCheckResult {
                    updateResultView(result)
                }

                // 下载进度
                if isDownloadingUpdate {
                    downloadProgressView
                }
            }

            // 链接
            Section("相关链接") {
                linkRow(icon: "chevron.left.forwardslash.chevron.right", color: .black, title: "GitHub 仓库", url: "https://github.com/lambret-1/GitHub")
                linkRow(icon: "tag", color: .green, title: "所有 Releases", url: "https://github.com/lambret-1/GitHub/releases")
                linkRow(icon: "exclamationmark.bubble", color: .red, title: "反馈问题", url: "https://github.com/lambret-1/GitHub/issues")
            }

            // 版权信息
            Section {
                VStack(spacing: 4) {
                    Text("GitHub iOS Client")
                        .font(.footnote)
                        .foregroundColor(.gray)
                    Text("使用 SwiftUI 构建")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .alert("发现新版本", isPresented: $showDownloadConfirm) {
            if let release = latestRelease {
                Button("立即下载") {
                    downloadUpdate(release: release)
                }
                Button("稍后再说", role: .cancel) {}
            }
        } message: {
            if let release = latestRelease {
                Text("新版本 \(release.tagName) 已发布，点击立即下载，下载完成后将自动弹出分享面板进行安装。")
            }
        }
        .alert("下载失败", isPresented: $showDownloadError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(downloadErrorMessage ?? "未知错误")
        }
        .overlay {
            if isDownloadingUpdate {
                downloadingOverlay
            }
        }
        // 镜像选择器
        .sheet(isPresented: $showMirrorPicker) {
            MirrorPickerView { selectedMirror in
                // 检查是否是预设镜像
                if let index = AppSettings.shared.presetMirrors.firstIndex(where: { $0.url == selectedMirror.url }) {
                    // 预设镜像：设置 selectedMirrorIndex，清除 customMirrorURL
                    AppSettings.shared.selectedMirrorIndex = index
                    AppSettings.shared.customMirrorURL = nil
                } else {
                    // 自定义镜像：设置 customMirrorURL
                    AppSettings.shared.customMirrorURL = selectedMirror.url
                }
                // 确保镜像加速开启
                if !AppSettings.shared.useMirrorAcceleration {
                    AppSettings.shared.useMirrorAcceleration = true
                    useMirrorAcceleration = true
                }
                showMirrorPicker = false
            }
        }
    }

    // MARK: - 版本信息行

    private func versionInfoRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }

    // MARK: - 链接行

    private func linkRow(icon: String, color: Color, title: String, url: String) -> some View {
        Button(action: {
            // 应用镜像加速转换
            let convertedURL = AppSettings.shared.convertWebURL(url)
            if let url = URL(string: convertedURL) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)
                Text(title)
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
    }

    // MARK: - 更新按钮

    private var updateButton: some View {
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
                if let result = updateCheckResult, !isDownloadingUpdate {
                    updateResultIcon(result)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
        }
        .disabled(isCheckingUpdate || isDownloadingUpdate)
    }

    // MARK: - 更新结果图标

    @ViewBuilder
    private func updateResultIcon(_ result: AppVersion.UpdateCheckResult) -> some View {
        switch result {
        case .upToDate:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .updateAvailable:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.orange)
        case .checkFailed:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
        }
    }

    // MARK: - 更新结果视图

    @ViewBuilder
    private func updateResultView(_ result: AppVersion.UpdateCheckResult) -> some View {
        switch result {
        case .upToDate:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已是最新版本")
                    .foregroundColor(.black)
                    .font(.subheadline)
            }
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("发现新版本: \(release.tagName)")
                        .foregroundColor(.black)
                        .font(.subheadline.bold())
                }
                Text("发布时间: \(AppVersion.formattedDate(from: release.publishedAt))")
                    .font(.caption)
                    .foregroundColor(.black)
                if let body = release.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(.black)
                        .lineLimit(3)
                }
                Button(action: {
                    downloadUpdate(release: release)
                }) {
                    HStack {
                        Image(systemName: "arrow.down.circle")
                        Text("立即下载更新")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isDownloadingUpdate)
            }
            .padding(.vertical, 4)
        case .checkFailed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("检查失败: \(error.localizedDescription)")
                    .foregroundColor(.black)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - 下载进度视图

    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: downloadProgress)
                .progressViewStyle(LinearProgressViewStyle())
            HStack {
                Text("正在下载更新...")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Spacer()
                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
        }
        .padding(.vertical, 4)
        .background(Color.white)
    }

    // MARK: - 下载中全屏覆盖层

    private var downloadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)

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
            .padding(32)
            .background(Color.white)
            .cornerRadius(16)
        }
    }

    // MARK: - 检查更新

    private func checkForUpdates() {
        isCheckingUpdate = true
        updateCheckResult = nil

        AppVersion.checkForUpdates { result in
            isCheckingUpdate = false
            updateCheckResult = result

            if case .updateAvailable(let release) = result {
                latestRelease = release
                showDownloadConfirm = true
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

        // 更新下载使用镜像加速
        // 公共镜像站（清华、中科大等）可以用于下载Release文件
        // 注意：公共镜像站只镜像了部分热门项目，如果镜像下载失败会自动报错
        FileDownloadManager.shared.downloadAndShare(
            from: asset.browserDownloadUrl,
            fileName: asset.name,
            useMirror: true,
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

// MARK: - 预览

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}
