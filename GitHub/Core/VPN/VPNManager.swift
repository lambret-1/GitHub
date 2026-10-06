//
//  VPNManager.swift
//  GitHub
//

import Foundation
import NetworkExtension
import Network
import UIKit
import Combine
import os.log

// MARK: - VPN 连接状态

enum VPNConnectionStatus {
    case invalid
    case disconnected
    case connecting
    case connected
    case reasserting
    case disconnecting
    case preparing
    case failed

    init(from status: NEVPNStatus) {
        switch status {
        case .invalid: self = .invalid
        case .disconnected: self = .disconnected
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .reasserting: self = .reasserting
        case .disconnecting: self = .disconnecting
        @unknown default: self = .invalid
        }
    }

    var isActive: Bool {
        self == .connecting || self == .connected || self == .reasserting || self == .preparing
    }

    var displayText: String {
        switch self {
        case .invalid: return "配置无效"
        case .disconnected: return "已断开"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .reasserting: return "重新连接中..."
        case .disconnecting: return "断开中..."
        case .preparing: return "准备中..."
        case .failed: return "连接失败"
        }
    }
}

// MARK: - VPN 流量统计

struct VPN流量统计 {
    var 上行字节: UInt64 = 0
    var 下行字节: UInt64 = 0
    var 上行速度: Double = 0
    var 下行速度: Double = 0
    var 连接时长: TimeInterval = 0
    var 最后更新时间: Date = Date()

    var 格式化上行: String { Self.格式化字节数(上行字节) }
    var 格式化下行: String { Self.格式化字节数(下行字节) }
    var 格式化上行速度: String { Self.格式化字节数(UInt64(上行速度)) + "/s" }
    var 格式化下行速度: String { Self.格式化字节数(UInt64(下行速度)) + "/s" }

    var 格式化连接时长: String {
        let 小时 = Int(连接时长) / 3600
        let 分钟 = (Int(连接时长) % 3600) / 60
        let 秒 = Int(连接时长) % 60
        return String(format: "%02d:%02d:%02d", 小时, 分钟, 秒)
    }

    static func 格式化字节数(_ 字节数: UInt64) -> String {
        let 值 = Double(字节数)
        if 值 < 1024 {
            return "\(Int(值)) B"
        } else if 值 < 1024 * 1024 {
            return String(format: "%.1f KB", 值 / 1024)
        } else if 值 < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", 值 / (1024 * 1024))
        } else {
            return String(format: "%.2f GB", 值 / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - VPN 日志条目

struct VPN日志条目: Identifiable, Equatable {
    let id: UUID
    let 时间: Date
    let 级别: VPN日志级别
    let 模块: String
    let 内容: String

    init(级别: VPN日志级别, 模块: String, 内容: String) {
        self.id = UUID()
        self.时间 = Date()
        self.级别 = 级别
        self.模块 = 模块
        self.内容 = 内容
    }
}

enum VPN日志级别: String, CaseIterable {
    case 调试 = "调试"
    case 信息 = "信息"
    case 警告 = "警告"
    case 错误 = "错误"

    var osLog级别: OSLogType {
        switch self {
        case .调试: return .debug
        case .信息: return .info
        case .警告: return .default
        case .错误: return .error
        }
    }
}

// MARK: - VPN 管理器

/// VPN 管理器
///
/// 注意：本类**没有**加 `@MainActor`。
/// 所有 `@Published` 属性的写入统一在主线程执行（内部已 `DispatchQueue.main.async` 派发）。
final class VPNManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = VPNManager()

    // MARK: - 常量

    private let appGroup标识 = "group.com.github.client"
    private let 扩展BundleID = "com.github.client.vpn"
    private let 配置标识 = "GitHub中文VPN"
    private let xray配置键 = "xray_config_json"
    private let 当前节点键 = "vpn_current_node"
    private let 节点文件名 = "vpn_nodes.json"
    private let 统计更新间隔: TimeInterval = 1.0
    private let 日志最大条数 = 500
    private let 扩展日志最大行数 = 100
    private let 测速最大并发 = 5

    // MARK: - 发布状态

    @Published var 当前连接状态: VPNConnectionStatus = .disconnected
    @Published var 流量统计: VPN流量统计 = VPN流量统计()
    @Published var 日志列表: [VPN日志条目] = []
    @Published var 最近错误: Error?
    @Published var 是否加载中: Bool = false

    /// VPN 配置是否已存在于系统
    @Published var VPN配置已存在: Bool = false

    /// 兼容旧 UI：是否需要创建 VPN 配置
    var 需要安装描述文件: Bool { !VPN配置已存在 }

    // MARK: - 内部属性

    private var 当前管理器: NETunnelProviderManager?
    private(set) var 节点列表: [VPNNode] = []
    private(set) var 当前节点: VPNNode?

    private var 统计定时器: Timer?
    private var 批量测速任务: Task<Void, Never>?

    private var 连接开始时间: Date?
    private var 上次上行字节: UInt64 = 0
    private var 上次下行字节: UInt64 = 0
    private var 上次统计时间: Date = Date()

    private let 日志记录器 = Logger(subsystem: "com.github.client", category: "VPN")

    // MARK: - 初始化

    private override init() {
        super.init()
        加载节点列表()
        加载当前节点()
        注册状态监听()
        首次启动写入默认节点()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.检测VPN配置状态()
        }
    }

    // MARK: - 首次启动写入默认节点

    private func 首次启动写入默认节点() {
        guard 节点列表.isEmpty else { return }

        // ⚠️ 演示用占位节点，请替换为你自己的节点信息
        var 默认节点 = VPNNode(
            remark: "🇺🇸 示例节点（请您替换）",
            protocolType: .vless,
            serverAddress: "example.com",
            serverPort: 443,
            uuid: "00000000-0000-0000-0000-000000000000"
        )
        默认节点.transportType = .tcp
        默认节点.enableTLS = true
        默认节点.tlsServerName = "example.com"

        节点列表.append(默认节点)
        保存节点列表()
        当前节点 = 默认节点
        保存当前节点()
        记录日志(级别: .信息, 模块: "初始化", 内容: "首次启动，已写入示例节点：\(默认节点.remark)")
    }

    // MARK: - 日志管理

    func 记录日志(级别: VPN日志级别, 模块: String, 内容: String) {
        let 条目 = VPN日志条目(级别: 级别, 模块: 模块, 内容: 内容)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.日志列表.insert(条目, at: 0)
            if self.日志列表.count > self.日志最大条数 {
                self.日志列表.removeLast(self.日志列表.count - self.日志最大条数)
            }
        }

        日志记录器.log(level: 级别.osLog级别, "\(模块): \(内容)")
    }

    func 清除日志() {
        DispatchQueue.main.async {
            self.日志列表.removeAll()
        }
    }

    func 读取扩展启动日志() {
        guard let 容器目录 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup标识
        ) else { return }

        let 日志文件 = 容器目录
            .appendingPathComponent("vpn扩展日志", isDirectory: true)
            .appendingPathComponent("隧道启动日志.log")

        guard FileManager.default.fileExists(atPath: 日志文件.path),
              let 内容 = try? String(contentsOf: 日志文件, encoding: .utf8),
              !内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            记录日志(级别: .警告, 模块: "扩展日志", 内容: "扩展启动日志为空或不存在")
            return
        }

        let 所有行 = 内容.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard !所有行.isEmpty else { return }

        let 保留行 = Array(所有行.suffix(扩展日志最大行数))
        let 条目列表: [VPN日志条目] = 保留行.reversed().map { 行 in
            VPN日志条目(级别: .调试, 模块: "扩展", 内容: 行)
        }

        let 总行数 = 所有行.count
        let 显示行数 = 保留行.count

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let 头内容 = "========== 扩展日志（共\(总行数)行，显示最近\(显示行数)行） =========="
            let 头 = VPN日志条目(级别: .信息, 模块: "扩展日志", 内容: 头内容)
            self.日志列表.insert(头, at: 0)
            self.日志列表.insert(contentsOf: 条目列表, at: 1)
            if self.日志列表.count > self.日志最大条数 {
                self.日志列表.removeLast(self.日志列表.count - self.日志最大条数)
            }
        }
    }

    // MARK: - 状态监听

    private func 注册状态监听() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpn状态变化通知(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    @objc private func vpn状态变化通知(_ 通知: Notification) {
        let 对象 = 通知.object
        let 新状态: VPNConnectionStatus
        if let 会话 = 对象 as? NETunnelProviderSession {
            新状态 = VPNConnectionStatus(from: 会话.status)
        } else if let 管理器 = 当前管理器 {
            新状态 = VPNConnectionStatus(from: 管理器.connection.status)
        } else {
            新状态 = .disconnected
        }

        let 旧状态 = 当前连接状态

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.当前连接状态 = 新状态
            self.onStatusChange?(新状态)
        }

        let 状态内容 = "\(旧状态.displayText) → \(新状态.displayText)"
        记录日志(级别: .信息, 模块: "状态", 内容: 状态内容)

        switch 新状态 {
        case .connected:
            连接开始时间 = Date()
            启动统计定时器()
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道连接成功")
        case .disconnected:
            停止统计定时器()
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道已断开")
            if 旧状态 == .connecting || 旧状态 == .preparing {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.读取扩展启动日志()
                }
            }
        case .failed:
            停止统计定时器()
            记录日志(级别: .错误, 模块: "连接", 内容: "隧道连接失败")
        default:
            break
        }
    }

    // MARK: - VPN 配置检测与权限

    func 检测VPN配置状态(完成: ((Bool) -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                let 内容 = "检测 VPN 配置失败：\(错误.localizedDescription)"
                self.记录日志(级别: .错误, 模块: "配置检测", 内容: 内容)
                DispatchQueue.main.async {
                    self.VPN配置已存在 = false
                    完成?(false)
                }
                return
            }

            let 匹配 = 管理器列表?.first(where: { 管理器 in
                guard let 协议配置 = 管理器.protocolConfiguration as? NETunnelProviderProtocol else {
                    return false
                }
                return 协议配置.providerBundleIdentifier == self.扩展BundleID
            })

            let 已存在 = 匹配 != nil

            DispatchQueue.main.async {
                self.VPN配置已存在 = 已存在
                if let 管理器 = 匹配 {
                    self.当前管理器 = 管理器
                    if let 会话 = 管理器.connection as? NETunnelProviderSession {
                        self.当前连接状态 = VPNConnectionStatus(from: 会话.status)
                    }
                }
                self.记录日志(级别: .信息, 模块: "配置检测", 内容: 已存在 ? "系统已存在 VPN 配置" : "系统暂无 VPN 配置")
                完成?(已存在)
            }
        }
    }

    /// 兼容旧 UI
    func 检测描述文件状态(完成: ((Bool) -> Void)? = nil) {
        检测VPN配置状态(完成: 完成)
    }

    func 请求VPN权限(完成: @escaping (Bool) -> Void) {
        记录日志(级别: .信息, 模块: "权限", 内容: "开始请求 VPN 权限...")

        let 临时管理器 = NETunnelProviderManager()
        let 临时协议 = NETunnelProviderProtocol()
        临时协议.providerBundleIdentifier = 扩展BundleID
        临时协议.serverAddress = "127.0.0.1"
        临时管理器.protocolConfiguration = 临时协议
        临时管理器.localizedDescription = "GitHub中文VPN 临时配置"
        临时管理器.isEnabled = false

        临时管理器.saveToPreferences { [weak self] 保存错误 in
            guard let self = self else { return }

            if let 保存错误 = 保存错误 {
                let 描述 = 保存错误.localizedDescription.lowercased()
                let 内容 = "请求 VPN 权限失败：\(保存错误.localizedDescription)"
                self.记录日志(级别: .错误, 模块: "权限", 内容: 内容)

                if 描述.contains("permission") || 描述.contains("denied") {
                    DispatchQueue.main.async {
                        self.VPN配置已存在 = false
                        完成(false)
                    }
                } else {
                    self.记录日志(级别: .信息, 模块: "权限", 内容: "保存临时配置返回非权限错误，视为已授权")
                    DispatchQueue.main.async { 完成(true) }
                }
            } else {
                self.记录日志(级别: .信息, 模块: "权限", 内容: "VPN 权限请求成功")
                临时管理器.removeFromPreferences { _ in
                    DispatchQueue.main.async { 完成(true) }
                }
            }
        }
    }

    func 跳转到设置页面() {
        guard let 设置URL = URL(string: UIApplication.openSettingsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(设置URL)
        }
    }

    // MARK: - 连接控制

    func 连接(完成: ((Error?) -> Void)? = nil) {
        记录日志(级别: .信息, 模块: "连接", 内容: "=== 开始连接 VPN ===")

        guard let 节点 = 当前节点 else {
            let 错误 = NSError(
                domain: "VPNManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "请先选择一个节点"]
            )
            DispatchQueue.main.async {
                self.最近错误 = 错误
                self.当前连接状态 = .failed
                完成?(错误)
            }
            return
        }

        let 节点信息 = "节点：\(节点.remark) (\(节点.serverAddress):\(节点.serverPort))"
        记录日志(级别: .信息, 模块: "连接", 内容: 节点信息)

        写入Xray配置到AppGroup(节点)

        DispatchQueue.main.async {
            self.当前连接状态 = .preparing
        }

        加载或创建VPN配置 { [weak self] 管理器, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                let 内容 = "VPN 配置加载/创建失败：\(错误.localizedDescription)"
                self.记录日志(级别: .错误, 模块: "连接", 内容: 内容)
                DispatchQueue.main.async {
                    self.最近错误 = 错误
                    self.当前连接状态 = .failed
                    完成?(错误)
                }
                return
            }

            guard let 管理器 = 管理器 else {
                let 错误 = NSError(
                    domain: "VPNManager",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: "VPN 管理器为空"]
                )
                DispatchQueue.main.async { 完成?(错误) }
                return
            }

            self.保存VPN配置(管理器: 管理器, 节点: 节点) { 保存成功, 保存错误 in
                guard 保存成功 else {
                    let 描述 = 保存错误?.localizedDescription ?? "未知错误"
                    let 内容 = "保存 VPN 配置失败：\(描述)"
                    self.记录日志(级别: .错误, 模块: "连接", 内容: 内容)
                    DispatchQueue.main.async {
                        self.最近错误 = 保存错误
                        self.当前连接状态 = .failed
                        完成?(保存错误)
                    }
                    return
                }

                do {
                    try 管理器.connection.startVPNTunnel()
                    self.记录日志(级别: .信息, 模块: "连接", 内容: "VPN 隧道启动命令已发送")
                    DispatchQueue.main.async { 完成?(nil) }
                } catch {
                    let 内容 = "启动 VPN 隧道失败：\(error.localizedDescription)"
                    self.记录日志(级别: .错误, 模块: "连接", 内容: 内容)
                    DispatchQueue.main.async {
                        self.最近错误 = error
                        self.当前连接状态 = .failed
                        完成?(error)
                    }
                }
            }
        }
    }

    private func 加载或创建VPN配置(完成: @escaping (NETunnelProviderManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                完成(nil, 错误)
                return
            }

            if let 匹配 = 管理器列表?.first(where: { 管理器 in
                guard let 协议配置 = 管理器.protocolConfiguration as? NETunnelProviderProtocol else {
                    return false
                }
                return 协议配置.providerBundleIdentifier == self.扩展BundleID
            }) {
                self.当前管理器 = 匹配
                self.记录日志(级别: .信息, 模块: "配置", 内容: "找到匹配的 VPN 配置，复用")
                完成(匹配, nil)
                return
            }

            if let 第一个 = 管理器列表?.first {
                self.当前管理器 = 第一个
                self.记录日志(级别: .信息, 模块: "配置", 内容: "使用第一个已有 VPN 配置")
                完成(第一个, nil)
                return
            }

            self.记录日志(级别: .信息, 模块: "配置", 内容: "未找到 VPN 配置，创建新配置")
            let 新管理器 = NETunnelProviderManager()
            新管理器.localizedDescription = self.配置标识
            self.当前管理器 = 新管理器
            完成(新管理器, nil)
        }
    }

    private func 保存VPN配置(
        管理器: NETunnelProviderManager,
        节点: VPNNode,
        完成: @escaping (Bool, Error?) -> Void
    ) {
        let 隧道协议: NETunnelProviderProtocol
        if let 现有 = 管理器.protocolConfiguration as? NETunnelProviderProtocol {
            隧道协议 = 现有
        } else {
            隧道协议 = NETunnelProviderProtocol()
        }

        隧道协议.providerBundleIdentifier = 扩展BundleID
        隧道协议.serverAddress = "\(节点.serverAddress):\(节点.serverPort)"
        隧道协议.providerConfiguration = [
            "node_server": 节点.serverAddress,
            "node_port": 节点.serverPort,
            "node_protocol": 节点.protocolType.rawValue
        ]

        管理器.protocolConfiguration = 隧道协议
        管理器.localizedDescription = 配置标识
        管理器.isEnabled = true

        管理器.saveToPreferences { [weak self] 保存错误 in
            if let 保存错误 = 保存错误 {
                完成(false, 保存错误)
                return
            }

            let 服务器描述 = 隧道协议.serverAddress ?? "未知"
            let 日志内容 = "VPN 配置保存成功，服务器：\(服务器描述)"
            self?.记录日志(级别: .信息, 模块: "配置", 内容: 日志内容)

            管理器.loadFromPreferences { 加载错误 in
                if let 加载错误 = 加载错误 {
                    let 警告内容 = "重新加载配置失败（不影响连接）：\(加载错误.localizedDescription)"
                    self?.记录日志(级别: .警告, 模块: "配置", 内容: 警告内容)
                }
                完成(true, nil)
            }
        }
    }

    func 断开() {
        记录日志(级别: .信息, 模块: "连接", 内容: "断开 VPN")
        当前管理器?.connection.stopVPNTunnel()
    }

    func 切换连接(完成: ((Error?) -> Void)? = nil) {
        if 当前连接状态.isActive {
            断开()
            完成?(nil)
        } else {
            连接(完成: 完成)
        }
    }

    // MARK: - 流量统计

    private func 启动统计定时器() {
        停止统计定时器()
        上次上行字节 = 0
        上次下行字节 = 0
        上次统计时间 = Date()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let timer = Timer(timeInterval: self.统计更新间隔, repeats: true) { [weak self] _ in
                self?.更新流量统计()
            }
            RunLoop.main.add(timer, forMode: .common)
            self.统计定时器 = timer
        }
    }

    private func 停止统计定时器() {
        DispatchQueue.main.async { [weak self] in
            self?.统计定时器?.invalidate()
            self?.统计定时器 = nil
        }
    }

    private func 更新流量统计() {
        guard let 管理器 = 当前管理器,
              let 会话 = 管理器.connection as? NETunnelProviderSession else { return }

        do {
            try 会话.sendProviderMessage(Data("getStats".utf8)) { [weak self] 响应数据 in
                guard let self = self,
                      let 数据 = 响应数据,
                      let 统计字符串 = String(data: 数据, encoding: .utf8) else { return }

                let 统计 = Self.解析Xray统计(统计字符串)
                let 上行 = 统计["uplink"] ?? 0
                let 下行 = 统计["downlink"] ?? 0

                let 现在 = Date()
                let 间隔 = max(0.001, 现在.timeIntervalSince(self.上次统计时间))

                let 上行速度 = Double(上行 &- self.上次上行字节) / 间隔
                let 下行速度 = Double(下行 &- self.上次下行字节) / 间隔

                self.上次上行字节 = 上行
                self.上次下行字节 = 下行
                self.上次统计时间 = 现在

                let 连接时长 = self.连接开始时间.map { 现在.timeIntervalSince($0) } ?? 0

                DispatchQueue.main.async {
                    self.流量统计 = VPN流量统计(
                        上行字节: 上行,
                        下行字节: 下行,
                        上行速度: max(0, 上行速度),
                        下行速度: max(0, 下行速度),
                        连接时长: 连接时长,
                        最后更新时间: 现在
                    )
                }
            }
        } catch {
            // 静默处理
        }
    }

    private static func 解析Xray统计(_ 字符串: String) -> [String: UInt64] {
        var 结果: [String: UInt64] = [:]
        let 键值对 = 字符串.components(separatedBy: .whitespaces)
        for 对 in 键值对 {
            let 部分 = 对.components(separatedBy: ":")
            guard 部分.count == 2, let 值 = UInt64(部分[1]) else { continue }
            结果[部分[0]] = 值
        }
        return 结果
    }

    func 重置流量统计() {
        上次上行字节 = 0
        上次下行字节 = 0
        上次统计时间 = Date()
        DispatchQueue.main.async {
            self.流量统计 = VPN流量统计()
        }
    }

    // MARK: - 节点管理

    func 添加节点(_ 节点: VPNNode) {
        guard !节点列表.contains(where: { $0.id == 节点.id }) else { return }
        节点列表.append(节点)
        保存节点列表()
        记录日志(级别: .信息, 模块: "节点", 内容: "添加节点：\(节点.remark)")
    }

    func 删除节点(_ 节点: VPNNode) {
        节点列表.removeAll { $0.id == 节点.id }
        if 当前节点?.id == 节点.id {
            当前节点 = nil
        }
        保存节点列表()
        记录日志(级别: .信息, 模块: "节点", 内容: "删除节点：\(节点.remark)")
    }

    func 批量删除节点(_ 节点数组: [VPNNode]) {
        let 待删除ID集合 = Set(节点数组.map { $0.id })
        for 节点 in 节点数组 {
            节点列表.removeAll { $0.id == 节点.id }
        }
        if let 当前 = 当前节点, 待删除ID集合.contains(当前.id) {
            当前节点 = nil
        }
        保存节点列表()
    }

    func 选择节点(_ 节点: VPNNode) {
        当前节点 = 节点
        保存当前节点()
        记录日志(级别: .信息, 模块: "节点", 内容: "选择节点：\(节点.remark)")
    }

    // MARK: - 节点测速

    func 测速节点(_ 节点: VPNNode, 完成: @escaping (Result<Int, Error>) -> Void) {
        let host = NWEndpoint.Host(节点.serverAddress)
        let port = NWEndpoint.Port(rawValue: UInt16(节点.serverPort)) ?? 443
        let connection = NWConnection(host: host, port: port, using: .tcp)
        let startTime = Date()
        let 节点ID = 节点.id

        let 锁 = NSLock()
        var 已完成 = false

        func 一次性完成(_ 结果: Result<Int, Error>) {
            锁.lock()
            if 已完成 { 锁.unlock(); return }
            已完成 = true
            锁.unlock()

            connection.cancel()

            if case .success(let 延迟) = 结果,
               let idx = self.节点列表.firstIndex(where: { $0.id == 节点ID }) {
                self.节点列表[idx].latency = 延迟
                self.保存节点列表()
            }
            完成(结果)
        }

        let 超时工作项 = DispatchWorkItem {
            一次性完成(.failure(NSError(
                domain: "VPNManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "连接超时（5秒）"]
            )))
        }

        connection.stateUpdateHandler = { 状态 in
            switch 状态 {
            case .ready:
                超时工作项.cancel()
                let 延迟 = Int(Date().timeIntervalSince(startTime) * 1000)
                一次性完成(.success(延迟))
            case .failed(let error):
                超时工作项.cancel()
                一次性完成(.failure(error))
            default:
                break
            }
        }

        connection.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: 超时工作项)
    }

    func 批量测速所有节点(
        节点: [VPNNode],
        进度: @escaping (Int, Int) -> Void,
        完成: @escaping () -> Void
    ) {
        let total = 节点.count
        guard total > 0 else { 完成(); return }

        批量测速任务?.cancel()
        批量测速任务 = Task { [weak self] in
            guard let self = self else { return }
            var 已完成 = 0

            await withTaskGroup(of: Void.self) { group in
                var 迭代器 = 节点.makeIterator()
                let 并发 = self.测速最大并发

                for _ in 0..<并发 {
                    guard let node = 迭代器.next() else { break }
                    group.addTask {
                        await self.执行一次测速(node)
                    }
                }

                while await group.next() != nil {
                    已完成 += 1
                    let a = 已完成
                    let b = total
                    DispatchQueue.main.async { 进度(a, b) }
                    if let node = 迭代器.next() {
                        group.addTask {
                            await self.执行一次测速(node)
                        }
                    }
                }
            }

            DispatchQueue.main.async { 完成() }
        }
    }

    private func 执行一次测速(_ 节点: VPNNode) async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            测速节点(节点) { _ in
                cont.resume()
            }
        }
    }

    // MARK: - 节点持久化（App Group）

    private var 节点文件URL: URL? {
        guard let 容器 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup标识
        ) else { return nil }
        return 容器.appendingPathComponent(节点文件名)
    }

    private func 加载节点列表() {
        guard let 文件 = 节点文件URL else { return }
        guard let 数据 = try? Data(contentsOf: 文件),
              let 解码 = try? JSONDecoder().decode([VPNNode].self, from: 数据) else { return }
        节点列表 = 解码
    }

    private func 保存节点列表() {
        guard let 文件 = 节点文件URL else { return }
        do {
            let 数据 = try JSONEncoder().encode(节点列表)
            try 数据.write(to: 文件, options: .atomic)
        } catch {
            let 内容 = "保存节点列表失败：\(error.localizedDescription)"
            记录日志(级别: .错误, 模块: "持久化", 内容: 内容)
        }
    }

    private func 加载当前节点() {
        guard let defaults = UserDefaults(suiteName: appGroup标识),
              let 数据 = defaults.data(forKey: 当前节点键),
              let 节点 = try? JSONDecoder().decode(VPNNode.self, from: 数据) else { return }
        当前节点 = 节点
    }

    private func 保存当前节点() {
        guard let 节点 = 当前节点,
              let 数据 = try? JSONEncoder().encode(节点),
              let defaults = UserDefaults(suiteName: appGroup标识) else { return }
        defaults.set(数据, forKey: 当前节点键)
    }

    // MARK: - Xray 配置生成

    /// 写入 Xray 配置到 App Group（双写机制：UserDefaults + 共享文件）
    ///
    /// 为什么需要双写：
    /// - UserDefaults 跨进程同步存在时序窗口，主 App 写入后扩展进程可能立即启动，
    ///   此时 UserDefaults 的磁盘 plist 可能尚未刷新，扩展读不到
    /// - 共享文件写入使用 .atomic 选项，保证扩展读取时文件一定完整
    /// - 扩展端读取逻辑优先读 UserDefaults，失败后回退到共享文件，双写确保至少一条通道可用
    private func 写入Xray配置到AppGroup(_ 节点: VPNNode) {
        let 配置 = 生成Xray配置(节点)

        guard let 数据 = try? JSONSerialization.data(withJSONObject: 配置, options: .prettyPrinted),
              let 字符串 = String(data: 数据, encoding: .utf8),
              !字符串.isEmpty else {
            记录日志(级别: .错误, 模块: "配置", 内容: "生成 Xray 配置失败或配置为空")
            return
        }

        var 写入成功计数 = 0

        // 通道一：写入 UserDefaults（App Group 共享）
        if let defaults = UserDefaults(suiteName: appGroup标识) {
            defaults.set(字符串, forKey: xray配置键)
            // 强制立即刷盘，缩短跨进程同步窗口
            defaults.synchronize()
            写入成功计数 += 1
            记录日志(级别: .信息, 模块: "配置", 内容: "UserDefaults 写入成功（键：\(xray配置键)，\(字符串.utf8.count) 字节）")
        } else {
            记录日志(级别: .错误, 模块: "配置", 内容: "无法访问 App Group UserDefaults（suiteName：\(appGroup标识)）")
        }

        // 通道二：写入共享文件（App Group 容器内）
        if let 容器 = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup标识) {
            let 文件URL = 容器.appendingPathComponent("xray_config.json")
            do {
                try 字符串.write(to: 文件URL, atomically: true, encoding: .utf8)
                写入成功计数 += 1
                记录日志(级别: .信息, 模块: "配置", 内容: "共享文件写入成功（路径：\(文件URL.path)，\(字符串.utf8.count) 字节）")
            } catch {
                记录日志(级别: .错误, 模块: "配置", 内容: "共享文件写入失败：\(error.localizedDescription)")
            }
        } else {
            记录日志(级别: .错误, 模块: "配置", 内容: "无法访问 App Group 容器（identifier：\(appGroup标识)）")
        }

        if 写入成功计数 > 0 {
            记录日志(级别: .信息, 模块: "配置", 内容: "Xray 配置双写完成（成功通道：\(写入成功计数)/2），\(字符串.utf8.count) 字节")
        } else {
            记录日志(级别: .错误, 模块: "配置", 内容: "Xray 配置双写全部失败，VPN 扩展将无法读取配置")
        }
    }

    private func 生成Xray配置(_ 节点: VPNNode) -> [String: Any] {
        let 出站 = 生成出站(节点)
        let 直连: [String: Any] = ["tag": "direct", "protocol": "freedom"]

        return [
            "log": ["loglevel": "warning"],
            "outbounds": [出站, 直连],
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": []
            ],
            "dns": [
                "servers": ["1.1.1.1", "8.8.8.8"]
            ]
        ]
    }

    private func 生成出站(_ 节点: VPNNode) -> [String: Any] {
        let 流设置 = 生成流设置(节点)

        switch 节点.protocolType {
        case .vless:
            var 用户: [String: Any] = [
                "id": 节点.uuid,
                "encryption": "none"
            ]
            if let flow = 节点.flow, !flow.isEmpty {
                用户["flow"] = flow
            }
            return [
                "tag": "proxy",
                "protocol": "vless",
                "settings": [
                    "vnext": [[
                        "address": 节点.serverAddress,
                        "port": 节点.serverPort,
                        "users": [用户]
                    ]]
                ],
                "streamSettings": 流设置
            ]

        case .vmess:
            return [
                "tag": "proxy",
                "protocol": "vmess",
                "settings": [
                    "vnext": [[
                        "address": 节点.serverAddress,
                        "port": 节点.serverPort,
                        "users": [["id": 节点.uuid, "alterId": 0, "security": "auto"]]
                    ]]
                ],
                "streamSettings": 流设置
            ]

        case .trojan:
            return [
                "tag": "proxy",
                "protocol": "trojan",
                "settings": [
                    "servers": [[
                        "address": 节点.serverAddress,
                        "port": 节点.serverPort,
                        "password": 节点.uuid
                    ]]
                ],
                "streamSettings": 流设置
            ]

        case .shadowsocks:
            return [
                "tag": "proxy",
                "protocol": "shadowsocks",
                "settings": [
                    "servers": [[
                        "address": 节点.serverAddress,
                        "port": 节点.serverPort,
                        "password": 节点.uuid,
                        "method": "aes-256-gcm"
                    ]]
                ],
                "streamSettings": 流设置
            ]

        case .hysteria, .tuic:
            let 内容 = "不支持的协议：\(节点.protocolType.displayName)，回退 VLESS"
            记录日志(级别: .错误, 模块: "配置", 内容: 内容)
            return [
                "tag": "proxy",
                "protocol": "vless",
                "settings": [
                    "vnext": [[
                        "address": 节点.serverAddress,
                        "port": 节点.serverPort,
                        "users": [["id": 节点.uuid, "encryption": "none"]]
                    ]]
                ],
                "streamSettings": 流设置
            ]
        }
    }

    private func 生成流设置(_ 节点: VPNNode) -> [String: Any] {
        var 设置: [String: Any] = [:]

        switch 节点.transportType {
        case .tcp:
            设置["network"] = "tcp"
            设置["tcpSettings"] = ["header": ["type": "none"]]
        case .websocket:
            设置["network"] = "ws"
            设置["wsSettings"] = [
                "path": 节点.wsPath ?? "/",
                "headers": ["Host": 节点.wsHost ?? 节点.tlsServerName ?? 节点.serverAddress]
            ]
        case .grpc:
            设置["network"] = "grpc"
            设置["grpcSettings"] = [
                "serviceName": 节点.grpcServiceName ?? "",
                "multiMode": false
            ]
        case .http2:
            设置["network"] = "http"
            设置["httpSettings"] = [
                "host": [节点.tlsServerName ?? 节点.serverAddress],
                "path": 节点.wsPath ?? "/"
            ]
        case .mkcp:
            设置["network"] = "kcp"
            设置["kcpSettings"] = [
                "mtu": 1350, "tti": 20,
                "uplinkCapacity": 5, "downlinkCapacity": 20,
                "congestion": false, "readBufferSize": 1, "writeBufferSize": 1,
                "header": ["type": "none"]
            ]
        case .quic:
            设置["network"] = "quic"
            设置["quicSettings"] = ["security": "none", "key": "", "header": ["type": "none"]]
        }

        if 节点.enableTLS {
            设置["security"] = "tls"
            var tls: [String: Any] = [
                "serverName": 节点.tlsServerName ?? 节点.serverAddress,
                "allowInsecure": 节点.allowInsecure
            ]
            if let alpn = 节点.alpn {
                tls["alpn"] = alpn
            }
            设置["tlsSettings"] = tls
        } else {
            设置["security"] = "none"
        }

        return 设置
    }

    // MARK: - 扩展通信

    func 发送消息到扩展(_ 消息: String, 完成: ((Data?) -> Void)? = nil) {
        guard let 管理器 = 当前管理器,
              let session = 管理器.connection as? NETunnelProviderSession else {
            完成?(nil)
            return
        }
        do {
            try session.sendProviderMessage(Data(消息.utf8)) { 回复 in
                DispatchQueue.main.async { 完成?(回复) }
            }
        } catch {
            完成?(nil)
        }
    }

    // MARK: - 兼容别名

    var nodes: [VPNNode] { 节点列表 }
    var currentNode: VPNNode? { 当前节点 }
    var connectionStatus: VPNConnectionStatus { 当前连接状态 }

    /// 状态变化回调（在主线程触发）
    var onStatusChange: ((VPNConnectionStatus) -> Void)?

    func addNode(_ node: VPNNode) { 添加节点(node) }
    func removeNode(_ node: VPNNode) { 删除节点(node) }
    func removeNodes(_ nodes: [VPNNode]) { 批量删除节点(nodes) }
    func selectNode(_ node: VPNNode) { 选择节点(node) }
    func toggleConnection(completion: ((Error?) -> Void)? = nil) { 切换连接(完成: completion) }
    func connect(completion: ((Error?) -> Void)? = nil) { 连接(完成: completion) }
    func disconnect() { 断开() }

    func testNodeLatency(_ node: VPNNode, completion: @escaping (Result<Int, Error>) -> Void) {
        测速节点(node, 完成: completion)
    }

    func testAllNodesLatency(
        nodes: [VPNNode],
        progress: @escaping (Int, Int) -> Void,
        completion: @escaping () -> Void
    ) {
        批量测速所有节点(节点: nodes, 进度: progress, 完成: completion)
    }
}