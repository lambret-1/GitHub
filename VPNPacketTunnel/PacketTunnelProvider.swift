//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//
//  用途：VPN 数据包隧道提供者（Xray-core 重构版·第一期底层基座）
//  职责：建立 TUN 虚拟网卡、将系统网络栈接入 Xray 核心、管理隧道生命周期
//  架构：主 App 生成 Xray JSON 配置 → App Group 共享 → 扩展读取配置
//       → 应用网络设置 → 获取 TUN 文件描述符 → StartXray(config, tunFd)
//  重构要点（第一期）：
//    1. 移除基于 UserDefaults 字符串拼接的不可靠日志，改为 App Group 文件日志
//    2. 启动链路改为严格分段校验：配置 → 网络设置 → TUN 描述符 → Xray 核心
//    3. 失败必须回调具体错误，杜绝“连接中秒断且扩展日志为空”
//    4. 适配 iOS16+ NetworkExtension 看门狗，所有阻塞操作均放在异步回调内
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
/// 说明：扩展是独立进程，os_log 在主 App 端不可见；
///       第一期将所有关键节点写入 App Group 文件，保证“启动失败必有日志”。
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
    /// - Parameter 消息: 日志内容
    func 记录(_ 消息: String) {
        let 行内容 = "[\(日期格式化器.string(from: Date()))] \(消息)\n"
        队列.async {
            guard let 目录 = self.容器目录?.appendingPathComponent(k日志目录名, isDirectory: true) else { return }
            do {
                try FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)
                let 文件 = 目录.appendingPathComponent("隧道启动日志.log")
                if FileManager.default.fileExists(atPath: 文件.path) {
                    let 文件句柄 = try FileHandle(forWritingTo: 文件)
                    try? 文件句柄.seekToEnd()
                    try? 文件句柄.write(contentsOf: Data(行内容.utf8))
                    try? 文件句柄.close()
                    // 限制日志文件最大 200KB，超出后截断保留后 100KB
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

    /// 重置本次启动的日志文件
    func 重置() {
        队列.async {
            guard let 文件 = self.容器目录?.appendingPathComponent(k日志目录名, isDirectory: true)
                .appendingPathComponent("隧道启动日志.log") else { return }
            try? FileManager.default.removeItem(at: 文件)
        }
    }
}

// MARK: - PacketTunnelProvider 主类

/// VPN 数据包隧道提供者
/// 由系统在 VPN 连接时实例化，运行于独立的网络扩展进程
final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 属性

    /// Xray 核心是否已成功启动
    private var xray已启动 = false

    /// 生命周期锁，防止重复启动/停止
    private let 状态锁 = NSLock()

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
            completionHandler(错误)
            return
        }
        扩展文件日志器.shared.记录("✅ Xray 配置读取成功，字节数：\(配置字符串.utf8.count)")

        // 2. JSON 语法预检（不校验业务字段，业务字段交给 Xray 内核返回错误码）
        guard let 配置数据 = 配置字符串.data(using: .utf8),
              let 配置对象 = try? JSONSerialization.jsonObject(with: 配置数据),
              let 配置字典 = 配置对象 as? [String: Any] else {
            let 错误 = NSError(
                domain: "VPNPacketTunnel",
                code: -1002,
                userInfo: [NSLocalizedDescriptionKey: "Xray 配置不是合法 JSON"]
            )
            扩展文件日志器.shared.记录("❌ 启动终止：Xray 配置 JSON 解析失败")
            completionHandler(错误)
            return
        }

        let 出站数组 = 配置字典["outbounds"] as? [[String: Any]]
        扩展文件日志器.shared.记录("✅ JSON 语法校验通过，出站数量：\(出站数组?.count ?? 0)")

        // 3. 应用 TUN 网络设置（必须先 setTunnelNetworkSettings，系统才会创建 utun）
        let 网络设置 = Self.构造隧道网络设置()
        setTunnelNetworkSettings(网络设置) { [weak self] 设置错误 in
            guard let self = self else {
                completionHandler(NSError(domain: "VPNPacketTunnel", code: -999,
                                          userInfo: [NSLocalizedDescriptionKey: "扩展实例已释放"]))
                return
            }

            if let 设置错误 = 设置错误 {
                扩展文件日志器.shared.记录("❌ setTunnelNetworkSettings 失败：\(设置错误.localizedDescription)")
                completionHandler(设置错误)
                return
            }
            扩展文件日志器.shared.记录("✅ TUN 网络设置已生效")

            // 4. 获取当前隧道对应的 utun 文件描述符
            guard let tun描述符 = self.获取TUN文件描述符() else {
                let 错误 = NSError(domain: "VPNPacketTunnel", code: -1003,
                                   userInfo: [NSLocalizedDescriptionKey: "获取 TUN 文件描述符失败"])
                扩展文件日志器.shared.记录("❌ 未找到可用的 utun 文件描述符")
                completionHandler(错误)
                return
            }
            扩展文件日志器.shared.记录("✅ 获取到 TUN 文件描述符：\(tun描述符)")

            // 5. 启动 Xray 内核（Go 核心内部创建 tun inbound 并接管流量）
            let 启动结果 = XrayCore.shared.start(configJSON: 配置字符串, tunFd: tun描述符)
            guard 启动结果 == 0 else {
                let 错误 = NSError(
                    domain: "VPNPacketTunnel",
                    code: Int(启动结果),
                    userInfo: [NSLocalizedDescriptionKey: "Xray 核心启动失败，错误码：\(启动结果)"]
                )
                扩展文件日志器.shared.记录("❌ StartXray 返回错误码：\(启动结果)")
                completionHandler(错误)
                return
            }

            self.状态锁.lock()
            self.xray已启动 = true
            self.状态锁.unlock()

            扩展文件日志器.shared.记录("✅ Xray 核心启动成功，隧道建立完成")
            completionHandler(nil)
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
        completionHandler()
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

    /// 从启动选项或 App Group UserDefaults 读取 Xray 配置
    /// - Returns: 非空且合法的 JSON 字符串；读取失败返回 nil
    private static func 读取Xray配置() -> String? {
        guard let defaults = UserDefaults(suiteName: kAppGroup标识),
              let 配置 = defaults.string(forKey: kXray配置键),
              !配置.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            扩展文件日志器.shared.记录("App Group 中不存在键为 \(kXray配置键) 的配置或配置为空")
            return nil
        }
        return 配置
    }

    // MARK: - 网络设置

    /// 构造全局 TUN 网络设置（IPv4 + IPv6 + DNS + MTU）
    private static func 构造隧道网络设置() -> NEPacketTunnelNetworkSettings {
        let 设置 = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "240.0.0.1")

        // 虚拟 IPv4 地址段（198.18.0.0/15 为基准测试保留段，TUN 方案通用）
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.254.0.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        ipv4.excludedRoutes = []
        设置.ipv4Settings = ipv4

        // 虚拟 IPv6，默认全流量接管；设备无 IPv6 网络时系统会自动忽略
        let ipv6 = NEIPv6Settings(addresses: ["fd6e:a81b:704f:1211::1"], networkPrefixLengths: [64])
        ipv6.includedRoutes = [NEIPv6Route.default()]
        设置.ipv6Settings = ipv6

        // 系统层 DNS，真实解析由 Xray 内核 DNS 配置接管
        let dns设置 = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns设置.matchDomains = [""]
        设置.dnsSettings = dns设置

        设置.mtu = 1500
        return 设置
    }

    // MARK: - TUN 文件描述符

    /// 获取当前 PacketTunnel 创建的 utun 文件描述符
    ///
    /// 原理：setTunnelNetworkSettings 成功后，系统在本扩展进程内新建 utun；
    ///       扫描文件描述符，通过 getsockopt 的 UTUN_OPT_IFNAME 找到接口名以 utun 开头的 fd。
    ///       该实现与 sing-box、WireGuardKitGo 等 TUN 方案一致。
    /// - Returns: TUN 文件描述符；扫描与 KVC 兜底均失败时返回 nil
    private func 获取TUN文件描述符() -> Int32? {
        var 最新描述符: Int32?
        var 名称缓冲 = [CChar](repeating: 0, count: Int(IFNAMSIZ))

        for 描述符: Int32 in 0..<1024 {
            var 长度 = socklen_t(名称缓冲.count)
            // SYSPROTO_CONTROL = 2，UTUN_OPT_IFNAME = 2
            let 结果 = getsockopt(描述符, 2, 2, &名称缓冲, &长度)
            if 结果 == 0 {
                let 接口名 = String(cString: 名称缓冲)
                if 接口名.hasPrefix("utun") {
                    最新描述符 = 描述符
                    扩展文件日志器.shared.记录("扫描到 utun 接口：\(接口名)，fd=\(描述符)")
                }
            }
        }

        if let 描述符 = 最新描述符 {
            return 描述符
        }

        // 兜底：通过私有 KVC 路径读取 packetFlow 的 socket fd
        if let kvc描述符 = value(forKeyPath: "packetFlow.socket.fileDescriptor") as? Int32 {
            扩展文件日志器.shared.记录("扫描失败，使用 KVC 兜底获取 fd=\(kvc描述符)")
            return kvc描述符
        }

        return nil
    }
}
