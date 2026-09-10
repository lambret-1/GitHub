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
                // 预设镜像列表
                Section("推荐镜像") {
                    ForEach(mirrors) { mirror in
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
                                if mirror.isOfficial {
                                    Text("官方")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                // 自定义镜像
                Section("自定义镜像") {
                    if showCustomInput {
                        VStack(spacing: 12) {
                            TextField("输入镜像 API 地址", text: $customURL)
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

                                Button("使用") {
                                    if !customURL.isEmpty {
                                        let mirror = MirrorOption(name: "自定义", url: customURL, isOfficial: false)
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
                        Text("镜像加速用于解决国内访问 GitHub API 缓慢的问题。")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("开启后，所有 API 请求将通过镜像服务器转发。")
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
