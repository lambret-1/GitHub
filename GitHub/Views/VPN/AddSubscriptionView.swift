//
//  AddSubscriptionView.swift
//  GitHub
//
//  用途：添加 VPN 订阅页面，支持输入订阅名称、URL、选择订阅类型
//  功能：
//    1. 订阅名称输入（可选，默认从 URL 自动生成）
//    2. 订阅 URL 输入（必填，支持小火箭和圈X格式）
//    3. 订阅类型选择（自动识别/小火箭/圈X）
//    4. 从剪贴板粘贴订阅 URL
//    5. 添加后自动更新订阅（拉取节点）
//  注意：本页面为 sheet 模态页面，拥有独立导航栏
//

import SwiftUI

// MARK: - 添加订阅页面

/// 添加 VPN 订阅页面
/// 以 sheet 模态形式展示，用户输入订阅信息后添加
struct AddSubscriptionView: View {

    // MARK: - 状态属性

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// 订阅名称
    @State private var subscriptionName = ""

    /// 订阅 URL
    @State private var subscriptionURL = ""

    /// 订阅类型
    @State private var subscriptionType: VPNSubscriptionType = .auto

    /// 是否正在添加（更新订阅中）
    @State private var isAdding = false

    /// 提示消息
    @State private var alertMessage: String?

    /// 是否显示提示
    @State private var showAlert = false

    /// 添加结果（成功后显示）
    @State private var addResult: VPNSubscription?

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            Form {
                // 订阅信息输入区
                Section(header: Text("订阅信息")) {
                    // 订阅名称
                    HStack {
                        Text("名称")
                            .foregroundColor(.primary)
                        TextField("可选，留空自动生成", text: $subscriptionName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.secondary)
                    }

                    // 订阅 URL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("订阅链接")
                            .foregroundColor(.primary)

                        TextField("输入订阅 URL", text: $subscriptionURL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .textContentType(.URL)
                            .padding(.vertical, 8)
                            // 这是一个什么东西：URL输入框垂直内边距
                            // 控制哪里：订阅链接输入框的高度
                            // 单位是什么：pt（点）
                            // 改大有什么效果：输入框变高，点击区域更大
                            // 改小有什么效果：输入框变矮，更紧凑
                            // 还能怎么改：可以使用固定高度

                        // 从剪贴板粘贴按钮
                        Button(action: {
                            pasteFromPasteboard()
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("从剪贴板粘贴")
                            }
                            .font(.subheadline)
                        }
                    }
                }

                // 订阅类型选择区
                Section(header: Text("订阅类型")) {
                    Picker("类型", selection: $subscriptionType) {
                        ForEach(VPNSubscriptionType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 订阅类型说明
                Section(header: Text("格式说明")) {
                    VStack(alignment: .leading, spacing: 8) {
                        formatExplanationRow(icon: "wand.and.stars", title: "自动识别", desc: "自动尝试小火箭→圈X→明文格式，推荐使用")
                        formatExplanationRow(icon: "rocket", title: "小火箭", desc: "Base64 编码的节点链接列表（vmess://、vless://、trojan://、ss://）")
                        formatExplanationRow(icon: "circle.hexagongrid", title: "圈X", desc: "[server] 段配置格式或 Base64 编码的节点列表")
                    }
                    .padding(.vertical, 4)
                }

                // 添加按钮
                Section {
                    Button(action: {
                        addSubscription()
                    }) {
                        HStack {
                            Spacer()
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text("添加中...")
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("添加订阅")
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        // 这是一个什么东西：添加按钮垂直内边距
                        // 控制哪里：添加按钮的高度
                        // 单位是什么：pt（点）
                        // 改大有什么效果：按钮变高，点击区域更大
                        // 改小有什么效果：按钮变矮，更紧凑
                        // 还能怎么改：可以使用固定高度
                        .background(isFormValid ? Color.blue : Color.gray)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || isAdding)
                }
            }
            .navigationTitle("添加订阅")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) {
                    if addResult != nil {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 计算属性

    /// 表单是否有效（URL 不为空）
    private var isFormValid: Bool {
        !subscriptionURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - 格式说明行

    /// 格式说明行
    private func formatExplanationRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.blue)
                .frame(width: 24)
            // 这是一个什么东西：格式说明图标宽度
            // 控制哪里：格式说明行左侧图标的宽度
            // 单位是什么：pt（点）
            // 改大有什么效果：图标区域变宽
            // 改小有什么效果：图标区域变窄
            // 还能怎么改：可以根据图标大小动态调整

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 方法

    /// 从剪贴板粘贴订阅 URL
    private func pasteFromPasteboard() {
        #if canImport(UIKit)
        if let pasteboardString = UIPasteboard.general.string {
            subscriptionURL = pasteboardString
            // 如果名称为空，自动从 URL 生成名称
            if subscriptionName.isEmpty {
                subscriptionName = generateName(from: pasteboardString)
            }
        } else {
            showAlert(message: "剪贴板为空")
        }
        #else
        showAlert(message: "当前平台不支持剪贴板")
        #endif
    }

    /// 从 URL 生成订阅名称
    /// - Parameter url: 订阅 URL
    /// - Returns: 生成的名称（取域名部分）
    private func generateName(from url: String) -> String {
        guard let urlComponents = URLComponents(string: url),
              let host = urlComponents.host else {
            return "新订阅"
        }
        // 取域名的前两个部分作为名称
        let parts = host.components(separatedBy: ".")
        if parts.count >= 2 {
            return parts[parts.count - 2]
        }
        return host
    }

    /// 添加订阅
    private func addSubscription() {
        guard isFormValid else { return }

        isAdding = true

        // 生成名称（如果为空）
        let name = subscriptionName.isEmpty ? generateName(from: subscriptionURL) : subscriptionName

        // 添加订阅
        let subscription = VPNSubscriptionManager.shared.addSubscription(
            name: name,
            url: subscriptionURL.trimmingCharacters(in: .whitespacesAndNewlines),
            type: subscriptionType
        )

        // 自动更新订阅（拉取节点）
        VPNSubscriptionManager.shared.updateSubscription(subscription) { result in
            DispatchQueue.main.async {
                isAdding = false
                addResult = subscription

                switch result {
                case .success(_, let nodes):
                    alertMessage = "添加成功，获取到 \(nodes.count) 个节点"
                case .failure(_, let error):
                    alertMessage = "订阅已添加，但更新失败：\(error.localizedDescription)\n您可以稍后手动更新"
                }

                showAlert = true
            }
        }
    }
}

// MARK: - 预览

struct AddSubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        AddSubscriptionView()
    }
}
