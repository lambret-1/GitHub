//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//

import Foundation
import NetworkExtension
import XrayKit

// MARK: - 常量定义

private let kAppGroup标识 = "group.com.github.client"
private let kXray配置键 = "xray_config_json"
private let k日志目录名 = "vpn扩展日志"

// MARK: - 扩展文件日志器

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

    /// 普通日志（异步写入）
    func 记录(_ 消息: String) {
        let 行内容 = "[\(日期格式化器.string(from: Date()))] \(消息)\n"
        队列.async {
            self.写入(行内容)
        }
    }

    /// 关键路径日志（同步写入，进程被杀前一定落盘）
    func 关键记录(_ 消息: String) {
        let 行内容 = "[\(日期格式化器.string(from: Date()))] \(消息)\n"
        队列.sync {
            self.写入(行内容)
        }
    }

    /// 内部写文件
    private func 写入(_ 行内容: String) {
        guard let 目录 = self.容器目录?.appendingPathComponent(k日志目录名, isDirectory: true) else { return }
        do {
            try FileManager.default.createDirectory(at: 目录, withIntermediateDirectories: true)
            let 文件 = 目录.appendingPathComponent("隧道启动日志.log")
            if FileManager.default.fileExists(atPath: 文件.path) {
                let 文件句柄 = try FileHandle(forWritingTo: 文件)
                _ = try? 文件句柄.seekToEnd()
                try? 文件句柄.write(contentsOf: Data(行内容.utf8))
                try? 文件句柄.close()
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
        }
    }

    /// 重置日志文件（同步）
    func 重置() {
        队列.sync {
            guard let 文件 = self.容器目录?.appendingPathComponent(k日志目录名, isDirectory: true)
                .appendingPathComponent("隧道启动日志.log") else { return }
            try? FileManager.default.removeItem(at: 文件)
        }
    }
}

// MARK: - PacketTunnelProvider 主类

final class PacketTunnelProvider: NEPacketTunnelProvider {

    // MARK: - 属性

    private var xray已启动 = false

    private let 状态锁 = NSLock()

    private let 回调锁 = NSLock()
    private var 已回调 = false

    // MARK: - 初始化

    override init() {
        super.init()
        扩展文件日志器.shared.重置()
        扩展文件日志器.shared.关键记录("=== PacketTunnelProvider 进程初始化 init ===")
        扩展文件日志器.shared.关键记录("扩展进程标识：\(ProcessInfo.processInfo.processIdentifier)")
        转存C层崩溃日志()
    }

    private func 转存C层崩溃日志() {
        let 崩溃日志路径 = "/tmp/vpn_extension_crash.log"
        guard FileManager.default.fileExists(atPath: 崩溃日志路径),
              let 数据 = try? Data(contentsOf: URL(fileURLWithPath: 崩溃日志路径)),
              let 内容 = String(data: 数据, encoding: .utf8),
              !内容.isEmpty else { return }
        扩展文件日志器.shared.关键记录("⚠️ 检测到上一次进程崩溃记录：\n\(内容)")
        try? FileManager.default.removeItem(atPath: 崩溃日志路径)
    }

    private func 安全回调(_ 错误: Error?, completionHandler: @escaping (Error?) -> Void) {
        回调锁.lock()
        if 已回调 {
            回调锁.unlock()
            return
        }
        已回调 = true
        回调锁.unlock()

        DispatchQueue.main.async {
            completionHandler(错误)
        }
    }

    // MARK: - 启动隧道

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        扩展文件日志器.shared.关键记录("=== startTunnel 开始 ===")

        // 1. 读取 Xray JSON 配置
        guard let 配置字符串 = Self.读取Xray配置() else {
            let 错误 = NSError(
                domain: "VPNPacketTunnel",
                code: -1001,
                userInfo: [NSLocalizedDescriptionKey: "未读取到有效的 Xray 配置"]
            )
            扩展文件日志器.shared.关键记录("❌ 启动终止：未读取到 Xray 配置")
            self.安全回调(错误, completionHandler: completionHandler)
            return
        }
        扩展文件日志器.shared.关键记录("✅ Xray 配置读取成功，字节数：\(配置字符串.utf8.count)")

        // 2. JSON 语法预检
        guard let 配置数据 = 配置字符串.data(using: .utf8),
              let 配置对象 = try? JSONSerialization.jsonObject(with: 配置数据),
              let 配置字典 = 配置对象 as? [String: Any] else {
            let 错误 = NSError(
                domain: "VPNPacketTunnel",
                code: -1002,
                userInfo: [NSLocalizedDescriptionKey: "Xray 配置不是合法 JSON"]
            )
            扩展文件日志器.shared.关键记录("❌ 启动终止：Xray 配置 JSON 解析失败")
            self.安全回调(错误, completionHandler: completionHandler)
            return
        }

        let 出站数组 = 配置字典["outbounds"] as? [[String: Any]]
        扩展文件日志器.shared.关键记录("✅ JSON 语法校验通过，出站数量：\(出站数组?.count ?? 0)")

        // 3. 应用 TUN 网络设置
        let 网络设置 = Self.构造隧道网络设置()
        setTunnelNetworkSettings(网络设置) { [weak self] 设置错误 in
            guard let self = self else {
                DispatchQueue.main.async {
                    completionHandler(NSError(
                        domain: "VPNPacketTunnel",
                        code: -999,
                        userInfo: [NSLocalizedDescriptionKey: "扩展实例已释放"]
                    ))
                }
                return
            }

            if let 设置错误 = 设置错误 {
                扩展文件日志器.shared.关键记录("❌ setTunnelNetworkSettings 失败：\(设置错误.localizedDescription)")
                self.安全回调(设置错误, completionHandler: completionHandler)
                return
            }
            扩展文件日志器.shared.关键记录("✅ TUN 网络设置已生效")

            // 4. 获取 TUN 文件描述符
            guard let tun描述符 = self.获取TUN文件描述符() else {
                let 错误 = NSError(domain: "VPNPacketTunnel", code: -1003,
                                   userInfo: [NSLocalizedDescriptionKey: "获取 TUN 文件描述符失败"])
                扩展文件日志器.shared.关键记录("❌ 未找到可用的 utun 文件描述符")
                self.安全回调(错误, completionHandler: completionHandler)
                return
            }
            扩展文件日志器.shared.关键记录("✅ 获取到 TUN 文件描述符：\(tun描述符)")

            // 5. 后台启动 Xray
            扩展文件日志器.shared.关键记录("即将调用 XrayCore.start（config=\(配置字符串.utf8.count)字节, tunFd=\(tun描述符)）")
            DispatchQueue.global(qos: .userInitiated).async {
                扩展文件日志器.shared.关键记录("后台线程已启动，正在调用 StartXray C 函数...")
                let 启动结果 = XrayCore.shared.start(configJSON: 配置字符串, tunFd: tun描述符)
                扩展文件日志器.shared.关键记录("StartXray C 函数已返回，错误码：\(启动结果)")

                DispatchQueue.main.async {
                    guard 启动结果 == 0 else {
                        let 错误 = NSError(
                            domain: "VPNPacketTunnel",
                            code: Int(启动结果),
                            userInfo: [NSLocalizedDescriptionKey: "Xray 核心启动失败，错误码：\(启动结果)"]
                        )
                        扩展文件日志器.shared.关键记录("❌ StartXray 返回错误码：\(启动结果)")
                        self.安全回调(错误, completionHandler: completionHandler)
                        return
                    }

                    self.状态锁.lock()
                    self.xray已启动 = true
                    self.状态锁.unlock()

                    扩展文件日志器.shared.关键记录("✅ Xray 核心启动成功，隧道建立完成")
                    self.安全回调(nil, completionHandler: completionHandler)
                }
            }
        }
    }

    // MARK: - 停止隧道

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        扩展文件日志器.shared.关键记录("=== stopTunnel 被调用，原因码：\(reason.rawValue) ===")

        状态锁.lock()
        let 需要停止 = xray已启动
        状态锁.unlock()

        if 需要停止 {
            let 停止结果 = XrayCore.shared.stop()
            扩展文件日志器.shared.关键记录(停止结果 == 0 ? "✅ Xray 核心已停止" : "⚠️ StopXray 返回错误码：\(停止结果)")
            状态锁.lock()
            xray已启动 = false
            状态锁.unlock()
        } else {
            扩展文件日志器.shared.关键记录("Xray 未启动，无需停止")
        }

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

    private static func 读取Xray配置() -> String? {
        // 前置诊断：检查 App Group 容器是否可用
        if let 容器 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup标识) {
            扩展文件日志器.shared.关键记录("App Group 容器可用：\(容器.path)")
        } else {
            扩展文件日志器.shared.关键记录("❌ App Group 容器不可用！entitlements 或 Provisioning Profile 可能未配置 App Groups：\(kAppGroup标识)")
        }

        // 通道一：从 UserDefaults（App Group 共享）读取
        if let defaults = UserDefaults(suiteName: kAppGroup标识) {
            if let 配置 = defaults.string(forKey: kXray配置键),
               !配置.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                扩展文件日志器.shared.关键记录("从 UserDefaults 读取到 Xray 配置（\(配置.utf8.count) 字节）")
                return 配置
            } else {
                // 诊断：UserDefaults 中所有键，帮助排查是否写入了其他键名
                let 所有键 = defaults.dictionaryRepresentation().keys.filter { !$0.hasPrefix("NS") && !$0.hasPrefix("Apple") }
                扩展文件日志器.shared.关键记录("UserDefaults 中未找到键 \(kXray配置键)，现有自定义键：\(所有键.joined(separator: ", "))")
            }
        } else {
            扩展文件日志器.shared.关键记录("❌ 无法创建 UserDefaults(suiteName: \(kAppGroup标识))")
        }

        // 通道二：从共享文件读取（UserDefaults 为空时的回退）
        if let 容器 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroup标识) {
            let 文件 = 容器.appendingPathComponent("xray_config.json")
            扩展文件日志器.shared.关键记录("尝试从共享文件读取：\(文件.path)（存在：\(FileManager.default.fileExists(atPath: 文件.path))）")
            if let 内容 = try? String(contentsOf: 文件, encoding: .utf8),
               !内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                扩展文件日志器.shared.关键记录("从共享文件读取到 Xray 配置（UserDefaults 为空，\(内容.utf8.count) 字节）")
                return 内容
            }
        }

        扩展文件日志器.shared.关键记录("App Group 中不存在键为 \(kXray配置键) 的配置或配置为空")
        return nil
    }

    // MARK: - 网络设置

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

    // MARK: - TUN 文件描述符

    private func 获取TUN文件描述符() -> Int32? {
        // 已知路径尝试（按优先级排序）
        let 已知路径列表: [(描述: String, 键路径: String, 对象: Any)] = [
            ("self.packetFlow.socket.fileDescriptor", "packetFlow.socket.fileDescriptor", self),
            ("packetFlow.socket.fileDescriptor", "socket.fileDescriptor", packetFlow),
            ("packetFlow._socket.fileDescriptor", "_socket.fileDescriptor", packetFlow),
            ("packetFlow.interface.fileDescriptor", "interface.fileDescriptor", packetFlow),
            ("packetFlow._interface.fileDescriptor", "_interface.fileDescriptor", packetFlow),
            ("packetFlow.tunInterface.fileDescriptor", "tunInterface.fileDescriptor", packetFlow),
            ("packetFlow._tunInterface.fileDescriptor", "_tunInterface.fileDescriptor", packetFlow),
            ("packetFlow.fileDescriptor", "fileDescriptor", packetFlow),
            ("packetFlow._fileDescriptor", "_fileDescriptor", packetFlow),
        ]

        for (描述, 键路径, 对象) in 已知路径列表 {
            if let num = safe_valueForKeyPath(键路径, 对象 as AnyObject) as? NSNumber {
                let fd = num.int32Value
                if fd > 0 {
                    扩展文件日志器.shared.关键记录("✅ KVC 路径 [\(描述)] 获取到 TUN fd=\(fd)")
                    return fd
                }
            }
        }

        // 单键尝试：先获取 socket/interface 对象，再从对象获取 fileDescriptor
        let 单键列表 = ["socket", "_socket", "interface", "_interface", "tunInterface", "_tunInterface", "tun", "_tun"]
        for 键 in 单键列表 {
            if let 对象 = safe_valueForKey(键, packetFlow) {
                扩展文件日志器.shared.关键记录("发现 packetFlow 属性 [\(键)]，类型：\(type(of: 对象))")
                if let num = safe_valueForKeyPath("fileDescriptor", 对象 as AnyObject) as? NSNumber {
                    let fd = num.int32Value
                    if fd > 0 {
                        扩展文件日志器.shared.关键记录("✅ 从属性 [\(键)].fileDescriptor 获取到 TUN fd=\(fd)")
                        return fd
                    }
                }
                // 尝试 _fileDescriptor
                if let num = safe_valueForKeyPath("_fileDescriptor", 对象 as AnyObject) as? NSNumber {
                    let fd = num.int32Value
                    if fd > 0 {
                        扩展文件日志器.shared.关键记录("✅ 从属性 [\(键)]._fileDescriptor 获取到 TUN fd=\(fd)")
                        return fd
                    }
                }
            }
        }

        // 运行时诊断：枚举 packetFlow 所有属性名，帮助定位正确的私有属性
        let 属性列表 = enumerate_property_names(packetFlow)
        扩展文件日志器.shared.关键记录("📋 packetFlow 运行时属性列表（\(属性列表.count)个）：\(属性列表.joined(separator: ", "))")

        // 对包含关键词的属性尝试获取 fileDescriptor
        let 关键词列表 = ["socket", "interface", "tun", "fd", "file", "descriptor", "flow", "pipe"]
        for 属性名 in 属性列表 {
            let 小写名 = 属性名.lowercased()
            guard 关键词列表.contains(where: { 小写名.contains($0) }) else { continue }
            guard !单键列表.contains(属性名) else { continue } // 已尝试过的跳过

            if let 对象 = safe_valueForKey(属性名, packetFlow) {
                扩展文件日志器.shared.关键记录("发现候选属性 [\(属性名)]，类型：\(type(of: 对象))")
                if let num = safe_valueForKeyPath("fileDescriptor", 对象 as AnyObject) as? NSNumber {
                    let fd = num.int32Value
                    if fd > 0 {
                        扩展文件日志器.shared.关键记录("✅ 从候选属性 [\(属性名)].fileDescriptor 获取到 TUN fd=\(fd)")
                        return fd
                    }
                }
            }
        }

        // 诊断：枚举 packetFlow 所有方法名（筛选可能相关的）
        let 方法列表 = enumerate_method_names(packetFlow)
        let 相关方法 = 方法列表.filter { 方法名 in
            let 小写 = 方法名.lowercased()
            return 小写.contains("socket") || 小写.contains("interface") || 小写.contains("tun")
                || 小写.contains("filedescriptor") || 小写.contains("fd") || 小写.contains("flow")
        }
        扩展文件日志器.shared.关键记录("📋 packetFlow 相关方法列表（\(相关方法.count)个）：\(相关方法.joined(separator: ", "))")

        扩展文件日志器.shared.关键记录("❌ KVC 未能获取 TUN fd（所有路径均不可用，已输出运行时诊断）")
        return nil
    }
}
