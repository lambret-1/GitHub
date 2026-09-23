//
//  VPNManager.swift
//  GitHub
//
//  用途：VPN 管理器（重构版·第一期底层基座）
//  职责：
//    1. 管理 NETunnelProviderManager（连接前强制清除旧配置，避免残留服务器地址）
//    2. 生成 Xray VLESS JSON 配置并写入 App Group
//    3. 节点数据持久化
//    4. 监听 VPN 连接状态变化
//

import Foundation
import NetworkExtension
import Network
import UIKit
import os.log

// MARK: - VPN 连接状态

/// VPN 连接状态（对应 NEVPNStatus）
enum VPNConnectionStatus {
    case invalid
    case disconnected
    case connecting
    case connected
    case reasserting
    case disconnecting

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

    /// 状态显示文本（中文）
    var displayText: String {
        switch self {
        case .invalid: return "配置无效"
        case .disconnected: return "已断开"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .reasserting: return "重新连接中..."
        case .disconnecting: return "断开中..."
        }
    }

    var isActive: Bool {
        self == .connecting || self == .connected || self == .reasserting
    }
}

// MARK: - VPN 管理器

/// VPN 管理器（单例）
final class VPNManager: NSObject {

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

    // MARK: - 属性

    /// 当前 VPN 管理器实例
    private var 当前管理器: NETunnelProviderManager?

    /// 节点列表
    private(set) var 节点列表: [VPNNode] = []

    /// 当前选中节点
    private(set) var 当前节点: VPNNode?

    /// 当前连接状态
    private(set) var 连接状态: VPNConnectionStatus = .disconnected {
        didSet {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.状态回调?(self.连接状态)
            }
        }
    }

    /// 状态变化回调
    var 状态回调: ((VPNConnectionStatus) -> Void)?

    /// 连接错误回调
    var 错误回调: ((Error) -> Void)?

    // MARK: - 初始化

    private override init() {
        super.init()
        加载节点列表()
        加载当前节点()
        注册状态监听()
        首次启动写入默认节点()
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
        DebugLogger.vpn("首次启动，已写入默认节点：\(默认节点.remark)")
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

        let 旧状态 = 连接状态
        连接状态 = 新状态
        DebugLogger.vpn("VPN状态：\(旧状态.displayText) → \(新状态.displayText)")

        // 连接中→断开，读取扩展日志
        if 旧状态 == .connecting && (新状态 == .disconnecting || 新状态 == .disconnected) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.读取扩展文件日志()
            }
        }
    }

    /// 读取扩展写入 App Group 的启动日志
    private func 读取扩展文件日志() {
        guard let 容器目录 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroup标识
        ) else { return }

        let 日志文件 = 容器目录
            .appendingPathComponent("vpn扩展日志", isDirectory: true)
            .appendingPathComponent("隧道启动日志.log")

        guard FileManager.default.fileExists(atPath: 日志文件.path),
              let 内容 = try? String(contentsOf: 日志文件, encoding: .utf8),
              !内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            DebugLogger.vpn("扩展文件日志为空")
            return
        }

        DebugLogger.vpn("========== 扩展启动日志 ==========")
        内容.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .forEach { DebugLogger.vpn($0) }
    }

    // MARK: - 连接控制

    /// 连接 VPN
    func 连接(completion: ((Error?) -> Void)? = nil) {
        DebugLogger.vpnInfo("=== 开始连接 VPN ===")

        guard let 节点 = 当前节点 else {
            let 错误 = NSError(domain: "VPNManager", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "请先选择一个节点"])
            completion?(错误)
            错误回调?(错误)
            return
        }

        DebugLogger.vpn("节点：\(节点.remark) (\(节点.serverAddress):\(节点.serverPort))")

        // 1. 生成 Xray 配置并写入 App Group
        写入Xray配置到AppGroup(节点)

        // 2. 强制清除所有旧 VPN 配置（解决残留错误服务器地址问题）
        清除所有旧VPN配置 { [weak self] in
            guard let self = self else { return }
            // 3. 创建新配置并启动隧道
            self.创建新VPN配置并启动(节点: 节点, completion: completion)
        }
    }

    /// 清除所有旧 VPN 配置
    private func 清除所有旧VPN配置(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { 管理器列表, error in
            if let error = error {
                DebugLogger.vpnError("加载VPN配置列表失败：\(error.localizedDescription)")
            }

            guard let 管理器列表 = 管理器列表, !管理器列表.isEmpty else {
                DebugLogger.vpn("无旧VPN配置需要清除")
                completion()
                return
            }

            DebugLogger.vpn("发现 \(管理器列表.count) 个旧VPN配置，强制删除")
            let group = DispatchGroup()
            for 管理器 in 管理器列表 {
                group.enter()
                管理器.removeFromPreferences { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main) {
                DebugLogger.vpn("所有旧VPN配置已删除")
                completion()
            }
        }
    }

    /// 创建新 VPN 配置并启动隧道
    private func 创建新VPN配置并启动(节点: VPNNode, completion: ((Error?) -> Void)?) {
        let 管理器 = NETunnelProviderManager()
        管理器.localizedDescription = 配置标识

        let 协议 = NETunnelProviderProtocol()
        协议.providerBundleIdentifier = 扩展BundleID
        协议.serverAddress = "\(节点.serverAddress):\(节点.serverPort)"
        协议.providerConfiguration = [
            "node_server": 节点.serverAddress,
            "node_port": 节点.serverPort,
            "node_protocol": 节点.protocolType.rawValue
        ]

        管理器.protocolConfiguration = 协议
        管理器.isEnabled = true

        管理器.saveToPreferences { [weak self] 保存错误 in
            guard let self = self else { return }

            if let 保存错误 = 保存错误 {
                DebugLogger.vpnError("保存VPN配置失败：\(保存错误.localizedDescription)")
                DispatchQueue.main.async {
                    completion?(保存错误)
                    self.错误回调?(保存错误)
                }
                return
            }

            DebugLogger.vpn("VPN配置保存成功，服务器：\(协议.serverAddress ?? "未知")")

            管理器.loadFromPreferences { [weak self] 加载错误 in
                guard let self = self else { return }

                if let 加载错误 = 加载错误 {
                    DispatchQueue.main.async {
                        completion?(加载错误)
                        self.错误回调?(加载错误)
                    }
                    return
                }

                self.当前管理器 = 管理器

                do {
                    try 管理器.connection.startVPNTunnel()
                    DebugLogger.vpnInfo("VPN隧道启动命令已发送")
                    DispatchQueue.main.async { completion?(nil) }
                } catch {
                    DebugLogger.vpnError("启动VPN隧道失败：\(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion?(error)
                        self.错误回调?(error)
                    }
                }
            }
        }
    }

    /// 断开 VPN
    func 断开() {
        DebugLogger.vpnInfo("断开 VPN")
        当前管理器?.connection.stopVPNTunnel()
    }

    /// 切换连接状态
    func 切换连接(completion: ((Error?) -> Void)? = nil) {
        if 连接状态.isActive {
            断开()
            completion?(nil)
        } else {
            连接(completion: completion)
        }
    }

    // MARK: - 节点管理

    func 添加节点(_ 节点: VPNNode) {
        guard !节点列表.contains(where: { $0.id == 节点.id }) else { return }
        节点列表.append(节点)
        保存节点列表()
    }

    func 删除节点(_ 节点: VPNNode) {
        节点列表.removeAll { $0.id == 节点.id }
        if 当前节点?.id == 节点.id {
            当前节点 = nil
        }
        保存节点列表()
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
        DebugLogger.vpn("选择节点：\(节点.remark)")
    }

    // MARK: - 节点测速

    func 测速节点(_ 节点: VPNNode, completion: @escaping (Result<Int, Error>) -> Void) {
        let host = NWEndpoint.Host(节点.serverAddress)
        let port = NWEndpoint.Port(rawValue: UInt16(节点.serverPort)) ?? 443
        let connection = NWConnection(host: host, port: port, using: .tcp)
        let startTime = Date()

        let 超时工作项 = DispatchWorkItem {
            connection.cancel()
            completion(.failure(NSError(domain: "VPNManager", code: -1,
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
                completion(.success(延迟))
            case .failed(let error):
                超时工作项.cancel()
                completion(.failure(error))
            default:
                break
            }
        }

        connection.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: 超时工作项)
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
            DebugLogger.vpn("Xray配置已写入AppGroup（\(字符串.count)字节）")
        } else {
            DebugLogger.vpnError("生成Xray配置失败")
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
            DebugLogger.vpnError("不支持的协议：\(节点.protocolType.displayName)，回退VLESS")
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

    func 发送消息到扩展(_ 消息: String, completion: ((Data?) -> Void)? = nil) {
        guard let 管理器 = 当前管理器,
              let session = 管理器.connection as? NETunnelProviderSession else {
            completion?(nil)
            return
        }
        do {
            try session.sendProviderMessage(Data(消息.utf8)) { 回复 in
                DispatchQueue.main.async { completion?(回复) }
            }
        } catch {
            completion?(nil)
        }
    }

    // MARK: - 兼容别名（供现有UI调用，后续逐步迁移为中文）

    /// 节点列表（英文别名）
    var nodes: [VPNNode] { 节点列表 }
    /// 当前节点（英文别名）
    var currentNode: VPNNode? { 当前节点 }
    /// 连接状态（英文别名）
    var connectionStatus: VPNConnectionStatus { 连接状态 }
    /// 状态回调（英文别名）
    var onStatusChange: ((VPNConnectionStatus) -> Void)? {
        get { 状态回调 }
        set { 状态回调 = newValue }
    }

    func addNode(_ node: VPNNode) { 添加节点(node) }
    func removeNode(_ node: VPNNode) { 删除节点(node) }
    func removeNodes(_ nodes: [VPNNode]) { 批量删除节点(nodes) }
    func selectNode(_ node: VPNNode) { 选择节点(node) }
    func toggleConnection(completion: ((Error?) -> Void)? = nil) { 切换连接(completion: completion) }
    func connect(completion: ((Error?) -> Void)? = nil) { 连接(completion: completion) }
    func disconnect() { 断开() }

    func testNodeLatency(_ node: VPNNode, completion: @escaping (Result<Int, Error>) -> Void) {
        测速节点(node, completion: completion)
    }

    /// 批量测速所有节点
    func testAllNodesLatency(nodes: [VPNNode], progress: @escaping (Int, Int) -> Void, completion: @escaping () -> Void) {
        let total = nodes.count
        guard total > 0 else { completion(); return }
        var 已完成 = 0
        let group = DispatchGroup()
        for node in nodes {
            group.enter()
            测速节点(node) { _ in
                已完成 += 1
                progress(已完成, total)
                group.leave()
            }
        }
        group.notify(queue: .main, execute: completion)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
