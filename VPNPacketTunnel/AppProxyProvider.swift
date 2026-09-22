//
//  AppProxyProvider.swift
//  VPNPacketTunnel
//
//  用途：应用代理提供者，是 NetworkExtension 的核心类
//  职责：接收应用网络流量，通过 VLESS 协议转发到代理节点
//  参考：LightBrowser 项目的成功实现
//

import NetworkExtension
import os.log

/// 应用代理提供者
/// 继承自 NEAppProxyProvider，由系统在 VPN 启动时实例化
class AppProxyProvider: NEAppProxyProvider {

    // MARK: - 日志记录器

    /// 统一日志记录器
    private let logger = OSLog(subsystem: "com.github.client.vpn", category: "AppProxy")

    // MARK: - 配置属性

    /// VLESS 节点配置（从 providerConfiguration 读取）
    private var vlessConfig: [String: Any] = [:]

    /// 是否使用 VLESS 代理
    private var useVLESS = true

    // MARK: - 代理生命周期

    /// 启动代理
    override func startProxy(options: [String: Any]? = nil) async throws {
        os_log("🚀 开始启动应用代理", log: logger, type: .info)

        // 从启动选项读取配置
        if let options = options {
            useVLESS = options["useVLESS"] as? Bool ?? true
            vlessConfig = options["vlessConfig"] as? [String: Any] ?? [:]
        }

        // 如果 options 中没有配置，从 App Group 读取
        if vlessConfig.isEmpty {
            vlessConfig = loadNodeFromAppGroup()
        }

        os_log("✅ 应用代理启动成功，VLESS: %{public}@", log: logger, type: .info, useVLESS ? "启用" : "禁用")
    }

    /// 停止代理
    override func stopProxy(with reason: NEProviderStopReason) async {
        os_log("🛑 停止应用代理，原因: %{public}ld", log: logger, type: .info, reason.rawValue)
    }

    // MARK: - 流量处理

    /// 处理新的 TCP 流量
    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        guard let tcpFlow = flow as? NEAppProxyTCPFlow else {
            return false
        }

        // 获取远程主机名
        let remoteHost: String
        if #available(iOS 14.2, *) {
            remoteHost = flow.remoteHostname ?? ""
        } else {
            remoteHost = ""
        }

        os_log("📡 新连接: %{public}@", log: logger, type: .debug, remoteHost)

        // 如果启用 VLESS，通过 VLESS 隧道转发
        if useVLESS, let config = parseVLESSConfig() {
            forwardViaVLESS(flow: tcpFlow, targetHost: remoteHost, targetPort: 443, config: config)
            return true
        }

        // 直连模式（不使用代理）
        return false
    }

    /// 处理新的 UDP 流量（暂时不支持，返回 false 表示直连）
    override func handleNewUDPFlow(_ flow: NEAppProxyUDPFlow, initialRemoteEndpoint remoteEndpoint: NWEndpoint) -> Bool {
        return false
    }

    // MARK: - VLESS 转发

    /// 通过 VLESS 隧道转发流量
    private func forwardViaVLESS(flow: NEAppProxyTCPFlow, targetHost: String, targetPort: UInt16, config: VLESSConfig) {
        let client = VLESSClient(config: config)

        client.connect(
            targetHost: targetHost,
            targetPort: targetPort,
            onData: { data in
                flow.write(data) { _ in }
            },
            onError: { error in
                os_log("❌ VLESS 错误: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                flow.closeReadWithError(nil)
                flow.closeWriteWithError(nil)
            },
            onConnected: {
                os_log("✅ VLESS 隧道建立成功: %{public}@:%d", log: self.logger, type: .debug, targetHost, targetPort)
                // 开始读取应用数据并发送到 VLESS 隧道
                self.continueReading(flow: flow, client: client)
            }
        )
    }

    /// 持续读取应用流量并发送到 VLESS 隧道
    private func continueReading(flow: NEAppProxyTCPFlow, client: VLESSClient) {
        flow.readData { data, _ in
            if let data = data, !data.isEmpty {
                client.send(data)
                self.continueReading(flow: flow, client: client)
            }
        }
    }

    // MARK: - 配置解析

    /// 解析 VLESS 配置
    private func parseVLESSConfig() -> VLESSConfig? {
        guard let uuid = vlessConfig["node_uuid"] as? String,
              let host = vlessConfig["node_server"] as? String,
              let port = vlessConfig["node_port"] as? Int else {
            return nil
        }

        return VLESSConfig(
            uuid: uuid,
            host: host,
            port: port,
            wsPath: "/",  // 暂时使用默认路径
            wsHost: nil,
            tls: vlessConfig["node_enable_tls"] as? Bool ?? false,
            name: vlessConfig["node_remark"] as? String ?? "VLESS节点"
        )
    }

    /// 从 App Group 加载节点配置
    private func loadNodeFromAppGroup() -> [String: Any] {
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.github.client"),
              let nodeData = sharedDefaults.data(forKey: "vpn_current_node"),
              let node = try? JSONSerialization.jsonObject(with: nodeData) as? [String: Any] else {
            return [:]
        }
        return node
    }
}
