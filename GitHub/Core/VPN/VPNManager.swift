//
//  VPNManager.swift
//  GitHub
//
//  用途：VPN 管理器，负责 VPN 配置、连接控制、节点管理
//  职责：
//    1. 管理 VPN 配置（NEVPNManager）
//    2. 控制 VPN 连接/断开
//    3. 节点数据持久化存储
//    4. 与 VPN 扩展（PacketTunnelProvider）通信
//    5. 监听 VPN 连接状态变化
//

import Foundation
import NetworkExtension
import UIKit

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

    // MARK: - App Group 标识

    /// App Group 标识，用于与 VPN 扩展共享数据
    /// 必须与 VPNPacketTunnel.entitlements 中配置一致
    private let appGroupIdentifier = "group.com.github.client"

    // MARK: - VPN 配置管理器

    /// NEVPNManager 实例，用于管理 VPN 配置
    private let vpnManager = NEVPNManager.shared()

    // MARK: - 节点存储

    /// 节点列表（所有已添加的节点）
    private(set) var nodes: [VPNNode] = []

    /// 当前选中的节点（用于连接）
    private(set) var currentNode: VPNNode?

    /// 节点存储文件名
    private let nodesFileName = "vpn_nodes.json"

    /// 当前节点存储 Key（用于 App Group 共享）
    private let currentNodeKey = "vpn_current_node"

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

    // MARK: - VPN 权限与配置

    /// 请求 VPN 权限并加载配置
    /// 首次使用 VPN 时需要调用此方法请求系统权限
    /// - Parameter completion: 完成回调，success 为 true 表示权限获取成功
    func requestVPNPermission(completion: @escaping (Bool, Error?) -> Void) {
        vpnManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion(false, error)
                }
                return
            }

            // 配置 VPN 协议（PacketTunnel 类型）
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = "com.github.client.vpn"
            protocolConfiguration.serverAddress = self.currentNode?.serverAddress ?? "未知服务器"
            protocolConfiguration.username = self.currentNode?.uuid

            // 设置 VPN 配置
            self.vpnManager.protocolConfiguration = protocolConfiguration
            self.vpnManager.localizedDescription = "GitHub 中文 VPN"
            self.vpnManager.isEnabled = true

            // 保存配置到系统
            self.vpnManager.saveToPreferences { saveError in
                DispatchQueue.main.async {
                    if let saveError = saveError {
                        completion(false, saveError)
                    } else {
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
        // 检查是否有选中的节点
        guard let node = currentNode else {
            let error = NSError(domain: "VPNManager", code: -1,
                               userInfo: [NSLocalizedDescriptionKey: "请先选择一个节点"])
            completion?(error)
            onConnectionError?(error)
            return
        }

        // 将当前节点配置保存到 App Group，供 VPN 扩展读取
        saveCurrentNodeToAppGroup(node)

        // 加载并更新 VPN 配置
        vpnManager.loadFromPreferences { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                DispatchQueue.main.async {
                    completion?(error)
                    self.onConnectionError?(error)
                }
                return
            }

            // 更新协议配置
            let protocolConfiguration = NETunnelProviderProtocol()
            protocolConfiguration.providerBundleIdentifier = "com.github.client.vpn"
            protocolConfiguration.serverAddress = node.serverAddress
            protocolConfiguration.username = node.uuid

            self.vpnManager.protocolConfiguration = protocolConfiguration
            self.vpnManager.localizedDescription = "GitHub 中文 VPN - \(node.remark)"
            self.vpnManager.isEnabled = true

            // 保存配置
            self.vpnManager.saveToPreferences { saveError in
                if let saveError = saveError {
                    DispatchQueue.main.async {
                        completion?(saveError)
                        self.onConnectionError?(saveError)
                    }
                    return
                }

                // 启动 VPN 隧道
                do {
                    try self.vpnManager.connection.startVPNTunnel()
                    DispatchQueue.main.async {
                        completion?(nil)
                    }
                } catch {
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
        vpnManager.connection.stopVPNTunnel()
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
        nodes.append(node)
        saveNodes()
    }

    /// 删除节点
    /// - Parameter node: 要删除的节点
    func removeNode(_ node: VPNNode) {
        nodes.removeAll { $0.id == node.id }
        // 如果删除的是当前节点，清空当前节点
        if currentNode?.id == node.id {
            currentNode = nil
            clearCurrentNodeFromAppGroup()
        }
        saveNodes()
    }

    /// 更新节点
    /// - Parameter node: 要更新的节点（通过 id 匹配）
    func updateNode(_ node: VPNNode) {
        if let index = nodes.firstIndex(where: { $0.id == node.id }) {
            var updatedNode = node
            updatedNode.updatedAt = Date()
            nodes[index] = updatedNode
            saveNodes()
            // 如果更新的是当前节点，同步更新
            if currentNode?.id == node.id {
                currentNode = updatedNode
                saveCurrentNodeToAppGroup(updatedNode)
            }
        }
    }

    /// 选择节点（设置为当前连接节点）
    /// - Parameter node: 要选择的节点
    func selectNode(_ node: VPNNode) {
        currentNode = node
        saveCurrentNodeToAppGroup(node)
        // 保存当前节点 ID 到本地
        UserDefaults.standard.set(node.id, forKey: "vpn_current_node_id")
    }

    /// 批量删除节点
    /// - Parameter nodes: 要删除的节点数组
    func removeNodes(_ nodesToRemove: [VPNNode]) {
        let idsToRemove = Set(nodesToRemove.map { $0.id })
        nodes.removeAll { idsToRemove.contains($0.id) }
        // 如果当前节点在删除列表中，清空
        if let currentNode = currentNode, idsToRemove.contains(currentNode.id) {
            self.currentNode = nil
            clearCurrentNodeFromAppGroup()
        }
        saveNodes()
    }

    /// 清空所有节点
    func clearAllNodes() {
        nodes.removeAll()
        currentNode = nil
        clearCurrentNodeFromAppGroup()
        saveNodes()
    }

    // MARK: - 节点持久化

    /// 保存节点列表到本地文件
    private func saveNodes() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted

            do {
                let data = try encoder.encode(self.nodes)
                let fileURL = self.getNodesFileURL()
                try data.write(to: fileURL, options: .atomic)
            } catch {
                print("❌ 保存节点列表失败: \(error.localizedDescription)")
            }
        }
    }

    /// 从本地文件加载节点列表
    private func loadNodes() {
        let fileURL = getNodesFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            nodes = try decoder.decode([VPNNode].self, from: data)
        } catch {
            print("❌ 加载节点列表失败: \(error.localizedDescription)")
        }
    }

    /// 获取节点存储文件路径
    /// - Returns: 文件 URL
    private func getNodesFileURL() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent(nodesFileName)
    }

    // MARK: - 当前节点加载

    /// 加载当前选中的节点
    private func loadCurrentNode() {
        if let nodeId = UserDefaults.standard.string(forKey: "vpn_current_node_id"),
           let node = nodes.first(where: { $0.id == nodeId }) {
            currentNode = node
            saveCurrentNodeToAppGroup(node)
        }
    }

    // MARK: - App Group 数据共享

    /// 保存当前节点到 App Group（供 VPN 扩展读取）
    /// - Parameter node: 节点对象
    private func saveCurrentNodeToAppGroup(_ node: VPNNode) {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ 无法访问 App Group 共享数据")
            return
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(node)
            sharedDefaults.set(data, forKey: currentNodeKey)
            sharedDefaults.synchronize()
        } catch {
            print("❌ 保存节点到 App Group 失败: \(error.localizedDescription)")
        }
    }

    /// 清除 App Group 中的当前节点
    private func clearCurrentNodeFromAppGroup() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return
        }
        sharedDefaults.removeObject(forKey: currentNodeKey)
        sharedDefaults.synchronize()
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
        // 初始化当前状态
        connectionStatus = VPNConnectionStatus(from: vpnManager.connection.status)
    }

    /// VPN 状态变化处理
    @objc private func vpnStatusDidChange(_ notification: Notification) {
        let newStatus = VPNConnectionStatus(from: vpnManager.connection.status)
        connectionStatus = newStatus
    }

    // MARK: - 与 VPN 扩展通信

    /// 向 VPN 扩展发送消息
    /// - Parameters:
    ///   - message: 消息字符串
    ///   - completion: 回复回调
    func sendMessageToExtension(_ message: String, completion: ((Data?) -> Void)? = nil) {
        guard let session = vpnManager.connection as? NETunnelProviderSession else {
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
