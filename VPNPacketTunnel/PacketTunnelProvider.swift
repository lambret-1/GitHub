//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//
//  用途：VPN 数据包隧道提供者，是 NetworkExtension 的核心类
//  职责：接收系统网络数据包，通过 VLESS 协议转发到代理服务器
//  架构：TCPStack（用户态TCP/IP协议栈）+ VLESSClient（VLESS协议客户端）
//

import NetworkExtension
import os.log

/// VPN 数据包隧道提供者
/// 继承自 NEPacketTunnelProvider，由系统在 VPN 启动时实例化
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 日志记录器

    /// 统一日志记录器，用于记录 VPN 扩展运行日志
    private let logger = OSLog(subsystem: "com.github.client.vpn", category: "PacketTunnel")

    // MARK: - 状态属性

    /// VPN 隧道是否正在运行
    private var isRunning = false

    /// 当前使用的节点配置（从 App Group 共享数据读取）
    private var currentNode: [String: Any]?

    /// TCP/IP 协议栈
    private var tcpStack: TCPStack?

    /// 活跃的 VLESS 客户端（按 TCP 连接索引）
    private var vlessClients: [ObjectIdentifier: VLESSClient] = [:]

    // MARK: - App Group 标识

    /// App Group 标识，用于与主 APP 共享数据
    /// 必须与主 APP 和 entitlements 中配置一致
    private let appGroupIdentifier = "group.com.github.client"

    // MARK: - 隧道生命周期

    /// 启动 VPN 隧道
    /// 系统在用户点击连接时调用此方法
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("🚀 开始启动 VPN 隧道", log: logger, type: .info)

        // 从启动选项或 App Group 读取节点配置
        loadNodeConfiguration { [weak self] node in
            guard let self = self else { return }

            self.currentNode = node

            // 初始化 TCP/IP 协议栈
            self.setupTCPStack()

            // 配置隧道网络设置
            let tunnelNetworkSettings = self.createTunnelNetworkSettings()

            // 设置隧道网络配置
            self.setTunnelNetworkSettings(tunnelNetworkSettings) { error in
                if let error = error {
                    os_log("❌ 设置隧道网络配置失败: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    completionHandler(error)
                    return
                }

                // 开始读取并处理数据包
                self.isRunning = true
                self.startPacketHandling()

                // 启动连接清理定时器
                self.startConnectionCleanupTimer()

                os_log("✅ VPN 隧道启动成功", log: self.logger, type: .info)
                completionHandler(nil)
            }
        }
    }

    /// 停止 VPN 隧道
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🛑 停止 VPN 隧道，原因: %{public}ld", log: logger, type: .info, reason.rawValue)

        // 停止数据包处理
        isRunning = false

        // 断开所有 VLESS 连接
        for (_, client) in vlessClients {
            client.disconnect()
        }
        vlessClients.removeAll()

        // 清理资源
        cleanupResources()

        os_log("✅ VPN 隧道已停止", log: logger, type: .info)
        completionHandler()
    }

    /// 处理来自系统的消息
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        if let message = String(data: messageData, encoding: .utf8) {
            os_log("📨 收到主 APP 消息: %{public}@", log: logger, type: .debug, message)

            if message == "getStatus" {
                let status = ["isRunning": isRunning, "node": currentNode ?? [:]] as [String: Any]
                if let data = try? JSONSerialization.data(withJSONObject: status) {
                    completionHandler?(data)
                    return
                }
            }
        }

        completionHandler?(nil)
    }

    // MARK: - TCP/IP 协议栈初始化

    /// 初始化 TCP/IP 协议栈
    private func setupTCPStack() {
        let stack = TCPStack()

        // 设置写回 IP 数据包的回调
        stack.writePacket = { [weak self] packet in
            self?.packetFlow.writePackets([packet], withProtocols: [AF_INET as NSNumber])
        }

        // 设置新连接回调
        stack.onNewConnection = { [weak self] connection, targetHost, targetPort in
            self?.handleNewConnection(connection: connection, targetHost: targetHost, targetPort: targetPort)
        }

        // 设置客户端数据回调
        stack.onClientData = { [weak self] connection, data in
            self?.handleClientData(connection: connection, data: data)
        }

        tcpStack = stack
    }

    // MARK: - 处理新连接

    /// 处理新的 TCP 连接
    private func handleNewConnection(connection: TCPConnection, targetHost: String, targetPort: UInt16) {
        guard let node = currentNode else { return }

        // 从节点配置中提取 VLESS 参数
        let serverAddress = node["node_server"] as? String ?? ""
        let serverPort = node["node_port"] as? Int ?? 443
        let uuid = node["node_uuid"] as? String ?? ""
        let transport = node["node_transport"] as? String ?? "tcp"
        let enableTLS = node["node_enable_tls"] as? Bool ?? true

        // 创建 VLESS 客户端配置
        let config = VLESSClientConfig(
            serverAddress: serverAddress,
            serverPort: UInt16(serverPort),
            uuid: uuid,
            transportType: transport,
            enableTLS: enableTLS,
            tlsServerName: node["node_ws_host"] as? String,
            wsHost: node["node_ws_host"] as? String,
            wsPath: node["node_ws_path"] as? String,
            flow: node["node_flow"] as? String
        )

        // 创建 VLESS 客户端
        let client = VLESSClient(config: config)

        // 设置数据回调
        client.onData = { [weak self, weak connection] data in
            guard let connection = connection else { return }
            // 将代理服务器返回的数据发送给客户端
            self?.tcpStack?.sendToClient(connection: connection, data: data)
        }

        client.onError = { [weak self] error in
            os_log("❌ VLESS 连接错误: %{public}@", log: self?.logger ?? .default, type: .error, error.localizedDescription)
        }

        // 保存客户端引用
        let connectionID = ObjectIdentifier(connection)
        vlessClients[connectionID] = client
        connection.proxyConnection = nil // 使用 VLESSClient 管理连接

        // 建立连接
        client.connect(targetHost: targetHost, targetPort: targetPort)
    }

    // MARK: - 处理客户端数据

    /// 处理从客户端收到的数据
    private func handleClientData(connection: TCPConnection, data: Data) {
        let connectionID = ObjectIdentifier(connection)
        if let client = vlessClients[connectionID] {
            client.send(data)
        }
    }

    // MARK: - 创建隧道网络设置

    /// 创建隧道网络设置
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // 远程服务器地址（占位，实际代理由用户态协议栈处理）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.0.0.1")

        // 配置 IPv4 地址
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])

        // 配置路由：使用默认路由（捕获所有流量）
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]

        // 排除局域网地址（局域网直连，不走代理）
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0")
        ]

        settings.ipv4Settings = ipv4Settings

        // 配置 DNS 服务器
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""] // 空字符串表示匹配所有域名
        settings.dnsSettings = dnsSettings

        // 设置 MTU
        settings.mtu = 1400

        return settings
    }

    // MARK: - 数据包处理

    /// 开始处理数据包
    private func startPacketHandling() {
        Task.detached { [weak self] in
            guard let self = self else { return }

            while self.isRunning {
                do {
                    // 读取系统发来的数据包
                    let packets = try await self.packetFlow.readPackets()

                    for (packetData, protocolNumber) in zip(packets.0, packets.1) {
                        // 只处理 IPv4 数据包（协议号 AF_INET = 2）
                        if protocolNumber.intValue == AF_INET {
                            self.tcpStack?.processPacket(packetData)
                        }
                    }
                } catch {
                    os_log("❌ 读取数据包失败: %{public}@", log: self.logger, type: .error, error.localizedDescription)
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }
            }
        }
    }

    // MARK: - 连接清理定时器

    /// 启动连接清理定时器
    private func startConnectionCleanupTimer() {
        Task.detached { [weak self] in
            guard let self = self else { return }

            while self.isRunning {
                try? await Task.sleep(nanoseconds: 60_000_000_000) // 60 秒
                self.tcpStack?.cleanupTimeoutConnections(timeout: 300)

                // 清理已断开的 VLESS 客户端
                let keysToRemove = self.vlessClients.keys.filter { key in
                    // 简单清理：如果对应的 TCPConnection 已不存在，则移除
                    return false // 暂时保留，由 TCPStack 清理时处理
                }
                for key in keysToRemove {
                    self.vlessClients[key]?.disconnect()
                    self.vlessClients.removeValue(forKey: key)
                }
            }
        }
    }

    // MARK: - 从 App Group 加载节点配置

    /// 从 App Group 加载节点配置
    private func loadNodeConfiguration(completion: @escaping ([String: Any]?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                os_log("❌ 无法访问 App Group 共享数据", log: self.logger, type: .error)
                completion(nil)
                return
            }

            if let nodeData = sharedDefaults.data(forKey: "vpn_current_node") {
                if let node = try? JSONSerialization.jsonObject(with: nodeData) as? [String: Any] {
                    os_log("✅ 成功加载节点配置: %{public}@", log: self.logger, type: .debug, node["node_remark"] as? String ?? "未知节点")
                    completion(node)
                    return
                }
            }

            os_log("⚠️ 未找到节点配置", log: self.logger, type: .error)
            completion(nil)
        }
    }

    // MARK: - 清理资源

    /// 清理资源
    private func cleanupResources() {
        tcpStack = nil
        os_log("🧹 资源清理完成", log: logger, type: .debug)
    }
}
