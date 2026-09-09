import SwiftUI

// ==============================================================================
// AboutView 关于页面
// 功能：显示应用版本信息、检查更新、跳转GitHub仓库
// ==============================================================================

struct AboutView: View {
    @State private var isCheckingUpdate = false
    @State private var updateCheckResult: AppVersion.UpdateCheckResult?
    @State private var showUpdateAlert = false
    @State private var latestRelease: AppVersion.ReleaseInfo?

    var body: some View {
        List {
            // 应用图标和名称
            Section {
                VStack(spacing: 12) {
                    // 应用图标
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 48))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
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

            // 版本信息
            Section("版本信息") {
                HStack {
                    Image(systemName: "number")
                        .foregroundColor(.blue)
                        .frame(width: 30)
                    Text("版本号")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("v\(AppVersion.currentVersion)")
                }

                HStack {
                    Image(systemName: "hammer")
                        .foregroundColor(.orange)
                        .frame(width: 30)
                    Text("构建号")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(AppVersion.buildNumber)
                }

                HStack {
                    Image(systemName: "apple.logo")
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    Text("部署目标")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("iOS 15.0+")
                }
            }

            // 检查更新
            Section("更新") {
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
                        if let result = updateCheckResult {
                            updateResultIcon(result)
                        } else {
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .disabled(isCheckingUpdate)

                // 显示检查结果
                if let result = updateCheckResult {
                    updateResultView(result)
                }
            }

            // 链接
            Section("相关链接") {
                Button(action: {
                    if let url = URL(string: "https://github.com/lambret-1/GitHub") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .foregroundColor(.black)
                            .frame(width: 30)
                        Text("GitHub 仓库")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }

                Button(action: {
                    if let url = URL(string: "https://github.com/lambret-1/GitHub/releases") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(.green)
                            .frame(width: 30)
                        Text("所有 Releases")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }

                Button(action: {
                    if let url = URL(string: "https://github.com/lambret-1/GitHub/issues") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        Text("反馈问题")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
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
        .alert(isPresented: $showUpdateAlert) {
            if let release = latestRelease {
                return Alert(
                    title: Text("发现新版本"),
                    message: Text("新版本 \(release.tagName)\n发布时间: \(AppVersion.formattedDate(from: release.publishedAt))\n\n\(release.body ?? "暂无更新说明")"),
                    primaryButton: .default(Text("前往下载")) {
                        if let url = URL(string: release.htmlUrl) {
                            UIApplication.shared.open(url)
                        }
                    },
                    secondaryButton: .cancel(Text("稍后再说"))
                )
            } else {
                return Alert(title: Text("提示"), message: Text("已是最新版本"), dismissButton: .default(Text("确定")))
            }
        }
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
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        case .updateAvailable(let release):
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("发现新版本: \(release.tagName)")
                        .foregroundColor(.orange)
                        .font(.subheadline.bold())
                }
                Text("发布时间: \(AppVersion.formattedDate(from: release.publishedAt))")
                    .font(.caption)
                    .foregroundColor(.gray)
                if let body = release.body, !body.isEmpty {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                Button(action: {
                    if let url = URL(string: release.htmlUrl) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("前往下载")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(.vertical, 4)
        case .checkFailed(let error):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("检查失败: \(error.localizedDescription)")
                    .foregroundColor(.red)
                    .font(.subheadline)
            }
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
                showUpdateAlert = true
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
