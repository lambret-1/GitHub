//
//  VPNManager.swift
//  GitHub
//
//  用途：VPN 管理器（重构版·参考 newVPN 隧道管理器架构）
//  职责：
//    1. ObservableObject 响应式状态管理（连接状态/流量统计/日志/错误）
//    2. NETunnelProviderManager 配置管理（复用已有配置，避免反复权限弹窗）
//    3. Xray VLESS JSON 配置生成并写入 App Group
//    4. 节点数据持久化（增删改查/测速）
//    5. VPN 状态变化监听 + 流量统计定时轮询
//    6. 描述文件检测与 VPN 权限管理
//

import Foundation
import NetworkExtension
import Network
import UIKit
import Combine
import os.log

// MARK: - VPN 连接状态

/// VPN 连接状态（对应 NEVPNStatus，扩展为准备中/连接失败）
enum VPNConnectionStatus {
    case invalid
    case disconnected
    case connecting
    case connected
    case reasserting
    case disconnecting
    /// 准备中（生成配置/保存配置阶段）
    case preparing
    /// 连接失败
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

    /// 是否处于活动状态（连接中/已连接/重连中/准备中）
    var isActive: Bool {
        self == .connecting || self == .connected || self == .reasserting || self == .preparing
    }

    /// 状态displayText（中文）
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

/// VPN 流量统计数据模型
struct VPN流量统计 {
    /// 上行总字节数
    var 上行字节: UInt64 = 0
    /// 下行总字节数
    var 下行字节: UInt64 = 0
    /// 上行速度（字节/秒）
    var 上行速度: Double = 0
    /// 下行速度（字节/秒）
    var 下行速度: Double = 0
    /// 连接时长（秒）
    var 连接时长: TimeInterval = 0
    /// 最后更新时间
    var 最后更新时间: Date = Date()

    /// 格式化上行总流量（人类可读）
    var 格式化上行: String {
        Self.格式化字节数(上行字节)
    }

    /// 格式化下行总流量（人类可读）
    var 格式化下行: String {
        Self.格式化字节数(下行字节)
    }

    /// 格式化上行速度（人类可读）
    var 格式化上行速度: String {
        Self.格式化字节数(UInt64(上行速度)) + "/s"
    }

    /// 格式化下行速度（人类可读）
    var 格式化下行速度: String {
        Self.格式化字节数(UInt64(下行速度)) + "/s"
    }

    /// 格式化连接时长（HH:MM:SS）
    var 格式化连接时长: String {
        let 小时 = Int(连接时长) / 3600
        let 分钟 = (Int(连接时长) % 3600) / 60
        let 秒 = Int(连接时长) % 60
        return String(format: "%02d:%02d:%02d", 小时, 分钟, 秒)
    }

    /// 字节数格式化工具
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

/// VPN 日志条目模型
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

/// VPN 日志级别
enum VPN日志级别: String, CaseIterable {
    case 调试 = "调试"
    case 信息 = "信息"
    case 警告 = "警告"
    case 错误 = "错误"

    /// 系统日志级别
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

/// VPN 管理器（ObservableObject 单例，参考 newVPN 隧道管理器架构）
final class VPNManager: NSObject, ObservableObject {

    // MARK: - 单例

    static let shared = VPNManager()

    // MARK: - 常量

    /// App Group 标识（必须与扩展 entitlements 完全一致）
    private let appGroup标识 = "group.com.github.client"

    /// VPN 扩展 Bundle ID
    private let 扩展BundleID = "com.github.client.vpn"

    /// VPN 配置标识
    private let 配置标识 = "GitHub中文VPN"

    /// Xray 配置存储键（App Group UserDefaults）
    private let xray配置键 = "xray_config_json"

    /// 当前节点存储键
    private let 当前节点键 = "vpn_current_node"

    /// 节点列表文件名
    private let 节点文件名 = "vpn_nodes.json"

    /// 流量统计更新间隔（秒）
    private let 统计更新间隔: TimeInterval = 1.0

    // MARK: - 发布状态（ObservableObject）

    /// 当前连接状态
    @Published var 当前连接状态: VPNConnectionStatus = .disconnected

    /// 流量统计
    @Published var 流量统计: VPN流量统计 = VPN流量统计()

    /// VPN 日志列表（最新在前，最多500条）
    @Published var 日志列表: [VPN日志条目] = []

    /// 最近错误
    @Published var 最近错误: Error?

    /// 是否需要安装 VPN 描述文件
    @Published var 需要安装描述文件: Bool = false

    /// 是否正在加载配置
    @Published var 是否加载中: Bool = false

    // MARK: - 内部属性

    /// 当前 VPN 管理器实例
    private var 当前管理器: NETunnelProviderManager?

    /// 节点列表
    private(set) var 节点列表: [VPNNode] = []

    /// 当前选中节点
    private(set) var 当前节点: VPNNode?

    /// 统计更新定时器
    private var 统计定时器: Timer?

    /// 连接开始时间
    private var 连接开始时间: Date?

    /// 上次统计字节数（用于计算速度）
    private var 上次上行字节: UInt64 = 0
    private var 上次下行字节: UInt64 = 0

    /// 系统日志器
    private let 日志记录器 = Logger(subsystem: "com.github.client", category: "VPN")

    // MARK: - 初始化

    private override init() {
        super.init()
        加载节点列表()
        加载当前节点()
        注册状态监听()
        首次启动写入默认节点()
        // 异步检测描述文件状态（不阻塞初始化）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.检测描述文件状态()
        }
    }

    // MARK: - 首次启动写入默认节点

    /// 首次启动时自动写入默认节点（VLESS over TLS）
    private func 首次启动写入默认节点() {
        guard 节点列表.isEmpty else { return }

        var 默认节点 = VPNNode(
            remark: "🇺🇸 美国高速优选",
            protocolType: .vless,
            serverAddress: "visa.com",
            serverPort: 443,
            uuid: "62bc5cd2-5eef-4e12-b9b3-24087eff5082"
        )
        默认节点.transportType = .tcp
        默认节点.enableTLS = true
        默认节点.tlsServerName = "visa.com"

        节点列表.append(默认节点)
        保存节点列表()
        当前节点 = 默认节点
        保存当前节点()
        记录日志(级别: .信息, 模块: "初始化", 内容: "首次启动，已写入默认节点：\(默认节点.remark)")
    }

    // MARK: - 日志管理

    /// 记录日志（内存环形缓冲 + 系统日志）
    func 记录日志(级别: VPN日志级别, 模块: String, 内容: String) {
        let 条目 = VPN日志条目(级别: 级别, 模块: 模块, 内容: 内容)

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.日志列表.insert(条目, at: 0)
            if self.日志列表.count > 500 {
                self.日志列表.removeLast(self.日志列表.count - 500)
            }
        }

        // 输出到系统日志
        日志记录器.log(level: 级别.osLog级别, "\(模块): \(内容)")
    }

    /// 清除日志
    func 清除日志() {
        DispatchQueue.main.async {
            self.日志列表.removeAll()
        }
    }

    /// 从扩展读取启动日志文件（连接失败时调用）
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

        记录日志(级别: .信息, 模块: "扩展日志", 内容: "========== 扩展启动日志 ==========")
        内容.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .forEach { 记录日志(级别: .调试, 模块: "扩展", 内容: $0) }
    }

    // MARK: - 状态监听

    private func 注册状态监听() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpn状态变化(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }

    @objc private func vpn状态变化(_ 通知: Notification) {
        let 新状态: VPNConnectionStatus
        if let 会话 = 通知.object as? NETunnelProviderSession {
            新状态 = VPNConnectionStatus(from: 会话.status)
        } else if let 管理器 = 当前管理器 {
            新状态 = VPNConnectionStatus(from: 管理器.connection.status)
        } else {
            新状态 = .disconnected
        }

        let 旧状态 = 当前连接状态
        DispatchQueue.main.async {
            self.当前连接状态 = 新状态
            // 触发兼容回调（供旧版UI使用）
            self.onStatusChange?(新状态)
        }

        记录日志(级别: .信息, 模块: "状态", 内容: "\(旧状态.displayText) → \(新状态.displayText)")

        // 状态变化处理
        switch 新状态 {
        case .connected:
            连接开始时间 = Date()
            启动统计定时器()
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道连接成功")
        case .disconnected:
            停止统计定时器()
            记录日志(级别: .信息, 模块: "连接", 内容: "隧道已断开")
            // 连接中→断开，可能是失败，读取扩展日志
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

    // MARK: - 描述文件管理

    /// 描述文件是否已安装
    var 描述文件是否已安装: Bool {
        guard let 管理器 = 当前管理器 else { return false }
        return 管理器.protocolConfiguration != nil
    }

    /// 检测 VPN 描述文件状态
    func 检测描述文件状态(完成: ((Bool) -> Void)? = nil) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.记录日志(级别: .错误, 模块: "描述文件", 内容: "检测描述文件状态失败：\(错误.localizedDescription)")
                DispatchQueue.main.async {
                    self.需要安装描述文件 = true
                }
                完成?(false)
                return
            }

            // 查找 providerBundleIdentifier 匹配的配置
            let 匹配的管理器 = 管理器列表?.first(where: { 管理器 in
                guard let 协议配置 = 管理器.protocolConfiguration as? NETunnelProviderProtocol else {
                    return false
                }
                return 协议配置.providerBundleIdentifier == self.扩展BundleID
            })

            let 已安装 = 匹配的管理器 != nil

            DispatchQueue.main.async {
                self.需要安装描述文件 = !已安装
                if let 管理器 = 匹配的管理器 {
                    self.当前管理器 = 管理器
                    // 同步当前连接状态
                    if let 会话 = 管理器.connection as? NETunnelProviderSession {
                        self.当前连接状态 = VPNConnectionStatus(from: 会话.status)
                    }
                }
                self.记录日志(级别: .信息, 模块: "描述文件", 内容: 已安装 ? "VPN 描述文件已安装" : "VPN 描述文件未安装")
                完成?(已安装)
            }
        }
    }

    /// 请求 VPN 权限（通过创建临时配置触发系统权限对话框）
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
                let 错误描述 = 保存错误.localizedDescription.lowercased()
                self.记录日志(级别: .错误, 模块: "权限", 内容: "请求VPN权限失败：\(保存错误.localizedDescription)")

                if 错误描述.contains("permission") || 错误描述.contains("denied") {
                    DispatchQueue.main.async {
                        self.需要安装描述文件 = true
                    }
                    完成(false)
                } else {
                    // 其他错误，可能是配置已存在，视为成功
                    self.记录日志(级别: .信息, 模块: "权限", 内容: "保存临时配置返回非权限错误，视为已授权")
                    完成(true)
                }
            } else {
                self.记录日志(级别: .信息, 模块: "权限", 内容: "VPN权限请求成功")
                // 删除临时配置
                临时管理器.removeFromPreferences { _ in
                    完成(true)
                }
            }
        }
    }

    /// 跳转到 iOS 设置页面（App 设置）
    func 跳转到设置页面() {
        guard let 设置URL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(设置URL)
    }

    // MARK: - 连接控制

    /// 连接 VPN
    func 连接(完成: ((Error?) -> Void)? = nil) {
        记录日志(级别: .信息, 模块: "连接", 内容: "=== 开始连接 VPN ===")

        guard let 节点 = 当前节点 else {
            let 错误 = NSError(domain: "VPNManager", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "请先选择一个节点"])
            DispatchQueue.main.async {
                self.最近错误 = 错误
                self.当前连接状态 = .failed
            }
            完成?(错误)
            return
        }

        记录日志(级别: .信息, 模块: "连接", 内容: "节点：\(节点.remark) (\(节点.serverAddress):\(节点.serverPort))")

        // 1. 生成 Xray 配置并写入 App Group
        写入Xray配置到AppGroup(节点)

        // 2. 状态切换为准备中
        DispatchQueue.main.async {
            self.当前连接状态 = .preparing
        }

        // 3. 加载/创建 VPN 配置并启动隧道（复用已有配置，不每次清除）
        加载或创建VPN配置 { [weak self] 管理器, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                self.记录日志(级别: .错误, 模块: "连接", 内容: "VPN配置加载/创建失败：\(错误.localizedDescription)")
                DispatchQueue.main.async {
                    self.最近错误 = 错误
                    self.当前连接状态 = .failed
                }
                完成?(错误)
                return
            }

            guard let 管理器 = 管理器 else {
                let 错误 = NSError(domain: "VPNManager", code: -2,
                                   userInfo: [NSLocalizedDescriptionKey: "VPN管理器为空"])
                完成?(错误)
                return
            }

            // 4. 保存配置（更新节点信息）
            self.保存VPN配置(管理器: 管理器, 节点: 节点) { 保存成功, 保存错误 in
                guard 保存成功 else {
                    self.记录日志(级别: .错误, 模块: "连接", 内容: "保存VPN配置失败：\(保存错误?.localizedDescription ?? "未知错误")")
                    DispatchQueue.main.async {
                        self.最近错误 = 保存错误
                        self.当前连接状态 = .failed
                    }
                    完成?(保存错误)
                    return
                }

                // 5. 启动隧道
                do {
                    try 管理器.connection.startVPNTunnel()
                    self.记录日志(级别: .信息, 模块: "连接", 内容: "VPN隧道启动命令已发送")
                    DispatchQueue.main.async {
                        完成?(nil)
                    }
                } catch {
                    self.记录日志(级别: .错误, 模块: "连接", 内容: "启动VPN隧道失败：\(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.最近错误 = error
                        self.当前连接状态 = .failed
                    }
                    完成?(error)
                }
            }
        }
    }

    /// 加载或创建 VPN 配置（复用已有配置，避免每次清除导致权限反复弹窗）
    private func 加载或创建VPN配置(完成: @escaping (NETunnelProviderManager?, Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] 管理器列表, 错误 in
            guard let self = self else { return }

            if let 错误 = 错误 {
                完成(nil, 错误)
                return
            }

            // 优先查找 bundleID 匹配的配置
            if let 匹配的管理器 = 管理器列表?.first(where: { 管理器 in
                guard let 协议配置 = 管理器.protocolConfiguration as? NETunnelProviderProtocol else {
                    return false
                }
                return 协议配置.providerBundleIdentifier == self.扩展BundleID
            }) {
                self.当前管理器 = 匹配的管理器
                self.记录日志(级别: .信息, 模块: "配置", 内容: "找到匹配的VPN配置，复用")
                完成(匹配的管理器, nil)
                return
            }

            // 其次使用第一个配置
            if let 第一个 = 管理器列表?.first {
                self.当前管理器 = 第一个
                self.记录日志(级别: .信息, 模块: "配置", 内容: "使用第一个已有VPN配置")
                完成(第一个, nil)
                return
            }

            // 没有配置，创建新的
            self.记录日志(级别: .信息, 模块: "配置", 内容: "未找到VPN配置，创建新配置")
            let 新管理器 = NETunnelProviderManager()
            新管理器.localizedDescription = self.配置标识
            self.当前管理器 = 新管理器
            完成(新管理器, nil)
        }
    }

    /// 保存 VPN 配置（更新协议配置和节点信息）
    private func 保存VPN配置(管理器: NETunnelProviderManager, 节点: VPNNode, 完成: @escaping (Bool, Error?) -> Void) {
        let 协议 = NETunnelProviderProtocol()
        协议.providerBundleIdentifier = 扩展BundleID
        协议.serverAddress = "\(节点.serverAddress):\(节点.serverPort)"
        协议.providerConfiguration = [
            "node_server": 节点.serverAddress,
            "node_port": 节点.serverPort,
            "node_protocol": 节点.protocolType.rawValue
        ]

        管理器.protocolConfiguration = 协议
        管理器.localizedDescription = 配置标识
        管理器.isEnabled = true

        管理器.saveToPreferences { [weak self] 保存错误 in
            if let 保存错误 = 保存错误 {
                完成(false, 保存错误)
                return
            }

            self?.记录日志(级别: .信息, 模块: "配置", 内容: "VPN配置保存成功，服务器：\(协议.serverAddress ?? "未知")")

            // 重新加载以确认
            管理器.loadFromPreferences { 加载错误 in
                if let 加载错误 = 加载错误 {
                    self?.记录日志(级别: .警告, 模块: "配置", 内容: "重新加载配置失败（不影响连接）：\(加载错误.localizedDescription)")
                }
                完成(true, nil)
            }
        }
    }

    /// 断开 VPN
    func 断开() {
        记录日志(级别: .信息, 模块: "连接", 内容: "断开 VPN")
        当前管理器?.connection.stopVPNTunnel()
    }

    /// 切换连接状态
    func 切换连接(完成: ((Error?) -> Void)? = nil) {
        if 当前连接状态.isActive {
            断开()
            完成?(nil)
        } else {
            连接(完成: 完成)
        }
    }

    // MARK: - 流量统计

    /// 启动统计定时器
    private func 启动统计定时器() {
        停止统计定时器()
        上次上行字节 = 0
        上次下行字节 = 0

        统计定时器 = Timer.scheduledTimer(withTimeInterval: 统计更新间隔, repeats: true) { [weak self] _ in
            self?.更新流量统计()
        }
        RunLoop.main.add(统计定时器!, forMode: .common)
    }

    /// 停止统计定时器
    private func 停止统计定时器() {
        统计定时器?.invalidate()
        统计定时器 = nil
    }

    /// 更新流量统计（通过 IPC 从扩展读取 Xray stats）
    private func 更新流量统计() {
        guard let 管理器 = 当前管理器,
              let 会话 = 管理器.connection as? NETunnelProviderSession else { return }

        do {
            try 会话.sendProviderMessage(Data("getStats".utf8)) { [weak self] 响应数据 in
                guard let self = self,
                      let 数据 = 响应数据,
                      let 统计字符串 = String(data: 数据, encoding: .utf8) else { return }

                // 解析 Xray stats 格式（简单的 key:value 文本）
                let 统计 = self.解析Xray统计(统计字符串)
                let 上行 = 统计["uplink"] ?? 0
                let 下行 = 统计["downlink"] ?? 0

                // 计算速度
                let 上行速度 = self.上次上行字节 > 0 ? Double(上行 - self.上次上行字节) / self.统计更新间隔 : 0
                let 下行速度 = self.上次下行字节 > 0 ? Double(下行 - self.上次下行字节) / self.统计更新间隔 : 0

                self.上次上行字节 = 上行
                self.上次下行字节 = 下行

                // 计算连接时长
                let 连接时长 = self.连接开始时间.map { Date().timeIntervalSince($0) } ?? 0

                DispatchQueue.main.async {
                    self.流量统计 = VPN流量统计(
                        上行字节: 上行,
                        下行字节: 下行,
                        上行速度: max(0, 上行速度),
                        下行速度: max(0, 下行速度),
                        连接时长: 连接时长,
                        最后更新时间: Date()
                    )
                }
            }
        } catch {
            // 统计读取失败静默处理，不影响连接
        }
    }

    /// 解析 Xray stats 字符串（格式：key1:value1 key2:value2）
    private func 解析Xray统计(_ 字符串: String) -> [String: UInt64] {
        var 结果: [String: UInt64] = [:]
        let 键值对 = 字符串.components(separatedBy: .whitespaces)
        for 对 in 键值对 {
            let 部分 = 对.components(separatedBy: ":")
            guard 部分.count == 2,
                  let 值 = UInt64(部分[1]) else { continue }
            结果[部分[0]] = 值
        }
        return 结果
    }

    /// 重置流量统计
    func 重置流量统计() {
        DispatchQueue.main.async {
            self.流量统计 = VPN流量统计()
        }
        上次上行字节 = 0
        上次下行字节 = 0
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
        for 节点 in 节点数组 {
            节点列表.removeAll { $0.id == 节点.id }
            if 当前节点?.id == 节点.id { 当前节点 = nil }
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

        let 超时工作项 = DispatchWorkItem {
            connection.cancel()
            完成(.failure(NSError(domain: "VPNManager", code: -1,
                                       userInfo: [NSLocalizedDescriptionKey: "连接超时（5秒）"])))
        }

        connection.stateUpdateHandler = { 状态 in
            switch 状态 {
            case .ready:
                超时工作项.cancel()
                let 延迟 = Int(Date().timeIntervalSince(startTime) * 1000)
                connection.cancel()
                if let idx = self.节点列表.firstIndex(where: { $0.id == 节点.id }) {
                    self.节点列表[idx].latency = 延迟
                    self.保存节点列表()
                }
                完成(.success(延迟))
            case .failed(let error):
                超时工作项.cancel()
                完成(.failure(error))
            default:
                break
            }
        }

        connection.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: 超时工作项)
    }

    /// 批量测速所有节点
    func 批量测速所有节点(节点: [VPNNode], 进度: @escaping (Int, Int) -> Void, 完成: @escaping () -> Void) {
        let total = 节点.count
        guard total > 0 else { 完成(); return }
        var 已完成 = 0
        let group = DispatchGroup()
        for node in 节点 {
            group.enter()
            测速节点(node) { _ in
                已完成 += 1
                进度(已完成, total)
                group.leave()
            }
        }
        group.notify(queue: .main, execute: 完成)
    }

    // MARK: - 节点持久化

    private func 加载节点列表() {
        guard let 文档目录 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let 文件 = 文档目录.appendingPathComponent(节点文件名)
        guard let 数据 = try? Data(contentsOf: 文件),
              let 解码 = try? JSONDecoder().decode([VPNNode].self, from: 数据) else { return }
        节点列表 = 解码
    }

    private func 保存节点列表() {
        guard let 文档目录 = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let 文件 = 文档目录.appendingPathComponent(节点文件名)
        if let 数据 = try? JSONEncoder().encode(节点列表) {
            try? 数据.write(to: 文件)
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
        defaults.synchronize()
    }

    // MARK: - Xray 配置生成

    /// 生成 Xray JSON 配置并写入 App Group
    private func 写入Xray配置到AppGroup(_ 节点: VPNNode) {
        guard let defaults = UserDefaults(suiteName: appGroup标识) else { return }

        let 配置 = 生成Xray配置(节点)

        if let 数据 = try? JSONSerialization.data(withJSONObject: 配置, options: .prettyPrinted),
           let 字符串 = String(data: 数据, encoding: .utf8) {
            defaults.set(字符串, forKey: xray配置键)
            defaults.synchronize()
            记录日志(级别: .信息, 模块: "配置", 内容: "Xray配置已写入AppGroup（\(字符串.count)字节）")
        } else {
            记录日志(级别: .错误, 模块: "配置", 内容: "生成Xray配置失败")
        }
    }

    /// 根据节点生成 Xray 配置字典
    private func 生成Xray配置(_ 节点: VPNNode) -> [String: Any] {
        let 出站 = 生成出站(节点)
        let 直连: [String: Any] = ["tag": "direct", "protocol": "freedom"]

        let 配置: [String: Any] = [
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

        return 配置
    }

    /// 生成代理出站配置
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
            记录日志(级别: .错误, 模块: "配置", 内容: "不支持的协议：\(节点.protocolType.displayName)，回退VLESS")
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

    /// 生成流设置（传输层配置）
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

    /// 发送消息到扩展
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

    // MARK: - 兼容别名（供现有UI调用，后续逐步迁移为中文）

    /// 节点列表（英文别名）
    var nodes: [VPNNode] { 节点列表 }
    /// 当前节点（英文别名）
    var currentNode: VPNNode? { 当前节点 }
    /// 连接状态（英文别名）
    var connectionStatus: VPNConnectionStatus { 当前连接状态 }
    /// 状态回调（英文别名，状态变化时触发）
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

    func testAllNodesLatency(nodes: [VPNNode], progress: @escaping (Int, Int) -> Void, completion: @escaping () -> Void) {
        批量测速所有节点(节点: nodes, 进度: progress, 完成: completion)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        停止统计定时器()
    }
}
