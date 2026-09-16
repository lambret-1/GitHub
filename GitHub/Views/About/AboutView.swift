import SwiftUI

// ==============================================================================
// AboutView 关于页面
// 功能：显示应用版本信息、检查更新、应用内下载更新、自动分享至签名工具
// ==============================================================================

struct AboutView: View {
    @EnvironmentObject var appState: AppState
    @State private var isCheckingUpdate = false
    @State private var isDownloadingUpdate = false
    @State private var downloadProgress: Double = 0
    @State private var updateCheckResult: AppVersion.UpdateCheckResult?
    @State private var latestRelease: AppVersion.ReleaseInfo?
    @State private var showDownloadConfirm = false
    @State private var downloadErrorMessage: String?
    @State private var showDownloadError = false

    var body: some View {
        List {
            // 应用图标和名称
            Section {
                VStack(spacing: 12) {
                    // 应用图标 - 使用APP图标
                    Image("AppIconImage")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                        .cornerRadius(18)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
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
                .padding(.vertical, 20)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }

            // 版本信息
            Section(header: Text("版本信息")) { // iOS14兼容：使用旧版Section语法
                versionInfoRow(icon: "number", color: .blue, title: "版本号", value: "v\(AppVersion.currentVersion)")
                versionInfoRow(icon: "hammer", color: .orange, title: "构建号", value: AppVersion.buildNumber)
                versionInfoRow(icon: "apple.logo", color: .gray, title: "部署目标", value: "iOS 16.0+")
            }

            // 检查更新
            Section(header: Text("更新")) { // iOS14兼容：使用旧版Section语法
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
            Section(header: Text("相关链接")) { // iOS14兼容：使用旧版Section语法
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
                .padding(.vertical, 10)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            }
        }
        .listStyle(InsetGroupedListStyle())
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $showDownloadConfirm) { // iOS14兼容：使用旧版Alert语法
            Alert(
                title: Text("发现新版本"),
                message: Text(latestRelease != nil ? "新版本 \(latestRelease!.tagName) 已发布，点击立即下载，下载完成后将自动弹出分享面板进行安装。" : "发现新版本"),
                primaryButton: .default(Text("立即下载"), action: {
                    if let release = latestRelease {
                        downloadUpdate(release: release)
                    }
                }),
                secondaryButton: .cancel(Text("稍后再说"))
            )
        }
        .alert(isPresented: $showDownloadError) { // iOS14兼容：使用旧版Alert语法
            Alert(
                title: Text("下载失败"),
                message: Text(downloadErrorMessage ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        .overlay( // iOS14兼容：使用旧版overlay语法
            Group {
                if isDownloadingUpdate {
                    downloadingOverlay
                }
            },
            alignment: .center
        )
    }

    // MARK: - 版本信息行

    private func versionInfoRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
    }

    // MARK: - 链接行

    private func linkRow(icon: String, color: Color, title: String, url: String) -> some View {
        Button(action: {
            if let url = URL(string: url) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                        .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                        .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度
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
                .foregroundColor(Color.red)
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
                    .foregroundColor(appState.isDarkMode ? .white : .black)
                    .font(.subheadline)
            }
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("发现新版本: \(release.tagName)")
                        .foregroundColor(appState.isDarkMode ? .white : .black)
                        .font(.subheadline.bold())
                }
                Text("发布时间: \(日期工具.相对时间(fromISO: release.publishedAt))")
                    .font(.caption)
                    .foregroundColor(appState.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
                if let body = release.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(appState.isDarkMode ? .white.opacity(0.8) : .black.opacity(0.8))
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
                    .padding(.vertical, 10)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    .background(Color.blue)
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .disabled(isDownloadingUpdate)
            }
            .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        case .checkFailed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color.red)
                Text("检查失败: \(error.localizedDescription)")
                    .foregroundColor(appState.isDarkMode ? .white : .black)
                    .font(.subheadline)
            }
        }
    }

    // MARK: - 下载进度视图

    private var downloadProgressView: some View {
        VStack(spacing: 8) {
            ProgressView(value: downloadProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .black))
            HStack {
                Text("正在下载更新...")
                    .font(.subheadline)
                    .foregroundColor(Color.black)
                Spacer()
                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(Color.black)
            }
        }
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color.white)
    }

    // MARK: - 下载中全屏覆盖层

    private var downloadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView(value: downloadProgress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    .scaleEffect(1.5)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置

                Text("正在下载更新...")
                    .font(.headline)
                    .foregroundColor(Color.black)

                Text(String(format: "%.0f%%", downloadProgress * 100))
                    .font(.subheadline)
                    .foregroundColor(Color.black)

                Text("下载完成后将自动弹出分享面板")
                    .font(.caption)
                    .foregroundColor(.black.opacity(0.7))
            }
            .padding(32)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
            .background(Color.white)
            .cornerRadius(16)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
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

// MARK: - 预览

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AboutView()
        }
    }
}
