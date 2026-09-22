//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//
//  用途：VPN 数据包隧道提供者，是 NetworkExtension 的核心类
//  职责：接收系统网络数据包，根据配置进行代理转发
//  第一期：实现基础的隧道启动/停止，数据包暂时直接转发（不做代理）
//  后续期：集成 VLESS/VMess 协议实现真正的代理
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

    // MARK: - App Group 标识

    /// App Group 标识，用于与主 APP 共享数据
    /// 必须与主 APP 和 entitlements 中配置一致
    private let appGroupIdentifier = "group.com.github.client"

    // MARK: - 隧道生命周期

    /// 启动 VPN 隧道
    /// 系统在用户点击连接时调用此方法
    /// - Parameters:
    ///   - options: 启动选项（可包含从主 APP 传递的额外配置）
    ///   - completionHandler: 启动完成回调，error 为 nil 表示成功
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        os_log("🚀 开始启动 VPN 隧道", log: logger, type: .info)

        // 从启动选项或 App Group 读取节点配置
        loadNodeConfiguration { [weak self] node in
            guard let self = self else { return }

            self.currentNode = node

            // 第一期：配置基础隧道网络设置
            // 暂时使用全流量捕获，但数据包直接转发（不做代理）
            // 后续期将根据节点配置设置真正的代理路由
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

                os_log("✅ VPN 隧道启动成功", log: self.logger, type: .info)
                completionHandler(nil)
            }
        }
    }

    /// 停止 VPN 隧道
    /// 系统在用户点击断开或 VPN 异常时调用此方法
    /// - Parameters:
    ///   - reason: 停止原因（用户手动断开、系统断开、连接丢失等）
    ///   - completionHandler: 停止完成回调
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        os_log("🛑 停止 VPN 隧道，原因: %{public}ld", log: logger, type: .info, reason.rawValue)

        // 停止数据包处理
        isRunning = false

        // 清理资源
        cleanupResources()

        os_log("✅ VPN 隧道已停止", log: logger, type: .info)
        completionHandler()
    }

    /// 处理来自系统的消息
    /// 主 APP 可以通过 NEPacketTunnelProvider 的 sendMessage 方法向扩展发送消息
    /// - Parameters:
    ///   - messageData: 消息数据
    ///   - completionHandler: 回复回调
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        // 第一期：简单处理消息，后续可扩展为实时控制（切换节点、更新配置等）
        if let message = String(data: messageData, encoding: .utf8) {
            os_log("📨 收到主 APP 消息: %{public}@", log: logger, type: .debug, message)

            // 处理特定消息
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

    // MARK: - 私有方法

    /// 创建隧道网络设置
    /// 第一期：配置基础的隧道网络设置，捕获所有流量
    /// 后续期：根据节点配置和路由规则设置更精确的网络配置
    /// - Returns: 隧道网络设置对象
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // 创建隧道网络设置，远程服务器地址暂时占位
        // 后续期将使用真实节点地址
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        // 配置 IPv4 地址
        // 使用虚拟网卡地址，这是 VPN 隧道的标准做法
        let ipv4Settings = NEIPv4Settings(addresses: ["10.0.0.2"], subnetMasks: ["255.255.255.0"])

        // 配置路由：第一期使用默认路由（捕获所有流量）
        // 后续期将根据分流规则设置精确路由
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
        // 第一期使用公共 DNS，后续期将支持自定义 DNS 和 DNS 分流
        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "1.1.1.1"])
        dnsSettings.matchDomains = [""] // 空字符串表示匹配所有域名
        settings.dnsSettings = dnsSettings

        // 设置 MTU（最大传输单元）
        // 1500 是标准以太网 MTU，VPN 隧道通常使用稍小的值避免分片
        settings.mtu = 1400

        return settings
    }

    /// 开始处理数据包
    /// 第一期：读取数据包后直接写回（不做代理，相当于直连）
    /// 后续期：将数据包通过 VLESS/VMess 协议发送到代理节点
    private func startPacketHandling() {
        // 使用后台队列处理数据包，避免阻塞主线程
        let packetQueue = DispatchQueue(label: "com.github.client.vpn.packet", qos: .userInitiated)

        packetQueue.async { [weak self] in
            guard let self = self else { return }

            while self.isRunning {
                // 读取系统发来的数据包
                // 一次最多读取 10 个数据包，提高处理效率
                let packets = self.packetFlow.readPackets()

                for (packetData, protocolNumber) in packets {
                    // 第一期：直接将数据包写回（不做代理）
                    // 后续期：在这里实现协议代理逻辑
                    self.packetFlow.writePackets([packetData], withProtocols: [protocolNumber])
                }
            }
        }
    }

    /// 从 App Group 加载节点配置
    /// 主 APP 将节点配置存储在 App Group 共享的 UserDefaults 中
    /// - Parameter completion: 加载完成回调，返回节点配置字典
    private func loadNodeConfiguration(completion: @escaping ([String: Any]?) -> Void) {
        // 在后台队列读取，避免阻塞
        DispatchQueue.global(qos: .userInitiated).async {
            // 通过 App Group 获取共享 UserDefaults
            guard let sharedDefaults = UserDefaults(suiteName: self.appGroupIdentifier) else {
                os_log("❌ 无法访问 App Group 共享数据", log: self.logger, type: .error)
                completion(nil)
                return
            }

            // 读取当前选中的节点配置
            if let nodeData = sharedDefaults.data(forKey: "vpn_current_node") {
                if let node = try? JSONSerialization.jsonObject(with: nodeData) as? [String: Any] {
                    os_log("✅ 成功加载节点配置: %{public}@", log: self.logger, type: .debug, node["remark"] as? String ?? "未知节点")
                    completion(node)
                    return
                }
            }

            os_log("⚠️ 未找到节点配置", log: self.logger, type: .warning)
            completion(nil)
        }
    }

    /// 清理资源
    /// 在 VPN 隧道停止时调用，释放所有占用的资源
    private func cleanupResources() {
        // 第一期：暂无特殊资源需要清理
        // 后续期：需要关闭网络连接、清理协议栈、释放内存等
        os_log("🧹 资源清理完成", log: logger, type: .debug)
    }
}
