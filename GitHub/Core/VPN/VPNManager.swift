//
//  VPNManager.swift
//  GitHub
//
//  用途：VPN 管理器，负责 VPN 配置、连接控制、节点管理
//  职责：
//    1. 管理 VPN 配置（NETunnelProviderManager）
//    2. 控制 VPN 连接/断开
//    3. 节点数据持久化存储
//    4. 与 VPN 扩展（PacketTunnelProvider）通信
//    5. 监听 VPN 连接状态变化
//
//  关键实现说明：
//    - 使用 NETunnelProviderManager 而非 NEVPNManager.shared()
//    - 参考 LightBrowser 项目的成功实现模式
//    - 连接前先删除旧配置，延迟后创建新配置，避免配置冲突
//

import Foundation
import NetworkExtension
import Network
import UIKit
import os.log

// MARK: - VPN 连接状态枚举

/// VPN 连接状态
/// 对应 NEVPNStatus 的各个状态，增加中文描述
enum VPNConnectionStatus {
    case invalid        // 配置无效
    case disconnected   // 已断开
    case connecting     // 连接中
    case connected      // 已连接
    case reasserting    // 重新连接中
    case disconnecting  // 断开中

    /// 从 NEVPNStatus 转换
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

    /// 是否处于活动状态（连接中或已连接）
    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reasserting:
            return true
        default:
            return false
        }
    }
}

// MARK: - VPN 管理器

/// VPN 管理器（单例模式）
/// 全局唯一实例，负责所有 VPN 相关操作
final class VPNManager: NSObject {

    // MARK: - 单例

    /// 共享实例
    static let shared = VPNManager()

    // MARK: - 私有初始化（防止外部创建实例）

    private override init() {
        super.init()
        // 加载节点列表
        loadNodes()
        // 加载当前选中的节点
        loadCurrentNode()
        // 监听 VPN 状态变化
        setupVPNStatusObserver()
    }

    // MARK: - 日志记录器

    /// 统一日志记录器，用于记录 VPN 管理器运行日志
    private let logger = OSLog(subsystem: "com.github.client", category: "VPNManager")

    // MARK: - App Group 标识

    /// App Group 标识，用于与 VPN 扩展共享数据
    /// 必须与 VPNPacketTunnel.entitlements 中配置一致
    private let appGroupIdentifier = "group.com.github.client"

    // MARK: - VPN 配置标识

    /// VPN 配置本地化描述，用于识别我们的 VPN 配置
    private let vpnConfigurationDescription = "GitHub中文VPN"

    /// VPN 扩展 Bundle Identifier
    private let vpnExtensionBundleID = "com.github.client.vpn"

    /// 当前活动的 VPN 管理器实例
    /// NETunnelProviderManager 不是单例，需要从 loadAllFromPreferences 获取或创建新实例
    private var currentVPNManager: NETunnelProviderManager?

    // MARK: - 节点存储

    /// 节点列表（所有已添加的节点）
    private(set) var nodes: [VPNNode] = []

    /// 当前选中的节点（用于连接）
    private(set) var currentNode: VPNNode?

    /// 节点存储文件名
    private let nodesFileName = "vpn_nodes.json"

    /// 当前节点存储 Key（用于 App Group 共享）
    private let currentNodeKey = "vpn_current_node"

    /// Xray 配置存储 Key（用于 App Group 共享，供 VPN 扩展读取）
    private let xrayConfigKey = "xray_config_json"

    // MARK: - 回调闭包

    /// VPN 状态变化回调
    var onStatusChange: ((VPNConnectionStatus) -> Void)?

    /// VPN 连接错误回调
    var onConnectionError: ((Error) -> Void)?

    // MARK: - 当前连接状态

    /// 当前 VPN 连接状态
    private(set) var connectionStatus: VPNConnectionStatus = .disconnected {
        didSet {
            // 状态变化时通知回调
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.onStatusChange?(self.connectionStatus)
            }
        }
    }

    // MARK: - 获取或创建 VPN 管理器

    /// 获取已存在的 VPN 配置管理器，或创建新的
    /// 参考 LightBrowser 的实现：使用 NETunnelProviderManager.loadAllFromPreferences
    /// - Parameter completion: 完成回调，返回管理器实例
    private func getOrCreateVPNManager(completion: @escaping (NETunnelProviderManager) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            guard let self = self else { return }

            if let error = error {
                DebugLogger.vpnError("加载所有VPN配置失败：\(error.localizedDescription)")
            }

            // 查找我们的 VPN 配置（通过 localizedDescription 识别）
            if let existingManager = managers?.first(where: { $0.localizedDescription == self.vpnConfigurationDescription }) {
                DebugLogger.vpn("找到已存在的VPN配置")
                self.currentVPNManager = existingManager
                completion(existingManager)
                return
            }

            // 没有找到，创建新的
            DebugLogger.vpn("创建新的VPN配置管理器")
            let newManager = NETunnelProviderManager()
            newManager.localizedDescription = self.vpnConfigurationDescription
            self.currentVPNManager = newManager
            completion(newManager)
        }
    }

    /// 删除所有旧的 VPN 配置
    /// 参考 LightBrowser：连接前先删除旧配置，避免配置冲突
    /// - Parameter completion: 完成回调
    private func removeAllOldVPNConfigurations(completion: @escaping () -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { managers, error in
            if let error = error {
                DebugLogger.vpnError("加载VPN配置列表失败：\(error.localizedDescription)")
                completion()
                return
            }

            guard let managers = managers, !managers.isEmpty else {
                DebugLogger.vpn("没有旧的VPN配置需要删除")
                completion()
                return
            }

            DebugLogger.vpn("找到 \(managers.count) 个旧VPN配置，准备删除")

            let group = DispatchGroup()
            for manager in managers {
                group.enter()
                manager.removeFromPreferences { _ in
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                DebugLogger.vpn("所有旧VPN配置已删除")
                completion()
            }
        }
    }

    // MARK: - VPN 权限与配置

    /// 请求 VPN 权限并加载配置
    /// 首次使用 VPN 时需要调用此方法请求系统权限
    /// - Parameter completion: 完成回调，success 为 true 表示权限获取成功
    func requestVPNPermission(completion: @escaping (Bool, Error?) -> Void) {
        getOrCreateVPNManager { [weak self] manager in
            guard let self = self else { return }

            // 配置 VPN 协议（PacketTunnel 类型）
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = self.vpnExtensionBundleID
            protocolConfiguration.serverAddress = self.currentNode?.serverAddress ?? "未知服务器"

            // 设置 VPN 配置
            manager.protocolConfiguration = protocolConfiguration
            manager.localizedDescription = self.vpnConfigurationDescription
            manager.isEnabled = true

            // 保存配置到系统
            manager.saveToPreferences { (saveError: Error?) in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        DebugLogger.vpnError("请求VPN权限保存配置失败：\(saveError.localizedDescription)")
                        completion(false, saveError)
                    } else {
                        DebugLogger.vpn("VPN权限请求成功")
                        completion(true, nil)
                    }
                }
            }
        }
    }

    // MARK: - 连接控制

    /// 连接 VPN
    /// 使用当前选中的节点建立 VPN 连接
    /// - Parameter completion: 完成回调
    func connect(completion: ((Error?) -> Void)? = nil) {
        os_log("🚀 开始连接 VPN", log: logger, type: .info)
        DebugLogger.vpnInfo("=== 开始连接 VPN ===")

        // 检查是否有选中的节点
        guard let node = currentNode else {
            let error = NSError(domain: "VPNManager", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "请先选择一个节点"])
            os_log("❌ 连接失败：未选择节点", log: logger, type: .error)
            DebugLogger.vpnError("连接失败：未选择节点")
            completion?(error)
            onConnectionError?(error)
            return
        }

        os_log("📋 使用节点：%{public}@ (%{public}@:%d)", log: logger, type: .info,
               node.remark, node.serverAddress, node.serverPort)
        DebugLogger.vpn("使用节点：\(node.remark) (\(node.serverAddress):\(node.serverPort))")
        DebugLogger.vpn("节点协议：\(node.protocolType.displayName)，UUID：\(node.uuid)")

        // 将当前节点配置保存到 App Group，供 VPN 扩展读取
        saveCurrentNodeToAppGroup(node)
        // 生成 Xray JSON 配置并保存到 App Group，供 VPN 扩展启动 Xray 核心使用
        saveXrayConfigToAppGroup(node)
        os_log("💾 节点配置和 Xray 配置已保存到 App Group", log: logger, type: .debug)

        // 优化：已有配置时直接复用，不删除重建
        // 首次无配置时才创建新配置（系统会弹出权限请求对话框）
        // 配置后再次连接只需更新节点信息，不会重复弹出权限请求
        getOrCreateVPNManager { [weak self] manager in
            guard let self = self else { return }
            self.updateConfigAndStartTunnel(manager: manager, node: node, completion: completion)
        }
    }

    /// 更新 VPN 配置并启动隧道
    /// 已有配置时直接更新节点信息，无需删除重建；首次配置时系统会弹出权限请求
    /// - Parameters:
    ///   - manager: VPN 管理器实例
    ///   - node: VPN 节点
    ///   - completion: 完成回调
    private func updateConfigAndStartTunnel(manager: NETunnelProviderManager, node: VPNNode, completion: ((Error?) -> Void)?) {
        DebugLogger.vpn("更新VPN配置并启动隧道")
        currentVPNManager = manager

        // 配置协议（复用已有配置，只更新节点信息）
        let protocolConfiguration: NETunnelProviderProtocol
        if let existingConfig = manager.protocolConfiguration as? NETunnelProviderProtocol {
            // 复用已有协议配置，只更新节点相关字段
            protocolConfiguration = existingConfig
            DebugLogger.vpn("复用已有协议配置，更新节点信息")
        } else {
            // 没有有效协议配置，创建新的（首次配置）
            protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = vpnExtensionBundleID
            DebugLogger.vpn("创建新的协议配置（首次配置）")
        }

        // 更新节点信息
        protocolConfiguration.serverAddress = "\(node.serverAddress):\(node.serverPort)"

        // 设置 providerConfiguration，传递节点信息给扩展
        let providerConfig: [String: Any] = [
            "node_remark": node.remark,
            "node_server": node.serverAddress,
            "node_port": node.serverPort,
            "node_uuid": node.uuid,
            "node_protocol": node.protocolType.rawValue,
            "node_transport": node.transportType.rawValue,
            "node_enable_tls": node.enableTLS
        ]
        protocolConfiguration.providerConfiguration = providerConfig

        manager.protocolConfiguration = protocolConfiguration
        manager.localizedDescription = vpnConfigurationDescription
        manager.isEnabled = true

        DebugLogger.vpn("VPN配置已更新")
        DebugLogger.vpn("serverAddress: \(protocolConfiguration.serverAddress ?? "未知")")

        // 保存配置（首次配置时系统会弹出权限请求，已有配置时不会弹出）
        manager.saveToPreferences { [weak self] (saveError: Error?) in
            guard let self = self else { return }

            if let saveError = saveError {
                DebugLogger.vpnError("保存VPN配置失败：\(saveError.localizedDescription) (code: \((saveError as NSError).code))")
                DebugLogger.vpnError("错误域：\((saveError as NSError).domain)")
                DispatchQueue.main.async {
                    completion?(saveError)
                    self.onConnectionError?(saveError)
                }
                return
            }

            DebugLogger.vpn("VPN配置保存成功")

            // 保存后重新加载配置
            manager.loadFromPreferences { [weak self] (reloadError: Error?) in
                guard let self = self else { return }

                if let reloadError = reloadError {
                    DebugLogger.vpnError("重新加载VPN配置失败：\(reloadError.localizedDescription)")
                    DispatchQueue.main.async {
                        completion?(reloadError)
                        self.onConnectionError?(reloadError)
                    }
                    return
                }

                // 确保协议配置类型正确
                guard manager.protocolConfiguration is NETunnelProviderProtocol else {
                    let configError = NSError(
                        domain: "VPNManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "VPN 配置类型错误，请重新添加 VPN 配置"]
                    )
                    DebugLogger.vpnError("VPN配置类型错误")
                    DispatchQueue.main.async {
                        completion?(configError)
                        self.onConnectionError?(configError)
                    }
                    return
                }

                DebugLogger.vpn("协议配置校验通过，准备启动隧道")

                // 启动 VPN 隧道
                do {
                    try manager.connection.startVPNTunnel()
                    os_log("✅ VPN 隧道启动命令已发送", log: self.logger, type: .info)
                    DebugLogger.vpnInfo("VPN隧道启动命令已发送，等待状态变化...")
                    DispatchQueue.main.async {
                        completion?(nil)
                    }
                } catch {
                    DebugLogger.vpnError("启动VPN隧道失败：\(error.localizedDescription)")
                    DebugLogger.vpnError("错误码：\((error as NSError).code)")
                    DebugLogger.vpnError("错误域：\((error as NSError).domain)")
                    DispatchQueue.main.async {
                        completion?(error)
                        self.onConnectionError?(error)
                    }
                }
            }
        }
    }

    /// 断开 VPN 连接
    func disconnect() {
        os_log("🛑 断开 VPN 连接", log: logger, type: .info)
        DebugLogger.vpnInfo("断开 VPN 连接")

        // 优先使用当前管理器
        if let manager = currentVPNManager {
            manager.connection.stopVPNTunnel()
            return
        }

        // 如果当前管理器不存在，从配置列表中查找
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            guard let self = self else { return }
            if let manager = managers?.first(where: { $0.localizedDescription == self.vpnConfigurationDescription }) {
                manager.connection.stopVPNTunnel()
                self.currentVPNManager = manager
            }
        }
    }

    /// 切换连接状态（连接则断开，断开则连接）
    func toggleConnection(completion: ((Error?) -> Void)? = nil) {
        if connectionStatus.isActive {
            disconnect()
            completion?(nil)
        } else {
            connect(completion: completion)
        }
    }

    // MARK: - 节点管理

    /// 添加节点
    /// - Parameter node: 要添加的节点
    func addNode(_ node: VPNNode) {
        // 检查是否已存在相同节点（通过 UUID 和服务器地址判断）
        if !nodes.contains(where: { $0.id == node.id }) {
            nodes.append(node)
            saveNodes()
            DebugLogger.vpn("添加节点：\(node.remark)")
        }
    }

    /// 删除节点
    /// - Parameter node: 要删除的节点
    func removeNode(_ node: VPNNode) {
        nodes.removeAll { $0.id == node.id }
        saveNodes()
        // 如果删除的是当前选中的节点，清空当前节点
        if currentNode?.id == node.id {
            currentNode = nil
            saveCurrentNodeToAppGroup(nil)
        }
        DebugLogger.vpn("删除节点：\(node.remark)")
    }

    /// 批量删除节点
    /// - Parameter nodesToRemove: 要删除的节点数组
    func removeNodes(_ nodesToRemove: [VPNNode]) {
        for node in nodesToRemove {
            nodes.removeAll { $0.id == node.id }
            // 如果删除的是当前选中的节点，清空当前节点
            if currentNode?.id == node.id {
                currentNode = nil
                saveCurrentNodeToAppGroup(nil)
            }
        }
        saveNodes()
        DebugLogger.vpn("批量删除 \(nodesToRemove.count) 个节点")
    }

    /// 选择节点
    /// - Parameter node: 要选择的节点
    func selectNode(_ node: VPNNode) {
        currentNode = node
        saveCurrentNode()
        DebugLogger.vpn("选择节点：\(node.remark)")
    }

    // MARK: - 节点测速

    /// 测试节点延迟（TCP 连接测试）
    /// - Parameters:
    ///   - node: 要测试的节点
    ///   - completion: 完成回调（成功返回延迟毫秒数，失败返回错误）
    func testNodeLatency(_ node: VPNNode, completion: @escaping (Result<Int, Error>) -> Void) {
        let host = NWEndpoint.Host(node.serverAddress)
        let port = NWEndpoint.Port(rawValue: UInt16(node.serverPort)) ?? 443

        let connection = NWConnection(host: host, port: port, using: .tcp)

        // 记录开始时间
        let startTime = Date()

        // 设置超时（5秒）
        let timeoutWorkItem = DispatchWorkItem {
            connection.cancel()
            let error = NSError(domain: "VPNManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "连接超时（5秒）"])
            completion(.failure(error))
        }

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // 连接成功，计算延迟
                timeoutWorkItem.cancel()
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                connection.cancel()

                // 更新节点延迟
                if let index = self.nodes.firstIndex(where: { $0.id == node.id }) {
                    self.nodes[index].latency = latency
                    self.nodes[index].lastSpeedTest = Date()
                    self.saveNodes()
                }

                DebugLogger.vpn("节点测速成功：\(node.remark) 延迟 \(latency)ms")
                completion(.success(latency))

            case .failed(let error):
                timeoutWorkItem.cancel()
                DebugLogger.vpn("节点测速失败：\(node.remark) 错误 \(error.localizedDescription)")
                completion(.failure(error))

            case .cancelled:
                break

            default:
                break
            }
        }

        // 启动连接
        connection.start(queue: .global())

        // 设置超时
        DispatchQueue.global().asyncAfter(deadline: .now() + 5, execute: timeoutWorkItem)
    }

    /// 批量测试所有节点延迟
    /// - Parameters:
    ///   - nodes: 要测试的节点列表
    ///   - progress: 进度回调（当前完成数，总数）
    ///   - completion: 全部完成回调
    func testAllNodesLatency(nodes: [VPNNode], progress: @escaping (_ completed: Int, _ total: Int) -> Void, completion: @escaping () -> Void) {
        let total = nodes.count
        guard total > 0 else {
            completion()
            return
        }

        var completed = 0
        let group = DispatchGroup()

        for node in nodes {
            group.enter()
            testNodeLatency(node) { _ in
                completed += 1
                progress(completed, total)
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion()
        }
    }

    /// 加载节点列表（从本地存储）
    private func loadNodes() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = documentsDirectory.appendingPathComponent(nodesFileName)
        guard let data = try? Data(contentsOf: fileURL),
              let decodedNodes = try? JSONDecoder().decode([VPNNode].self, from: data) else {
            return
        }
        nodes = decodedNodes
    }

    /// 保存节点列表（到本地存储）
    private func saveNodes() {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        let fileURL = documentsDirectory.appendingPathComponent(nodesFileName)
        if let data = try? JSONEncoder().encode(nodes) {
            try? data.write(to: fileURL)
        }
    }

    /// 加载当前选中的节点
    private func loadCurrentNode() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let nodeData = sharedDefaults.data(forKey: currentNodeKey),
              let node = try? JSONDecoder().decode(VPNNode.self, from: nodeData) else {
            return
        }
        currentNode = node
    }

    /// 保存当前选中的节点
    private func saveCurrentNode() {
        guard let node = currentNode,
              let nodeData = try? JSONEncoder().encode(node),
              let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        sharedDefaults.set(nodeData, forKey: currentNodeKey)
        sharedDefaults.synchronize()
    }

    /// 将当前节点配置保存到 App Group，供 VPN 扩展读取
    /// - Parameter node: VPN 节点，传 nil 表示清空
    private func saveCurrentNodeToAppGroup(_ node: VPNNode?) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        if let node = node {
            // 将 VPNNode 转换为 [String: Any] 字典，与 PacketTunnelProvider 读取格式一致
            let nodeDict: [String: Any] = [
                "node_remark": node.remark,
                "node_server": node.serverAddress,
                "node_port": node.serverPort,
                "node_uuid": node.uuid,
                "node_protocol": node.protocolType.rawValue,
                "node_transport": node.transportType.rawValue,
                "node_enable_tls": node.enableTLS,
                "node_ws_host": node.tlsServerName ?? node.wsHost ?? "",
                "node_ws_path": node.wsPath ?? "/",
                "node_flow": node.flow ?? ""
            ]
            if let nodeData = try? JSONSerialization.data(withJSONObject: nodeDict) {
                sharedDefaults.set(nodeData, forKey: currentNodeKey)
            }
        } else {
            sharedDefaults.removeObject(forKey: currentNodeKey)
        }
        sharedDefaults.synchronize()
    }

    // MARK: - Xray 配置生成

    /// 生成 Xray JSON 配置并保存到 App Group
    ///
    /// 配置结构：
    /// - log: 日志级别
    /// - inbounds: TUN 入站（dokodemo-door，捕获所有流量）
    /// - outbounds: 代理出站（根据节点类型生成 VLESS/VMess/Trojan/Shadowsocks 配置）
    ///
    /// - Parameter node: VPN 节点
    private func saveXrayConfigToAppGroup(_ node: VPNNode) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }

        let config = generateXrayConfig(from: node)

        if let configData = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted),
           let configString = String(data: configData, encoding: .utf8) {
            sharedDefaults.set(configString, forKey: xrayConfigKey)
            sharedDefaults.synchronize()
            DebugLogger.vpn("Xray 配置已保存到 App Group（\(configString.count) 字节）")
        } else {
            DebugLogger.vpnError("生成 Xray 配置失败")
        }
    }

    /// 根据 VPN 节点生成 Xray 配置字典
    /// - Parameter node: VPN 节点
    /// - Returns: Xray 配置字典
    private func generateXrayConfig(from node: VPNNode) -> [String: Any] {
        // 出站配置（根据协议类型生成）
        let outbound = generateOutboundConfig(from: node)

        // 完整配置
        // 注意：使用 StartXray(config, tunFd) 时，Xray 核心会自动处理 TUN 设备
        // 不需要手动配置 inbound，Xray 会自动创建 tun inbound
        let config: [String: Any] = [
            // 日志配置（仅设置级别，不设置文件路径，避免文件写入失败）
            "log": [
                "loglevel": "warning"
            ],
            // 出站配置
            "outbounds": [outbound],
            // 路由配置
            "routing": [
                "domainStrategy": "IPIfNonMatch",
                "rules": []
            ],
            // DNS 配置
            "dns": [
                "servers": ["1.1.1.1", "8.8.8.8"]
            ]
        ]

        return config
    }

    /// 生成出站配置（根据节点协议类型）
    /// - Parameter node: VPN 节点
    /// - Returns: 出站配置字典
    private func generateOutboundConfig(from node: VPNNode) -> [String: Any] {
        // 流设置（传输层配置）
        let streamSettings = generateStreamSettings(from: node)

        switch node.protocolType {
        case .vless:
            // VLESS 协议配置
            var user: [String: Any] = [
                "id": node.uuid,
                "encryption": "none"
            ]
            // VLESS flow（如 xtls-rprx-vision）
            if let flow = node.flow, !flow.isEmpty {
                user["flow"] = flow
            }

            return [
                "tag": "proxy",
                "protocol": "vless",
                "settings": [
                    "vnext": [
                        [
                            "address": node.serverAddress,
                            "port": node.serverPort,
                            "users": [user]
                        ]
                    ]
                ],
                "streamSettings": streamSettings
            ]

        case .vmess:
            // VMess 协议配置
            return [
                "tag": "proxy",
                "protocol": "vmess",
                "settings": [
                    "vnext": [
                        [
                            "address": node.serverAddress,
                            "port": node.serverPort,
                            "users": [
                                [
                                    "id": node.uuid,
                                    "alterId": 0,
                                    "security": "auto"
                                ]
                            ]
                        ]
                    ]
                ],
                "streamSettings": streamSettings
            ]

        case .trojan:
            // Trojan 协议配置（密码存储在 uuid 字段）
            return [
                "tag": "proxy",
                "protocol": "trojan",
                "settings": [
                    "servers": [
                        [
                            "address": node.serverAddress,
                            "port": node.serverPort,
                            "password": node.uuid
                        ]
                    ]
                ],
                "streamSettings": streamSettings
            ]

        case .shadowsocks:
            // Shadowsocks 协议配置（密码存储在 uuid 字段，加密方式需额外字段）
            return [
                "tag": "proxy",
                "protocol": "shadowsocks",
                "settings": [
                    "servers": [
                        [
                            "address": node.serverAddress,
                            "port": node.serverPort,
                            "password": node.uuid,
                            "method": "aes-256-gcm"
                        ]
                    ]
                ],
                "streamSettings": streamSettings
            ]

        case .hysteria, .tuic:
            // Hysteria 和 TUIC 协议：Xray-core 暂不直接支持，回退为 VLESS 配置
            // 注意：这两种协议基于 QUIC，需要专用客户端支持
            DebugLogger.vpnError("不支持的协议类型：\(node.protocolType.displayName)，回退为 VLESS 配置")
            return [
                "tag": "proxy",
                "protocol": "vless",
                "settings": [
                    "vnext": [
                        [
                            "address": node.serverAddress,
                            "port": node.serverPort,
                            "users": [
                                [
                                    "id": node.uuid,
                                    "encryption": "none"
                                ]
                            ]
                        ]
                    ]
                ],
                "streamSettings": streamSettings
            ]
        }
    }

    /// 生成流设置（传输层配置）
    /// - Parameter node: VPN 节点
    /// - Returns: 流设置字典
    private func generateStreamSettings(from node: VPNNode) -> [String: Any] {
        var streamSettings: [String: Any] = [:]

        // 传输类型
        switch node.transportType {
        case .tcp:
            streamSettings["network"] = "tcp"
            streamSettings["tcpSettings"] = [
                "header": ["type": "none"]
            ]

        case .websocket:
            streamSettings["network"] = "ws"
            var wsSettings: [String: Any] = [
                "path": node.wsPath ?? "/"
            ]
            // WebSocket Host 头
            let wsHost = node.wsHost ?? node.tlsServerName ?? node.serverAddress
            wsSettings["headers"] = ["Host": wsHost]
            streamSettings["wsSettings"] = wsSettings

        case .grpc:
            streamSettings["network"] = "grpc"
            streamSettings["grpcSettings"] = [
                "serviceName": node.grpcServiceName ?? "",
                "multiMode": false
            ]

        case .http2:
            streamSettings["network"] = "http"
            streamSettings["httpSettings"] = [
                "host": [node.tlsServerName ?? node.serverAddress],
                "path": node.wsPath ?? "/"
            ]

        case .mkcp:
            // mKCP 传输（基于 KCP，低延迟）
            streamSettings["network"] = "kcp"
            streamSettings["kcpSettings"] = [
                "mtu": 1350,
                "tti": 20,
                "uplinkCapacity": 5,
                "downlinkCapacity": 20,
                "congestion": false,
                "readBufferSize": 1,
                "writeBufferSize": 1,
                "header": ["type": "none"]
            ]

        case .quic:
            // QUIC 传输（基于 UDP）
            streamSettings["network"] = "quic"
            streamSettings["quicSettings"] = [
                "security": "none",
                "key": "",
                "header": ["type": "none"]
            ]
        }

        // 安全设置（TLS / Reality / 无加密）
        if node.enableTLS {
            if let flow = node.flow, flow.contains("vision") {
                // XTLS Vision 使用 TLS
                streamSettings["security"] = "tls"
                streamSettings["tlsSettings"] = [
                    "serverName": node.tlsServerName ?? node.serverAddress,
                    "allowInsecure": false,
                    "fingerprint": "chrome"
                ]
            } else {
                // 普通 TLS
                streamSettings["security"] = "tls"
                streamSettings["tlsSettings"] = [
                    "serverName": node.tlsServerName ?? node.serverAddress,
                    "allowInsecure": false
                ]
            }
        } else {
            // 无加密（明文传输）
            streamSettings["security"] = "none"
        }

        return streamSettings
    }

    // MARK: - VPN 状态监听

    /// 设置 VPN 状态变化监听器
    private func setupVPNStatusObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vpnStatusDidChange(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
        // 初始化当前状态（从当前管理器或默认断开）
        if let manager = currentVPNManager {
            connectionStatus = VPNConnectionStatus(from: manager.connection.status)
        }
    }

    /// VPN 状态变化处理
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        // 从通知对象获取状态，或从当前管理器获取
        let newStatus: VPNConnectionStatus
        if let session = notification.object as? NETunnelProviderSession {
            newStatus = VPNConnectionStatus(from: session.status)
        } else if let manager = currentVPNManager {
            newStatus = VPNConnectionStatus(from: manager.connection.status)
        } else {
            newStatus = .disconnected
        }

        let oldStatus = connectionStatus
        connectionStatus = newStatus
        DebugLogger.vpnInfo("VPN状态变化：\(oldStatus.displayText) → \(newStatus.displayText)")

        // 当从连接中变为断开时，延迟读取 App Group 文件日志（第一期重构：文件日志替代 UserDefaults 字符串日志）
        if oldStatus == .connecting && (newStatus == .disconnecting || newStatus == .disconnected) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.读取扩展文件日志()
            }
        }
    }

    /// 读取扩展写入 App Group 的启动链路日志
    /// 日志位置：<AppGroup容器>/vpn扩展日志/隧道启动日志.log
    private func 读取扩展文件日志() {
        guard let 容器目录 = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            DebugLogger.vpnError("无法访问 App Group 容器，无法读取扩展日志")
            return
        }

        let 日志文件 = 容器目录
            .appendingPathComponent("vpn扩展日志", isDirectory: true)
            .appendingPathComponent("隧道启动日志.log")

        guard FileManager.default.fileExists(atPath: 日志文件.path),
              let 日志内容 = try? String(contentsOf: 日志文件, encoding: .utf8),
              !日志内容.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            DebugLogger.vpn("扩展文件日志为空")
            return
        }

        DebugLogger.vpn("========== 扩展启动日志开始 ==========")
        日志内容
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .forEach { DebugLogger.vpn($0) }
        DebugLogger.vpn("========== 扩展启动日志结束 ==========")
    }

    // MARK: - 与 VPN 扩展通信

    /// 向 VPN 扩展发送消息
    /// - Parameters:
    ///   - message: 消息字符串
    ///   - completion: 回复回调
    func sendMessageToExtension(_ message: String, completion: ((Data?) -> Void)? = nil) {
        guard let manager = currentVPNManager,
              let session = manager.connection as? NETunnelProviderSession else {
            completion?(nil)
            return
        }

        do {
            let data = Data(message.utf8)
            try session.sendProviderMessage(data) { responseData in
                DispatchQueue.main.async {
                    completion?(responseData)
                }
            }
        } catch {
            print("❌ 发送消息到 VPN 扩展失败: \(error.localizedDescription)")
            completion?(nil)
        }
    }

    /// 获取 VPN 扩展状态
    /// - Parameter completion: 状态回调
    func getExtensionStatus(completion: @escaping (Bool, [String: Any]?) -> Void) {
        sendMessageToExtension("getStatus") { responseData in
            guard let data = responseData,
                  let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(false, nil)
                return
            }
            completion(true, status)
        }
    }

    // MARK: - 清理

    /// 移除通知监听器（在 deinit 时调用）
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
