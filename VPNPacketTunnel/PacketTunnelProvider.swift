//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//
//  用途：VPN 数据包隧道提供者（Xray-core 集成版）
//  职责：管理 VPN 隧道生命周期，获取 TUN 文件描述符，启动 Xray 核心代理
//  核心原理：Xray Go 核心直接读写 TUN 设备，处理所有网络协议（TCP/UDP/VLESS/VMess/Trojan 等）
//  架构：主 App 生成 Xray JSON 配置 → App Group 共享 → 扩展读取配置 → StartXray(config, tunFd)
//

import NetworkExtension
import os.log
import XrayKit

// MARK: - 常量定义

/// App Group 标识，用于主 App 与扩展共享数据
private let kAppGroup = "group.com.github.client"

/// Xray 配置在 App Group UserDefaults 中的存储键
private let kXrayConfigKey = "xray_config_json"

/// 扩展日志在 App Group UserDefaults 中的存储键
private let kExtensionLogKey = "vpn_extension_logs"

/// 日志记录器
private let logger = Logger(subsystem: "com.github.client.vpn", category: "PacketTunnel")

// MARK: - 扩展日志写入 App Group

/// 将扩展日志写入 App Group，供主 App 读取
/// - Parameter message: 日志消息
private func logToAppGroup(_ message: String) {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    let timestamp = formatter.string(from: Date())
    let logLine = "[\(timestamp)] [VPN扩展] \(message)\n"

    if let defaults = UserDefaults(suiteName: kAppGroup) {
        var existing = defaults.string(forKey: kExtensionLogKey) ?? ""
        existing += logLine
        // 限制日志长度，最多保留 100KB
        if existing.count > 100 * 1024 {
            existing = String(existing.suffix(50 * 1024))
        }
        defaults.set(existing, forKey: kExtensionLogKey)
        defaults.synchronize()
    }
}

// MARK: - PacketTunnelProvider 主类

/// VPN 数据包隧道提供者
/// 继承 NEPacketTunnelProvider，由系统在 VPN 连接时实例化
class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 属性

    /// Xray 核心是否已启动
    private var xrayStarted = false

    /// 流量统计锁（多线程安全）
    private let statsLock = NSLock()

    // MARK: - init（扩展初始化）

    /// 扩展初始化方法
    /// 系统在实例化 PacketTunnelProvider 时调用
    override init() {
        super.init()

        // 读取 C 信号处理器记录的崩溃日志（如果有）
        if let crashLog = Self.readCrashLog() {
            logToAppGroup(crashLog)
            Self.clearCrashLog()
        }

        logToAppGroup("=== PacketTunnelProvider init 被调用 ===")
        logger.info("PacketTunnelProvider 初始化完成")
    }

    /// 读取 C 信号处理器记录的崩溃日志
    /// - Returns: 崩溃日志内容，没有则返回 nil
    private static func readCrashLog() -> String? {
        let crashLogPath = "/tmp/vpn_extension_crash.log"
        guard FileManager.default.fileExists(atPath: crashLogPath),
              let data = FileManager.default.contents(atPath: crashLogPath),
              let content = String(data: data, encoding: .utf8),
              !content.isEmpty else {
            return nil
        }
        return content
    }

    /// 清除崩溃日志文件
    private static func clearCrashLog() {
        let crashLogPath = "/tmp/vpn_extension_crash.log"
        try? FileManager.default.removeItem(atPath: crashLogPath)
    }

    // MARK: - startTunnel（启动 VPN 隧道）

    /// 启动 VPN 隧道
    /// 系统在用户点击连接时调用此方法
    /// - Parameters:
    ///   - options: 启动选项（可包含配置）
    ///   - completionHandler: 完成回调，nil 表示成功，Error 表示失败
    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        logger.info("startTunnel 被调用，开始启动 VPN 隧道")
        logToAppGroup("=== startTunnel 被调用 ===")

        // 1. 从启动选项或 App Group 读取 Xray 配置
        var configJson: String? = options?["config"] as? String

        if configJson == nil {
            // 从 App Group UserDefaults 读取配置
            if let defaults = UserDefaults(suiteName: kAppGroup) {
                configJson = defaults.string(forKey: kXrayConfigKey)
                if configJson != nil {
                    logger.info("从 App Group 读取到 Xray 配置（\(configJson!.count) 字节）")
                    logToAppGroup("从 App Group 读取到 Xray 配置（\(configJson!.count) 字节）")
                } else {
                    logToAppGroup("❌ App Group 中未找到 Xray 配置")
                }
            } else {
                logToAppGroup("❌ 无法初始化 App Group UserDefaults")
            }
        }

        guard let finalConfig = configJson, !finalConfig.isEmpty else {
            let error = NSError(
                domain: "XrayTunnel",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "未找到 Xray 配置，请在主 App 中配置节点"]
            )
            logger.error("启动失败：\(error.localizedDescription)")
            logToAppGroup("❌ 启动失败：未找到 Xray 配置")
            completionHandler(error)
            return
        }

        // 打印配置前 200 字符用于调试
        let configPreview = String(finalConfig.prefix(200))
        logToAppGroup("配置预览：\(configPreview)...")

        // 2. 配置虚拟 TUN 网卡网络设置
        let settings = createTunnelNetworkSettings()
        logToAppGroup("网络设置已创建")

        // 3. 应用网络设置
        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                logger.error("设置网络配置失败：\(error.localizedDescription)")
                logToAppGroup("❌ 设置网络配置失败：\(error.localizedDescription)")
                completionHandler(error)
                return
            }

            logger.info("网络配置应用成功")
            logToAppGroup("✅ 网络配置应用成功")

            // 4. 获取 TUN 设备文件描述符
            guard let tunFd = self.getTunnelFileDescriptor() else {
                let error = NSError(
                    domain: "XrayTunnel",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "获取 TUN 文件描述符失败"]
                )
                logger.error("启动失败：\(error.localizedDescription)")
                logToAppGroup("❌ 获取 TUN 文件描述符失败")
                completionHandler(error)
                return
            }

            logger.info("获取到 TUN 文件描述符：\(tunFd)")
            logToAppGroup("✅ 获取到 TUN 文件描述符：\(tunFd)")

            // 5. 启动 Xray 核心（通过 XrayKit 动态框架调用）
            logToAppGroup("正在启动 Xray 核心...")
            let result = XrayCore.shared.start(configJSON: finalConfig, tunFd: Int32(tunFd))

            if result != 0 {
                let error = NSError(
                    domain: "XrayTunnel",
                    code: Int(result),
                    userInfo: [NSLocalizedDescriptionKey: "Xray 核心启动失败，错误码：\(result)"]
                )
                logger.error("Xray 启动失败，错误码：\(result)")
                logToAppGroup("❌ Xray 启动失败，错误码：\(result)")
                completionHandler(error)
                return
            }

            logger.info("Xray 核心启动成功")
            logToAppGroup("✅ Xray 核心启动成功")
            self.xrayStarted = true
            completionHandler(nil)
        }
    }

    // MARK: - stopTunnel（停止 VPN 隧道）

    /// 停止 VPN 隧道
    /// 系统在用户点击断开或 VPN 异常时调用
    /// - Parameters:
    ///   - reason: 停止原因
    ///   - completionHandler: 完成回调
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        logger.info("stopTunnel 被调用，原因：\(reason.rawValue)")
        logToAppGroup("=== stopTunnel 被调用，原因：\(reason.rawValue) ===")

        // 停止 Xray 核心（通过 XrayKit 动态框架调用）
        if xrayStarted {
            let result = XrayCore.shared.stop()
            if result != 0 {
                logger.error("StopXray 返回错误码：\(result)")
                logToAppGroup("❌ StopXray 返回错误码：\(result)")
            } else {
                logger.info("Xray 核心已停止")
                logToAppGroup("✅ Xray 核心已停止")
            }
            xrayStarted = false
        }

        completionHandler()
    }

    // MARK: - handleAppMessage（处理主 App 消息）

    /// 处理来自主 App 的消息
    /// 主 App 可通过 NETunnelProviderSession.sendProviderMessage 与扩展通信
    /// - Parameters:
    ///   - messageData: 消息数据
    ///   - completionHandler: 回复回调
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let message = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        logger.info("收到主 App 消息：\(message)")

        switch message {
        case "getStatus":
            // 返回 VPN 运行状态
            let status = xrayStarted ? "running" : "stopped"
            completionHandler?(Data(status.utf8))

        case "getVersion":
            // 返回 Xray 版本（通过 XrayKit 动态框架调用）
            let version = XrayCore.shared.getVersion()
            completionHandler?(Data(version.utf8))

        case "getStats":
            // 返回流量统计（查询 proxy 出站的统计，通过 XrayKit 动态框架调用）
            let stats = XrayCore.shared.queryStats(tag: "proxy")
            completionHandler?(Data(stats.utf8))

        default:
            logger.warning("未知消息类型：\(message)")
            completionHandler?(nil)
        }
    }

    // MARK: - sleep / wake（系统休眠/唤醒）

    /// 系统休眠时调用
    override func sleep(completionHandler: @escaping () -> Void) {
        logger.info("系统休眠")
        completionHandler()
    }

    /// 系统唤醒时调用
    override func wake() {
        logger.info("系统唤醒")
    }

    // MARK: - 私有方法

    /// 创建隧道网络配置
    /// - Returns: NEPacketTunnelNetworkSettings 网络设置对象
    private func createTunnelNetworkSettings() -> NEPacketTunnelNetworkSettings {
        // 远程服务器地址（占位，实际由 Xray 配置决定）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")

        // IPv4 配置：使用 Xray 常用的虚拟地址段 198.18.0.0/16
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()] // 所有流量走 VPN
        settings.ipv4Settings = ipv4

        // IPv6 配置（可选，用于支持 IPv6 网络）
        let ipv6 = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"], networkPrefixLengths: [64])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        // DNS 配置：使用公共 DNS，防止 DNS 泄漏
        // 注意：Xray 内部也有 DNS 配置，这里的 DNS 用于系统层面的域名解析
        settings.dnsSettings = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        settings.dnsSettings?.matchDomains = [""] // 匹配所有域名

        // MTU 设置：避免 VPN 隧道分片
        settings.mtu = 1500

        return settings
    }

    /// 获取 TUN 设备文件描述符
    ///
    /// 原理：扫描所有文件描述符，通过 getsockopt 获取接口名称，找到最高编号的 utun 设备
    /// 这是 WireGuard-Go、sing-box、Xray 等项目的标准做法
    ///
    /// - Returns: TUN 设备文件描述符，失败返回 nil
    private func getTunnelFileDescriptor() -> Int32? {
        var lastFd: Int32? = nil
        var buffer = [CChar](repeating: 0, count: Int(IFNAMSIZ))

        // 扫描 0-1023 范围内的所有文件描述符
        for fd: Int32 in 0..<1024 {
            var length = socklen_t(buffer.count)
            // SYSPROTO_CONTROL = 2, UTUN_OPT_IFNAME = 2
            if getsockopt(fd, 2, 2, &buffer, &length) == 0 {
                let interfaceName = String(cString: buffer)
                if interfaceName.hasPrefix("utun") {
                    lastFd = fd // 保留最高编号的 utun（当前 VPN 隧道）
                }
            }
        }

        if let fd = lastFd {
            return fd
        }

        // 备用方案：通过 KVC 获取 packetFlow 的 socket 文件描述符
        if let value = self.value(forKeyPath: "packetFlow.socket.fileDescriptor") as? Int32 {
            logger.info("通过 KVC 获取到 TUN fd：\(value)")
            return value
        }

        logger.error("无法获取 TUN 文件描述符")
        return nil
    }
}
