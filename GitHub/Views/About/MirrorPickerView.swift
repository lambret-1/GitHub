import SwiftUI

// MARK: - 镜像选择器视图

struct MirrorPickerView: View {
    let onSelect: (MirrorOption) -> Void

    @Environment(\.presentationMode) private var presentationMode
    @State private var customURL: String = ""
    @State private var showCustomInput: Bool = false

    private let mirrors = AppSettings.shared.presetMirrors

    var body: some View {
        NavigationView {
            List {
                // 说明部分
                Section("使用说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• 公共镜像站（清华、中科大、华为云、阿里云）仅用于下载热门开源项目的Release文件")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• 公共镜像站只镜像了部分热门项目，不一定包含所有项目，如无法下载请使用官方服务器")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• 文件下载、HTML预览等操作在使用公共镜像站时仍走官方服务器")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• 如需代理所有GitHub请求，请添加自定义镜像（如gh-proxy.com类型的代理）")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• 头像不经过镜像，直接从官方加载")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("• API请求始终使用官方服务器，确保账号安全")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }

                // 预设镜像列表（只显示非官方镜像，官方镜像相当于关闭加速）
                Section("公共镜像站") {
                    ForEach(Array(mirrors.enumerated()), id: \.element.id) { index, mirror in
                        // 只显示非官方镜像（索引大于0）
                        if index > 0 {
                            Button(action: {
                                onSelect(mirror)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(mirror.name)
                                            .foregroundColor(.primary)
                                        Text(mirror.url)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    // 显示当前选中的勾选标记
                                    if AppSettings.shared.currentMirror.url == mirror.url {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                // 自定义镜像
                Section("自定义镜像") {
                    // 显示已添加的自定义镜像
                    if let customURL = AppSettings.shared.customMirrorURL, !customURL.isEmpty {
                        Button(action: {
                            let mirror = MirrorOption(name: "自定义镜像", url: customURL, isOfficial: false)
                            onSelect(mirror)
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("自定义镜像")
                                        .foregroundColor(.primary)
                                    Text(customURL)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                                Spacer()
                                // 显示当前选中的勾选标记
                                if AppSettings.shared.currentMirror.url == customURL {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }

                    if showCustomInput {
                        VStack(spacing: 12) {
                            TextField("输入镜像代理地址（如 https://gh-proxy.com）", text: $customURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)

                            HStack {
                                Button("取消") {
                                    showCustomInput = false
                                    customURL = ""
                                }
                                .foregroundColor(.gray)

                                Spacer()

                                Button("添加并使用") {
                                    if !customURL.isEmpty {
                                        let mirror = MirrorOption(name: "自定义镜像", url: customURL, isOfficial: false)
                                        onSelect(mirror)
                                    }
                                }
                                .foregroundColor(.blue)
                                .disabled(customURL.isEmpty)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button(action: {
                            showCustomInput = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                Text("添加自定义镜像")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }

                // 说明
                Section("说明") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("账号安全保护（重要）")
                                .font(.caption)
                                .foregroundColor(.green)
                                .bold()
                        }
                        Text("API 请求（账号信息、仓库列表、文件读写等需要认证的操作）始终使用 GitHub 官方服务器，不经过镜像，确保您的账号信息和私有仓库安全。")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("镜像加速仅用于：文件下载、HTML 网页预览、头像加载、浏览器打开 GitHub 页面等公开资源。")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("如果某个镜像无法使用，请切换到其他镜像或关闭加速。")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("切换镜像后，请返回上一页并下拉刷新以重新加载数据。")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("选择镜像")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
