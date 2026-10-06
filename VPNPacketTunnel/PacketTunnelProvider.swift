//
//  PacketTunnelProvider.swift
//  VPNPacketTunnel
//

import Foundation
import NetworkExtension
import XrayKit
import Darwin
import UIKit

// MARK: - 常量定义

private let kAppGroup标识 = "group.com.github.client"
private let kXray配置键 = "xray_config_json"
private let k日志目录名 = "vpn扩展日志"
private let k最大文件描述符: Int32 = 1024
private let kSYSPROTO_CONTROL: Int32 = 2
private let kUTUN_OPT_IFNAME: Int32 = 2
private let k接口名缓冲区大小 = 16
/// 心跳标记文件名（存在表示上次异常退出，正常停止时会删除）
private let k心跳文件名 = "vpn_heartbeat.plist"

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

    /// 内存监控定时器（定期输出内存使用，诊断jetsam）
    private var 内存监控定时器: Timer?
    private let 内存监控间隔: TimeInterval = 10.0

    // MARK: - 初始化

    override init() {
        super.init()
        扩展文件日志器.shared.重置()
        扩展文件日志器.shared.关键记录("=== PacketTunnelProvider 进程初始化 init ===")
        扩展文件日志器.shared.关键记录("扩展进程标识：\(ProcessInfo.processInfo.processIdentifier)")
        转存C层崩溃日志()
        检测上次异常退出()
    }

    /// 检测上次是否异常退出（jetsam内存压力杀进程/SIGKILL/崩溃等无法捕获信号的情况）
    /// 原理：startTunnel成功后创建心跳文件，stopTunnel正常停止时删除；
    ///       下次启动时心跳文件仍存在则说明上次异常退出
    private func 检测上次异常退出() {
        guard let 容器 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kAppGroup标识
        ) else { return }

        let 心跳文件 = 容器.appendingPathComponent(k心跳文件名)

        guard FileManager.default.fileExists(atPath: 心跳文件.path) else { return }

        // 读取心跳文件中的启动时间
        let 上次启动时间: String
        if let 数据 = try? Data(contentsOf: 心跳文件),
           let 字典 = try? PropertyListSerialization.propertyList(from: 数据, format: nil) as? [String: Any],
           let 时间 = 字典["启动时间"] as? String {
            上次启动时间 = 时间
        } else {
            上次启动时间 = "未知"
        }

        扩展文件日志器.shared.关键记录("⚠️ 检测到上次进程异常退出（启动时间：\(上次启动时间)），可能原因：内存压力(jetsam)/系统杀进程/SIGKILL/Xray内部崩溃")

        // 写入崩溃日志到App Group
        let 崩溃内容 = """
        检测到VPN扩展进程异常退出（无信号捕获记录）
        上次启动时间: \(上次启动时间)
        可能原因:
        1. 内存压力(jetsam) - speedtest大流量时内存占用过高被系统杀死
        2. 系统主动杀进程 - 设备低内存/省电策略
        3. SIGKILL - 系统强制终止，无法捕获信号
        4. Xray核心内部崩溃 - Go运行时panic未传递到扩展信号处理器
        说明: 此日志由心跳标记机制检测生成，非信号处理器捕获。
        """
        写入崩溃日志到AppGroup(崩溃内容: 崩溃内容, 类型: "异常退出(无信号)", 原因: "VPN扩展进程意外终止，可能为内存压力(jetsam)或系统杀进程")

        // 删除心跳文件，避免重复记录
        try? FileManager.default.removeItem(at: 心跳文件)
    }

    private func 转存C层崩溃日志() {
        let 崩溃日志路径 = "/tmp/vpn_extension_crash.log"
        guard FileManager.default.fileExists(atPath: 崩溃日志路径),
              let 数据 = try? Data(contentsOf: URL(fileURLWithPath: 崩溃日志路径)),
              let 内容 = String(data: 数据, encoding: .utf8),
              !内容.isEmpty else { return }

        扩展文件日志器.shared.关键记录("⚠️ 检测到上一次进程崩溃记录：\n\(内容)")

        // 将崩溃日志写入 App Group 共享目录，供主App崩溃日志列表读取
        写入崩溃日志到AppGroup(崩溃内容: 内容)

        try? FileManager.default.removeItem(atPath: 崩溃日志路径)
    }

    /// 将VPN扩展崩溃日志写入 App Group 共享目录（主App可读取）
    private func 写入崩溃日志到AppGroup(崩溃内容: String, 类型: String = "Signal", 原因: String = "VPN扩展进程异常终止") {
        guard let 容器 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kAppGroup标识
        ) else { return }

        // VPN扩展崩溃日志目录
        let 崩溃目录 = 容器.appendingPathComponent("vpn扩展崩溃日志", isDirectory: true)
        try? FileManager.default.createDirectory(at: 崩溃目录, withIntermediateDirectories: true)

        // 生成文件名：vpn_crash_YYYYMMDD_HHMMSS.log
        let 日期Formatter = DateFormatter()
        日期Formatter.dateFormat = "yyyyMMdd_HHmmss"
        let 文件名 = "vpn_crash_\(日期Formatter.string(from: Date())).log"
        let 文件URL = 崩溃目录.appendingPathComponent(文件名)

        // 设备信息
        let 设备 = UIDevice.current
        let 设备信息 = """
        设备型号: \(设备.model)
        系统版本: \(设备.systemName) \(设备.systemVersion)
        设备名称: \(设备.name)
        屏幕尺寸: \(UIScreen.main.bounds.size.width) x \(UIScreen.main.bounds.size.height)
        屏幕缩放: \(UIScreen.main.scale)
        """

        // 应用信息
        let 应用信息 = """
        应用名称: \(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "GitHub VPN")
        应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")
        构建版本: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知")
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")
        进程类型: VPN Network Extension
        """

        // 崩溃时间
        let 时间Formatter = DateFormatter()
        时间Formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let 崩溃时间 = 时间Formatter.string(from: Date())

        // 组装崩溃日志（与主App格式一致，标注来源为VPN扩展）
        let 日志内容 = """
        ========================================
        崩溃日志（VPN扩展）
        ========================================
        崩溃时间: \(崩溃时间)
        崩溃类型: \(类型)
        崩溃原因: \(原因)
        崩溃来源: PacketTunnelProvider (VPN Network Extension)

        ----------------------------------------
        设备信息
        ----------------------------------------
        \(设备信息)

        ----------------------------------------
        应用信息
        ----------------------------------------
        \(应用信息)

        ----------------------------------------
        C层崩溃信号记录
        ----------------------------------------
        \(崩溃内容)

        ----------------------------------------
        说明
        ----------------------------------------
        此日志由VPN扩展进程在崩溃后首次启动时生成，
        原始信号记录来自SignalHandler.c的/tmp/vpn_extension_crash.log。

        ========================================
        崩溃日志结束
        ========================================
        """

        // 写入文件
        try? 日志内容.write(to: 文件URL, atomically: true, encoding: .utf8)

        // 只保留最近20条，删除旧的
        清理旧崩溃日志(目录: 崩溃目录)
    }

    /// 清理旧的VPN扩展崩溃日志（只保留最近20条）
    private func 清理旧崩溃日志(目录: URL) {
        let 文件管理器 = FileManager.default
        guard let 文件列表 = try? 文件管理器.contentsOfDirectory(
            at: 目录,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let 崩溃文件 = 文件列表
            .filter { $0.lastPathComponent.hasPrefix("vpn_crash_") && $0.pathExtension == "log" }
            .sorted { (url1, url2) -> Bool in
                let 日期1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let 日期2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return 日期1 < 日期2
            }

        if 崩溃文件.count > 20 {
            let 待删除 = 崩溃文件.prefix(崩溃文件.count - 20)
            for 文件URL in 待删除 {
                try? 文件管理器.removeItem(at: 文件URL)
            }
        }
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
                    self.创建心跳文件()
                    self.启动内存监控定时器()
                    self.安全回调(nil, completionHandler: completionHandler)
                }
            }
        }
    }

    // MARK: - 停止隧道

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        let 原因名称 = Self.停止原因名称(reason)
        扩展文件日志器.shared.关键记录("=== stopTunnel 被调用，原因码：\(reason.rawValue)，原因：\(原因名称) ===")

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

        停止内存监控定时器()
        删除心跳文件()

        // 注意：不在此处调用 setTunnelNetworkSettings(nil)
        // 原因：系统在 stopTunnel 完成后会自动清理网络设置，
        //       手动调用会与系统清理流程冲突，导致 NEAgentErrorDomain 错误，
        //       进而可能使系统认为隧道未完全断开，出现"开关关闭不了"的问题。
        扩展文件日志器.shared.关键记录("stopTunnel 处理完成，等待系统自动清理网络设置")
        completionHandler()
    }

    /// 获取停止原因的可读名称
    private static func 停止原因名称(_ 原因: NEProviderStopReason) -> String {
        switch 原因 {
        case .none: return "无"
        case .userInitiated: return "用户主动断开"
        case .providerFailed: return "扩展失败"
        case .noNetworkAvailable: return "无可用网络"
        case .unrecoverableNetworkChange: return "不可恢复的网络变化"
        case .providerDisabled: return "扩展被禁用"
        case .authenticationCanceled: return "认证取消"
        case .configurationFailed: return "配置失败"
        case .idleTimeout: return "空闲超时"
        case .configurationDisabled: return "配置被禁用"
        case .configurationRemoved: return "配置被删除"
        case .superceded: return "被新配置取代"
        case .userSwitch: return "用户切换"
        case .connectionFailed: return "连接失败"
        case .sleep: return "设备睡眠"
        case .appUpdate: return "应用更新"
        @unknown default: return "未知(\(原因.rawValue))"
        }
    }

    // MARK: - 内存监控定时器（诊断jetsam）

    private func 启动内存监控定时器() {
        停止内存监控定时器()
        let 初始内存 = 获取当前内存使用()
        扩展文件日志器.shared.关键记录("💾 内存监控已启动（每\(内存监控间隔)秒输出一次），启动内存：\(初始内存)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.内存监控定时器 = Timer.scheduledTimer(withTimeInterval: self.内存监控间隔, repeats: true) { [weak self] _ in
                self?.输出内存使用()
            }
        }
    }

    private func 停止内存监控定时器() {
        DispatchQueue.main.async { [weak self] in
            self?.内存监控定时器?.invalidate()
            self?.内存监控定时器 = nil
        }
    }

    private func 输出内存使用() {
        let 内存信息 = 获取当前内存使用()
        扩展文件日志器.shared.记录("💾 内存使用：\(内存信息)")
    }

    // MARK: - 心跳文件管理（异常退出检测）

    /// 创建心跳文件（隧道启动成功后调用，包含启动时间）
    private func 创建心跳文件() {
        guard let 容器 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kAppGroup标识
        ) else { return }

        let 心跳文件 = 容器.appendingPathComponent(k心跳文件名)
        let 时间Formatter = DateFormatter()
        时间Formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let 启动时间 = 时间Formatter.string(from: Date())

        let 字典: [String: Any] = [
            "启动时间": 启动时间,
            "进程标识": ProcessInfo.processInfo.processIdentifier,
            "版本": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知"
        ]

        if let 数据 = try? PropertyListSerialization.data(fromPropertyList: 字典, format: .xml, options: 0) {
            try? 数据.write(to: 心跳文件, options: .atomic)
            扩展文件日志器.shared.记录("💓 心跳文件已创建（启动时间：\(启动时间)）")
        }
    }

    /// 删除心跳文件（隧道正常停止时调用）
    private func 删除心跳文件() {
        guard let 容器 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: kAppGroup标识
        ) else { return }

        let 心跳文件 = 容器.appendingPathComponent(k心跳文件名)
        if FileManager.default.fileExists(atPath: 心跳文件.path) {
            try? FileManager.default.removeItem(at: 心跳文件)
            扩展文件日志器.shared.记录("💓 心跳文件已删除（正常停止）")
        }
    }

    // MARK: - 内存监控

    /// 获取当前进程内存使用情况（用于诊断jetsam内存压力）
    private func 获取当前内存使用() -> String {
        var 任务信息 = mach_task_basic_info()
        var 计数 = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let 结果: kern_return_t = withUnsafeMutablePointer(to: &任务信息) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(计数)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &计数)
            }
        }

        guard 结果 == KERN_SUCCESS else { return "未知" }

        let 已用字节 = 任务信息.resident_size
        let 已用MB = Double(已用字节) / 1024.0 / 1024.0
        return String(format: "%.1f MB", 已用MB)
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

    /// 遍历进程文件描述符表，查找 utun 接口对应的 fd
    ///
    /// 原理：iOS NetworkExtension 未提供公开 API 获取 TUN fd，
    ///       KVC 私有路径在 iOS 16+ 已失效；
    ///       业界通用方案是遍历 fd 0~1024，通过 getsockopt(SYSPROTO_CONTROL, UTUN_OPT_IFNAME)
    ///       获取每个 socket 对应的接口名，匹配 utun 前缀。
    /// - Parameter 指定接口名: 可选，指定要匹配的接口名（如 "utun0"），不指定则匹配第一个 utun*
    /// - Returns: 匹配到的文件描述符，未找到返回 nil
    private func 遍历查找UTUN文件描述符(指定接口名: String? = nil) -> Int32? {
        var 缓冲区 = [CChar](repeating: 0, count: k接口名缓冲区大小)
        var 找到的fd: Int32? = nil

        for fd: Int32 in 0...k最大文件描述符 {
            var 长度 = socklen_t(缓冲区.count)
            let 结果 = getsockopt(fd, kSYSPROTO_CONTROL, kUTUN_OPT_IFNAME, &缓冲区, &长度)
            guard 结果 == 0 else { continue }

            let 接口名 = String(cString: 缓冲区)
            guard !接口名.isEmpty else { continue }

            if let 目标名 = 指定接口名 {
                if 接口名 == 目标名 {
                    扩展文件日志器.shared.关键记录("fd遍历：找到指定接口 [\(接口名)]，fd=\(fd)")
                    找到的fd = fd
                    break
                }
            } else if 接口名.hasPrefix("utun") {
                扩展文件日志器.shared.关键记录("fd遍历：找到 utun 接口 [\(接口名)]，fd=\(fd)")
                找到的fd = fd
                break
            }
        }

        if 找到的fd == nil {
            扩展文件日志器.shared.关键记录("fd遍历：遍历 0~\(k最大文件描述符) 未找到 utun 接口")
        }
        return 找到的fd
    }

    private func 获取TUN文件描述符() -> Int32? {
        // 方案一（优先）：遍历进程文件描述符表，查找 utun 接口
        // 这是 iOS 16+ 上最可靠的方案，KVC 私有路径已被 Apple 封堵
        扩展文件日志器.shared.关键记录("方案一：遍历 fd 表查找 utun 接口...")
        if let fd = 遍历查找UTUN文件描述符() {
            扩展文件日志器.shared.关键记录("✅ fd遍历方案获取到 TUN fd=\(fd)")
            return fd
        }

        // 方案二（回退）：KVC 私有路径尝试
        扩展文件日志器.shared.关键记录("方案二：KVC 私有路径尝试（回退方案）...")
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
                if let num = safe_valueForKeyPath("fileDescriptor", 对象 as AnyObject) as? NSNumber {
                    let fd = num.int32Value
                    if fd > 0 {
                        扩展文件日志器.shared.关键记录("✅ 从属性 [\(键)].fileDescriptor 获取到 TUN fd=\(fd)")
                        return fd
                    }
                }
                if let num = safe_valueForKeyPath("_fileDescriptor", 对象 as AnyObject) as? NSNumber {
                    let fd = num.int32Value
                    if fd > 0 {
                        扩展文件日志器.shared.关键记录("✅ 从属性 [\(键)]._fileDescriptor 获取到 TUN fd=\(fd)")
                        return fd
                    }
                }
            }
        }

        // 运行时诊断：枚举 packetFlow 所有属性名
        let 属性列表 = enumerate_property_names(packetFlow)
        扩展文件日志器.shared.关键记录("📋 packetFlow 运行时属性列表（\(属性列表.count)个）：\(属性列表.joined(separator: ", "))")

        扩展文件日志器.shared.关键记录("❌ 所有方案均未能获取 TUN fd（fd遍历 + KVC均失败）")
        return nil
    }
}
