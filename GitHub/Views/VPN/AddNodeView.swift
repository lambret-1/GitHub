//
//  AddNodeView.swift
//  GitHub
//
//  用途：手动添加节点页面，提供完整的节点配置表单
//  支持协议：VMess、VLESS（第一期），后续扩展 Trojan、Shadowsocks 等
//  表单字段：备注、协议、服务器地址、端口、UUID、加密方式、传输协议、TLS配置等
//

import SwiftUI

// MARK: - 添加节点页面

/// 手动添加节点页面
struct AddNodeView: View {

    // MARK: - 环境对象

    /// 关闭当前页面的环境变量
    @Environment(\.dismiss) private var dismiss

    // MARK: - 表单状态

    /// 节点备注名称
    @State private var remark: String = ""

    /// 协议类型
    @State private var protocolType: VPNProtocolType = .vmess

    /// 服务器地址
    @State private var serverAddress: String = ""

    /// 服务器端口
    @State private var serverPort: String = "443"

    /// 用户 UUID
    @State private var uuid: String = ""

    /// 加密方式（VMess 专用）
    @State private var encryption: VPNEncryptionType = .auto

    /// 传输协议类型
    @State private var transportType: VPNTransportType = .tcp

    /// WebSocket 路径
    @State private var wsPath: String = ""

    /// WebSocket Host
    @State private var wsHost: String = ""

    /// gRPC 服务名称
    @State private var grpcServiceName: String = ""

    /// 是否启用 TLS
    @State private var enableTLS: Bool = false

    /// TLS 服务器名称（SNI）
    @State private var tlsServerName: String = ""

    /// 是否跳过证书验证
    @State private var allowInsecure: Bool = false

    /// ALPN 协议列表（逗号分隔）
    @State private var alpn: String = ""

    /// 流控类型（VLESS 专用）
    @State private var flow: String = ""

    // MARK: - UI 状态

    /// 是否显示保存成功提示
    @State private var showSaveSuccess = false

    /// 错误提示信息
    @State private var errorMessage: String?

    /// 是否显示错误提示
    @State private var showError = false

    // MARK: - 高级设置展开状态

    /// 是否展开传输设置
    @State private var showTransportSettings = false

    /// 是否展开 TLS 设置
    @State private var showTLSSettings = false

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            Form {
                // 基础信息部分
                basicInfoSection

                // 协议特定设置
                if protocolType == .vmess {
                    vmessSettingsSection
                } else if protocolType == .vless {
                    vlessSettingsSection
                }

                // 传输设置
                transportSettingsSection

                // TLS 设置
                tlsSettingsSection
            }
            .navigationTitle("添加节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveNode()
                    }
                    .fontWeight(.medium)
                    .disabled(!isFormValid)
                }
            }
            .alert("保存成功", isPresented: $showSaveSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("节点「\(remark)」已添加")
            }
            .alert("错误", isPresented: $showError) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 基础信息部分

    /// 基础信息部分
    private var basicInfoSection: some View {
        Section(header: Text("基础信息")) {
            // 节点备注
            HStack {
                Text("备注")
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)
                // 这是一个什么东西：备注标签宽度
                // 控制哪里：表单左侧标签文字的宽度
                // 单位是什么：pt（点）
                // 改大有什么效果：标签变宽，输入框相对变窄
                // 改小有什么效果：标签变窄，输入框相对变宽
                // 还能怎么改：可以根据屏幕宽度动态调整，或者使用固定比例

                TextField("请输入节点备注名称", text: $remark)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }

            // 协议类型选择
            Picker(selection: $protocolType) {
                ForEach(VPNProtocolType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Text("协议")
            }

            // 服务器地址
            HStack {
                Text("服务器")
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)

                TextField("域名或 IP 地址", text: $serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .multilineTextAlignment(.trailing)
            }

            // 服务器端口
            HStack {
                Text("端口")
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)

                TextField("端口号", text: $serverPort)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            // UUID
            HStack {
                Text("UUID")
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)

                TextField("用户 UUID", text: $uuid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - VMess 特定设置

    /// VMess 协议特定设置
    private var vmessSettingsSection: some View {
        Section(header: Text("VMess 设置")) {
            // 加密方式
            Picker(selection: $encryption) {
                ForEach(VPNEncryptionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Text("加密方式")
            }
        }
    }

    // MARK: - VLESS 特定设置

    /// VLESS 协议特定设置
    private var vlessSettingsSection: some View {
        Section(header: Text("VLESS 设置")) {
            // 流控类型
            HStack {
                Text("流控")
                    .foregroundColor(.primary)
                    .frame(width: 70, alignment: .leading)

                TextField("可选，如 xtls-rprx-vision", text: $flow)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }

            // 提示信息
            Text("VLESS 协议默认不加密，依赖 TLS 或 Reality 保证安全")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 传输设置部分

    /// 传输设置部分
    private var transportSettingsSection: some View {
        Section {
            // 展开/收起按钮
            Button(action: {
                withAnimation {
                    showTransportSettings.toggle()
                }
            }) {
                HStack {
                    Text("传输设置")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showTransportSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if showTransportSettings {
                // 传输协议选择
                Picker(selection: $transportType) {
                    ForEach(VPNTransportType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                } label: {
                    Text("传输协议")
                }

                // WebSocket 配置
                if transportType == .websocket {
                    HStack {
                        Text("WS 路径")
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .leading)
                        // 这是一个什么东西：WS路径标签宽度
                        // 控制哪里：传输设置中左侧标签的宽度
                        // 单位是什么：pt（点）
                        // 改大有什么效果：标签变宽
                        // 改小有什么效果：标签变窄
                        // 还能怎么改：可以统一所有标签宽度

                        TextField("可选，如 /path", text: $wsPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("WS Host")
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .leading)

                        TextField("可选，伪装域名", text: $wsHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                    }
                }

                // gRPC 配置
                if transportType == .grpc {
                    HStack {
                        Text("gRPC 服务名")
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .leading)
                        // 这是一个什么东西：gRPC服务名标签宽度
                        // 控制哪里：gRPC设置中左侧标签的宽度
                        // 单位是什么：pt（点）
                        // 改大有什么效果：标签变宽
                        // 改小有什么效果：标签变窄
                        // 还能怎么改：可以统一所有标签宽度

                        TextField("可选，服务名称", text: $grpcServiceName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    // MARK: - TLS 设置部分

    /// TLS 设置部分
    private var tlsSettingsSection: some View {
        Section {
            // 展开/收起按钮
            Button(action: {
                withAnimation {
                    showTLSSettings.toggle()
                }
            }) {
                HStack {
                    Text("TLS 设置")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showTLSSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if showTLSSettings {
                // 启用 TLS 开关
                Toggle("启用 TLS", isOn: $enableTLS)

                if enableTLS {
                    // SNI
                    HStack {
                        Text("SNI")
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .leading)
                        // 这是一个什么东西：SNI标签宽度
                        // 控制哪里：TLS设置中左侧标签的宽度
                        // 单位是什么：pt（点）
                        // 改大有什么效果：标签变宽
                        // 改小有什么效果：标签变窄
                        // 还能怎么改：可以统一所有标签宽度

                        TextField("可选，服务器名称", text: $tlsServerName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                    }

                    // ALPN
                    HStack {
                        Text("ALPN")
                            .foregroundColor(.primary)
                            .frame(width: 80, alignment: .leading)

                        TextField("可选，如 h2,http/1.1", text: $alpn)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    // 跳过证书验证
                    Toggle("跳过证书验证", isOn: $allowInsecure)

                    // 安全提示
                    if allowInsecure {
                        Text("⚠️ 跳过证书验证存在安全风险，可能导致中间人攻击")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }

    // MARK: - 表单验证

    /// 表单是否有效（所有必填字段已填写）
    private var isFormValid: Bool {
        !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !serverPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (Int(serverPort) != nil && (1...65535).contains(Int(serverPort)!))
    }

    // MARK: - 保存节点

    /// 保存节点
    private func saveNode() {
        // 验证必填字段
        guard !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "请输入节点备注名称")
            return
        }

        guard !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "请输入服务器地址")
            return
        }

        guard let port = Int(serverPort), (1...65535).contains(port) else {
            showError(message: "端口号必须是 1-65535 之间的数字")
            return
        }

        guard !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showError(message: "请输入 UUID")
            return
        }

        // 创建节点
        var node = VPNNode(
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
            protocolType: protocolType,
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            serverPort: port,
            uuid: uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        // 设置协议特定配置
        if protocolType == .vmess {
            node.encryption = encryption
        } else if protocolType == .vless {
            node.encryption = .none
            if !flow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.flow = flow.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 设置传输配置
        node.transportType = transportType
        if transportType == .websocket {
            if !wsPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.wsPath = wsPath.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if !wsHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.wsHost = wsHost.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if transportType == .grpc {
            if !grpcServiceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.grpcServiceName = grpcServiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 设置 TLS 配置
        node.enableTLS = enableTLS
        if enableTLS {
            if !tlsServerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.tlsServerName = tlsServerName.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            node.allowInsecure = allowInsecure
            if !alpn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                node.alpn = alpn.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        // 保存节点
        VPNManager.shared.addNode(node)

        // 显示成功提示
        showSaveSuccess = true
    }

    /// 显示错误提示
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - 预览

struct AddNodeView_Previews: PreviewProvider {
    static var previews: some View {
        AddNodeView()
    }
}
