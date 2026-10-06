//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//
//  用途：VPN 数据包隧道提供者（ 重构版·第一期底层基座）
//  职责：建立 TUN 虚拟网卡、将系统网络栈接入 Xray 核心、管理隧道生命周期
//  架构：主 App 生成 Xray JSON 配置 → App Group 共享 → 扩展读取配置
//       → 应用网络设置 → 获取 TUN 文件描述符 → StartXray(config, tunFd)
//

import Foundation
import NetworkExtension
import XrayKit

// MARK: - 常量定义

/// App Group 标识，用于主 App 与扩展共享数据（必须与两端 entitlements 完全一致）
private let kAppGroup标识 = "group.com.github.client"

/// Xray 配置在 App Group UserDefaults 中的存储键
private let kXray配置键 = "xray_config_json"

/// 扩展共享日志目录（App Group 容器内）
private let k日志目录名 = "vpn扩展日志"

// MARK: - 扩展文件日志器

/// 扩展文件日志器（线程安全）
final class 扩展文件日志器 {
    static let shared = 扩展文件日志器()

    private let 队列 = DispatchQueue(label: "com.github.client.vpn.扩展日志队列", qos: .utility)
    private let 日期格式化器: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    private var 容器目录: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup标识)
    }

    private init() {}

    /// 写入一条启动链路日志
    func 记录(_ 消息: String) {
        let 行内容 = "[\(日期格式化器.string(from: Date()))] \(消息)\n"
        队列.async {
            guard let 目录 = self.容器目录?.appendingPathComponent(kLog目录名, isDirectory: true) else { return }
            do {
                try FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)
                let 文件 = 目录.appendingPathComponent("隧道启动日志.log")
                if FileManager.default.fileExists(atPath: 文件.path) {
                    let 文件句柄 = try FileHandle(forWritingTo: 文件)
                    _ = try? 文件句柄.seekToEnd()
                    try? 文件句柄.write(contentsOf: Data(行内容.utf8))
                    try? 文件句柄.close()
                    // 限制日志文件最大 200KB
                    if let 属性 = try? FileManager.default.attributesOfItem(atPath: 文件.path),
                       let 大小 = 属性[.size] as? Int, 大小 > 200 * 1024,
                       let 旧内容 = try? String(contentsOf: 文件, encoding: .utf8) {
                        let 保留内容 = String(旧内容.suffix(100 * 1024))
                        try? 保留内容.write(to: 文件, atomically: true, encoding: .utf8)
                    }
                } else {
                    try 行内容.write(to: 文件, atomically: true, encoding: .utf8)
                }
            } catch {
                // 文件日志写入失败时静默处理，不影响隧道主链路
            }
        }
    }

    /// 重置本次启动的日志文件（同步执行，避免和首次 记录 竞态）
    func 重置() {
        队列.sync {
            guard let 文件 = self.容器目录?.appendingPathComponent(k日志目录名, isDirectory: true)
                .appendingPathComponent("隧道启动日志.log") else { return }
            try? FileManager.default.removeItem(at: 文件)
        }
    }
}

// 兼容：原代码里用 目录名 变量名，这里保证编译通过
private let kLog目录名 = k日志目录名

// MARK: - PacketTunnelProvider 主类

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 属性

    /// Xray 核心是否已成功启动
    private var xray已启动 = false

    /// 生命周期锁，防止重复启动/停止
    private let 状态锁 = NSLock()

    /// startTunnel 的 completionHandler 是否已被调用过
    private let 回调锁 = NSLock()
    private var 已回调 = false

    // MARK: - 初始化

    override init() {
        super.init()
        扩展文件日志器.shared.重置()
        扩展文件日志器.shared.记录("=== PacketTunnelProvider 进程初始化 init ===")
        扩展文件日志器.shared.记录("扩展进程标识：\(ProcessInfo.processInfo.processIdentifier)")
        转存C层崩溃日志()
    }

    /// 读取 C 信号处理器在上一次崩溃时写入的临时日志并转存到 App Group
    private func 转存C层崩溃日志() {
        let 崩溃日志路径 = "/tmp/vpn_extension_crash.log"
        guard FileManager.default.fileExists(atPath: 崩溃日志路径),
              let 数据 = try? Data(contentsOf: URL(fileURLWithPath: 崩溃日志路径)),
              let 内容 = String(data: 数据, encoding: .utf8),
              !内容.isEmpty else { return }
        扩展文件日志器.shared.记录("⚠️ 检测到上一次进程崩溃记录：\n\(内容)")
        try? FileManager.default.removeItem(atPath: 崩溃日志路径)
    }

    /// 保证 startTunnel 的 completionHandler 只被调用一次
    private func 安全回调(_ 错误: Error?, completionHandler: @escaping (Error?) -> Void) {
        回调锁.lock()
        if 已回调 {
            回调锁.unlock()
            return
        }
        已回调 = true
        回调锁.unlock()

        // 回主队列，稳妥起见
        DispatchQueue.main.async {
            completionHandler(错误)
        }
    }

    // MARK: - 启动隧道

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        扩展文件日志器.shared.记录("=== startTunnel 开始 ===")

        // 1. 读取 Xray JSON 配置
        guard let 配置字符串 = Self.读取Xray配置() else {
            let 错误 = NSError(
                domain: "VPNPacketTunnel",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "未读取到有效的 Xray 配置"]
            )
            扩展文件日志器.shared.记录("❌ 启动终止：未读取到 Xray 配置")
            安全回调(错误, completionHandler: completionHandler)
            return
        }
        扩展文件日志器.shared.记录("✅ Xray 配置读取成功，字节数：\(配置字符串.utf8.count)")

        // 2. JSON 语法预检
        guard let 配置数据 = 配置字符串.data(using: .utf8),
              let 配置对象 = try? JSONSerialization.jsonObject(with: 配置数据),
              let 配置字典 = 配置对象 as? [String: Any] else {
            let 错误 = NSError(
                domain: "VPNPacketTunnel",
                code: -1002,
                userInfo: [NSLocalizedDescriptionKey: "Xray 配置不是合法 JSON"]
            )
            扩展文件日志器.shared.记录("❌ 启动终止：Xray 配置 JSON 解析失败")
            安全回调(错误, completionHandler: completionHandler)
            return
        }

        let 出站数组 = 配置字典["outbounds"] as? [[String: Any]]
        扩展文件日志器.shared.记录("✅ JSON 语法校验通过，出站数量：\(出站数组?.count ?? 0)")

        // 3. 应用 TUN 网络设置
        let 网络设置 = Self.构造隧道网络设置()
        setTunnelNetworkSettings(网络设置) { [weak self] 设置错误 in
            guard let self = self else {
                安全回调(NSError(domain: "VPNPacketTunnel", code: -999,
                                 userInfo: [NSLocalizedDescriptionKey: "扩展实例已释放"]),
                        completionHandler: completionHandler)
                return
            }

            if let 设置错误 = 设置错误 {
                扩展文件日志器.shared.记录("❌ setTunnelNetworkSettings 失败：\(设置错误.localizedDescription)")
                安全回调(设置错误, completionHandler: completionHandler)
                return
            }
            扩展文件日志器.shared.记录("✅ TUN 网络设置已生效")

            // 4. 获取当前隧道对应的 utun 文件描述符
            guard let tun描述符 = self.获取TUN文件描述符() else {
                let 错误 = NSError(domain: "VPNPacketTunnel", code: -1003,
                                   userInfo: [NSLocalizedDescriptionKey: "获取 TUN 文件描述符失败"])
                扩展文件日志器.shared.记录("❌ 未找到可用的 utun 文件描述符")
                安全回调(错误, completionHandler: completionHandler)
                return
            }
            扩展文件日志器.shared.记录("✅ 获取到 TUN 文件描述符：\(tun描述符)")

            // 5. 在后台队列启动 Xray，避免阻塞 NetworkExtension 队列（看门狗会杀进程）
            DispatchQueue.global(qos: .userInitiated).async {
                let 启动结果 = XrayCore.shared.start(configJSON: 配置字符串, tunFd: tun描述符)

                // 回主队列处理状态
                DispatchQueue.main.async {
                    guard 启动结果 == 0 else {
                        let 错误 = NSError(
                            domain: "VPNPacketTunnel",
                            code: Int(启动结果),
                            userInfo: [NSLocalizedDescriptionKey: "Xray 核心启动失败，错误码：\(启动结果)"]
                        )
                        扩展文件日志器.shared.记录("❌ StartXray 返回错误码：\(启动结果)")
                        安全回调(错误, completionHandler: completionHandler)
                        return
                    }

                    self.状态锁.lock()
                    self.xray已启动 = true
                    self.状态锁.unlock()

                    扩展文件日志器.shared.记录("✅ Xray 核心启动成功，隧道建立完成")
                    安全回调(nil, completionHandler: completionHandler)
                }
            }
        }
    }

    // MARK: - 停止隧道

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        扩展文件日志器.shared.记录("=== stopTunnel 被调用，原因码：\(reason.rawValue) ===")

        状态锁.lock()
        let 需要停止 = xray已启动
        状态锁.unlock()

        if 需要停止 {
            let 停止结果 = XrayCore.shared.stop()
            扩展文件日志器.shared.记录(停止结果 == 0 ? "✅ Xray 核心已停止" : "⚠️ StopXray 返回错误码：\(停止结果)")
            状态锁.lock()
            xray已启动 = false
            状态锁.unlock()
        } else {
            扩展文件日志器.shared.记录("Xray 未启动，无需停止")
        }

        // 清空网络设置，避免残留
        setTunnelNetworkSettings(nil) { 清空错误 in
            if let 清空错误 = 清空错误 {
                扩展文件日志器.shared.记录("⚠️ 清空网络设置失败：\(清空错误.localizedDescription)")
            } else {
                扩展文件日志器.shared.记录("✅ 网络设置已清空")
            }
            completionHandler()
        }
    }

    // MARK: - 主 App 消息通道

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        guard let 消息 = String(data: messageData, encoding: .utf8) else {
            completionHandler?(nil)
            return
        }

        扩展文件日志器.shared.记录("收到主 App 消息：\(消息)")

        switch 消息 {
        case "getStatus":
            状态锁.lock()
            let 运行中 = xray已启动
            状态锁.unlock()
            completionHandler?(Data((运行中 ? "running" : "stopped").utf8))
        case "getVersion":
            completionHandler?(Data(XrayCore.shared.getVersion().utf8))
        case "getStats":
            completionHandler?(Data(XrayCore.shared.queryStats(tag: "proxy").utf8))
        default:
            completionHandler?(nil)
        }
    }

    // MARK: - 系统休眠/唤醒

    override func sleep(completionHandler: @escaping () -> Void) {
        扩展文件日志器.shared.记录("系统进入休眠")
        completionHandler()
    }

    override func wake() {
        扩展文件日志器.shared.记录("系统已唤醒")
    }

    // MARK: - 配置读取

    /// 从 App Group UserDefaults 读取 Xray 配置
    private static func 读取Xray配置() -> String? {
        // 主路径：UserDefaults
        if let defaults = UserDefaults(suiteName: kAppGroup标识),
           let 配置 = defaults.string(forKey: kXray配置键),
           !配置.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 配置
        }

        // 兜底：文件（跨进程更稳，主 App 若同时写了文件就能读到）
        if let 容器 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup标识) {
            let 文件 = 容器.appendingPathComponent("xray_config.json")
            if let 内容 = try? String(contentsOf: 文件, encoding: .utf8),
               !内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                扩展文件日志器.shared.记录("从文件读取到 Xray 配置（UserDefaults 为空）")
                return 内容
            }
        }

        扩展文件日志器.shared.记录("App Group 中不存在键为 \(kXray配置键) 的配置或配置为空")
        return nil
    }

    // MARK: - 网络设置

    /// 构造全局 TUN 网络设置（IPv4 + IPv6 + DNS + MTU）
    private static func 构造隧道网络设置() -> NEPacketTunnelNetworkSettings {
        let 设置 = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.254.0.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = []
        设置.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"], networkPrefixLengths: [64])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        设置.ipv6Settings = ipv6

        let dns设置 = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns设置.matchDomains = [""]
        设置.dnsSettings = dns设置

        设置.mtu = 1500
        return 设置
    }

    // MARK: - TUN 文件描述符（关键修复点）

    /// 获取当前 PacketTunnel 创建的 utun 文件描述符
    ///
    /// iOS 扩展进程中，真正的 utun fd 由 NetworkExtension framework 持有，
    /// **不在扩展进程的 fd 表里**，所以早期那种「遍历 0..1024 用 getsockopt 找 utun」
    /// 的方式在真机上拿不到系统 utun，会误取到别的 fd 或直接失败。
    ///
    /// 正确做法：通过 `packetFlow` 的私有 KVC 路径读取底层 socket fd。
    /// 注意：KVC 返回的是 NSNumber，**不能直接 `as? Int32`**，那样会失败。
    private func 获取TUN文件描述符() -> Int32? {
        // 主路径：self 上取 packetFlow 底层的 socket fd
        if let num = value(forKeyPath: "packetFlow.socket.fileDescriptor") as? NSNumber {
            let fd = num.int32Value
            if fd > 0 {
                扩展文件日志器.shared.记录("KVC(self) 获取到 TUN fd=\(fd)")
                return fd
            }
        }

        // 兼容路径：直接对 packetFlow 对象做 KVC
        if let num = packetFlow.value(forKeyPath: "socket.fileDescriptor") as? NSNumber {
            let fd = num.int32Value
            if fd > 0 {
                扩展文件日志器.shared.记录("KVC(packetFlow) 获取到 TUN fd=\(fd)")
                return fd
            }
        }

        // 再兜底：有些 iOS 版本 packetFlow 本身就有 fileDescriptor
        if let num = packetFlow.value(forKeyPath: "fileDescriptor") as? NSNumber {
            let fd = num.int32Value
            if fd > 0 {
                扩展文件日志器.shared.记录("KVC(packetFlow.fileDescriptor) 获取到 TUN fd=\(fd)")
                return fd
            }
        }

        扩展文件日志器.shared.记录("KVC 未能获取 TUN fd")
        return nil
    }
}