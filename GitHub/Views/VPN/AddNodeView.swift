//
//  AddNodeView.swift
//  GitHub，
//

import SwiftUI

// MARK: - Alert 类型

private enum 节点页面Alert: Identifiable {
    case 保存成功(String)
    case 错误(String)

    var id: String {
        switch self {
        case .保存成功(let 名): return "success-\(名)"
        case .错误(let 文案): return "error-\(文案)"
        }
    }
}

// MARK: - 添加节点页面

struct AddNodeView: View {

    @Environment(\.dismiss) private var dismiss

    // MARK: - 表单状态

    @State private var remark: String = ""
    @State private var protocolType: VPNProtocolType = .vmess
    @State private var serverAddress: String = ""
    @State private var serverPort: String = "443"
    @State private var uuid: String = ""
    @State private var encryption: VPNEncryptionType = .auto
    @State private var transportType: VPNTransportType = .tcp
    @State private var wsPath: String = ""
    @State private var wsHost: String = ""
    @State private var grpcServiceName: String = ""
    @State private var enableTLS: Bool = false
    @State private var tlsServerName: String = ""
    @State private var allowInsecure: Bool = false
    @State private var alpn: String = ""
    @State private var flow: String = ""

    // MARK: - UI 状态

    /// 统一 alert 状态（替代原来的 showSaveSuccess + showError）
    @State private var activeAlert: 节点页面Alert?

    @State private var showTransportSettings = false
    @State private var showTLSSettings = false

    // MARK: - 视图主体

    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                if protocolType == .vmess {
                    vmessSettingsSection
                } else if protocolType == .vless {
                    vlessSettingsSection
                }
                transportSettingsSection
                tlsSettingsSection
            }
            .navigationTitle("添加节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { saveNode() }
                        .fontWeight(.medium)
                        .disabled(!isFormValid)
                }
            }
            .alert(item: $activeAlert) { alert in
                switch alert {
                case .保存成功(let 名):
                    return Alert(
                        title: Text("保存成功"),
                        message: Text("节点「\(名)」已添加"),
                        dismissButton: .default(Text("确定")) { dismiss() }
                    )
                case .错误(let 文案):
                    return Alert(
                        title: Text("错误"),
                        message: Text(文案),
                        dismissButton: .cancel(Text("确定"))
                    )
                }
            }
        }
    }

    // MARK: - 基础信息部分

    private var basicInfoSection: some View {
        Section(header: Text("基础信息")) {
            HStack {
                Text("备注").frame(width: 70, alignment: .leading)
                TextField("请输入节点备注名称", text: $remark)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }

            Picker(selection: $protocolType) {
                ForEach(VPNProtocolType.supportedCases) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Text("协议")
            }

            HStack {
                Text("服务器").frame(width: 70, alignment: .leading)
                TextField("域名或 IP 地址", text: $serverAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("端口").frame(width: 70, alignment: .leading)
                TextField("端口号", text: $serverPort)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("UUID").frame(width: 70, alignment: .leading)
                TextField("用户 UUID", text: $uuid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }
        }
    }

    // MARK: - VMess 设置

    private var vmessSettingsSection: some View {
        Section(header: Text("VMess 设置")) {
            Picker(selection: $encryption) {
                ForEach(VPNEncryptionType.allCases) { type in
                    Text(type.displayName).tag(type)
                }
            } label: {
                Text("加密方式")
            }
        }
    }

    // MARK: - VLESS 设置

    private var vlessSettingsSection: some View {
        Section(header: Text("VLESS 设置")) {
            HStack {
                Text("流控").frame(width: 70, alignment: .leading)
                TextField("可选，如 xtls-rprx-vision", text: $flow)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }

            Text("VLESS 协议默认不加密，依赖 TLS 或 Reality 保证安全")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 传输设置

    private var transportSettingsSection: some View {
        Section {
            Button(action: {
                withAnimation { showTransportSettings.toggle() }
            }) {
                HStack {
                    Text("传输设置").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showTransportSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if showTransportSettings {
                Picker(selection: $transportType) {
                    ForEach(VPNTransportType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                } label: {
                    Text("传输协议")
                }

                if transportType == .websocket {
                    HStack {
                        Text("WS 路径").frame(width: 80, alignment: .leading)
                        TextField("可选，如 /path", text: $wsPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("WS Host").frame(width: 80, alignment: .leading)
                        TextField("可选，伪装域名", text: $wsHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                    }
                }

                if transportType == .grpc {
                    HStack {
                        Text("gRPC 服务名").frame(width: 100, alignment: .leading)
                        TextField("可选，服务名称", text: $grpcServiceName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    // MARK: - TLS 设置

    private var tlsSettingsSection: some View {
        Section {
            Button(action: {
                withAnimation { showTLSSettings.toggle() }
            }) {
                HStack {
                    Text("TLS 设置").foregroundColor(.primary)
                    Spacer()
                    Image(systemName: showTLSSettings ? "chevron.up" : "chevron.down")
                        .foregroundColor(.gray)
                }
            }

            if showTLSSettings {
                Toggle("启用 TLS", isOn: $enableTLS)

                if enableTLS {
                    HStack {
                        Text("SNI").frame(width: 80, alignment: .leading)
                        TextField("可选，服务器名称", text: $tlsServerName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text("ALPN").frame(width: 80, alignment: .leading)
                        TextField("可选，如 h2,http/1.1", text: $alpn)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                    }

                    Toggle("跳过证书验证", isOn: $allowInsecure)

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

    private var isFormValid: Bool {
        let 端口合法 = Int(serverPort).map { (1...65535).contains($0) } ?? false
        return !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !serverPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && 端口合法
    }

    // MARK: - 保存节点

    private func saveNode() {
        guard !remark.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("请输入节点备注名称"); return
        }
        guard !serverAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("请输入服务器地址"); return
        }
        guard let port = Int(serverPort), (1...65535).contains(port) else {
            setError("端口号必须是 1-65535 之间的数字"); return
        }
        guard !uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            setError("请输入 UUID"); return
        }

        var node = VPNNode(
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines),
            protocolType: protocolType,
            serverAddress: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            serverPort: port,
            uuid: uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if protocolType == .vmess {
            node.encryption = encryption
        } else if protocolType == .vless {
            node.encryption = .none
            let 值 = flow.trimmingCharacters(in: .whitespacesAndNewlines)
            if !值.isEmpty { node.flow = 值 }
        }

        node.transportType = transportType
        if transportType == .websocket {
            let p = wsPath.trimmingCharacters(in: .whitespacesAndNewlines)
            let h = wsHost.trimmingCharacters(in: .whitespacesAndNewlines)
            if !p.isEmpty { node.wsPath = p }
            if !h.isEmpty { node.wsHost = h }
        }
        if transportType == .grpc {
            let s = grpcServiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !s.isEmpty { node.grpcServiceName = s }
        }

        node.enableTLS = enableTLS
        if enableTLS {
            let sni = tlsServerName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sni.isEmpty { node.tlsServerName = sni }
            node.allowInsecure = allowInsecure

            let alpn值 = alpn.trimmingCharacters(in: .whitespacesAndNewlines)
            if !alpn值.isEmpty {
                node.alpn = alpn值.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            }
        }

        // ⚠️ @MainActor 隔离：跳到主线程访问 VPNManager
        let 最终节点 = node
        Task { @MainActor in
            VPNManager.shared.addNode(最终节点)
            activeAlert = .保存成功(最终节点.remark)
        }
    }

    private func setError(_ 文案: String) {
        activeAlert = .错误(文案)
    }
}

// MARK: - 预览

struct AddNodeView_Previews: PreviewProvider {
    static var previews: some View {
        AddNodeView()
    }
}