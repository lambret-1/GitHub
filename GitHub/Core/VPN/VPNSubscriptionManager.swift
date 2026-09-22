//
//  VPNSubscriptionManager.swift
//  GitHub
//
//  用途：VPN 订阅管理器，负责订阅的增删改查、持久化存储、更新拉取
//  功能：
//    1. 订阅列表管理（添加、删除、修改、启用/禁用）
//    2. 订阅持久化存储（UserDefaults + JSON 编码）
//    3. 订阅更新（从 URL 拉取内容并解析为节点）
//    4. 订阅节点与 VPNManager 集成（订阅节点导入到节点列表）
//    5. 订阅状态变化回调（用于 UI 响应式更新）
//

import Foundation

// MARK: - VPN 订阅管理器

/// VPN 订阅管理器
/// 单例模式，全局唯一实例，负责所有订阅相关的业务逻辑
final class VPNSubscriptionManager {

    // MARK: - 单例

    /// 共享实例
    static let shared = VPNSubscriptionManager()

    /// 私有初始化（单例模式）
    private init() {
        loadSubscriptions()
    }

    // MARK: - 持久化键名

    /// 订阅列表存储键名（UserDefaults）
    private let subscriptionsKey = "vpn_subscriptions"

    // MARK: - 数据存储

    /// 订阅列表（内存缓存）
    private(set) var subscriptions: [VPNSubscription] = []

    /// 订阅更新回调（用于 UI 响应式更新）
    var onSubscriptionsChange: (() -> Void)?

    // MARK: - 订阅管理方法

    /// 添加订阅
    /// - Parameters:
    ///   - name: 订阅名称
    ///   - url: 订阅 URL
    ///   - type: 订阅类型（默认自动识别）
    /// - Returns: 新创建的订阅
    @discardableResult
    func addSubscription(name: String, url: String, type: VPNSubscriptionType = .auto) -> VPNSubscription {
        let subscription = VPNSubscription(name: name, url: url, type: type)
        subscriptions.append(subscription)
        saveSubscriptions()
        notifyChange()
        return subscription
    }

    /// 删除订阅
    /// - Parameter subscription: 要删除的订阅
    func removeSubscription(_ subscription: VPNSubscription) {
        // 先移除该订阅关联的节点
        removeNodes(for: subscription)

        // 移除订阅
        subscriptions.removeAll { $0.id == subscription.id }
        saveSubscriptions()
        notifyChange()
    }

    /// 更新订阅信息
    /// - Parameters:
    ///   - subscription: 要更新的订阅
    ///   - name: 新名称（nil 表示不修改）
    ///   - url: 新 URL（nil 表示不修改）
    ///   - type: 新类型（nil 表示不修改）
    func updateSubscription(_ subscription: VPNSubscription, name: String? = nil, url: String? = nil, type: VPNSubscriptionType? = nil) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        if let name = name {
            subscriptions[index].name = name
        }
        if let url = url {
            subscriptions[index].url = url
        }
        if let type = type {
            subscriptions[index].type = type
        }

        saveSubscriptions()
        notifyChange()
    }

    /// 切换订阅启用状态
    /// - Parameter subscription: 要切换的订阅
    func toggleSubscriptionEnabled(_ subscription: VPNSubscription) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        subscriptions[index].isEnabled.toggle()

        // 如果禁用，移除该订阅的节点；如果启用，需要重新更新
        if !subscriptions[index].isEnabled {
            removeNodes(for: subscriptions[index])
        }

        saveSubscriptions()
        notifyChange()
    }

    /// 获取所有启用的订阅
    /// - Returns: 启用的订阅列表
    func enabledSubscriptions() -> [VPNSubscription] {
        return subscriptions.filter { $0.isEnabled }
    }

    // MARK: - 订阅更新方法

    /// 更新单个订阅（从 URL 拉取并解析节点）
    /// - Parameters:
    ///   - subscription: 要更新的订阅
    ///   - completion: 完成回调（成功返回订阅和新节点列表，失败返回错误）
    func updateSubscription(_ subscription: VPNSubscription, completion: @escaping (VPNSubscriptionUpdateResult) -> Void) {
        guard let url = URL(string: subscription.url) else {
            let error = VPNSubscriptionParseError.invalidFormat
            updateSubscriptionStatus(subscription, success: false, error: error.localizedDescription)
            completion(.failure(subscription: subscription, error: error))
            return
        }

        // 创建网络请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // 超时时间30秒
        request.setValue("GitHub-CN-Client/1.0", forHTTPHeaderField: "User-Agent")

        // 执行网络请求
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            // 网络错误处理
            if let error = error {
                let parseError = VPNSubscriptionParseError.networkError(error.localizedDescription)
                self.updateSubscriptionStatus(subscription, success: false, error: parseError.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(subscription: subscription, error: parseError))
                }
                return
            }

            // HTTP 状态码检查
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                let parseError = VPNSubscriptionParseError.httpError(httpResponse.statusCode)
                self.updateSubscriptionStatus(subscription, success: false, error: parseError.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(subscription: subscription, error: parseError))
                }
                return
            }

            // 数据校验
            guard let data = data, !data.isEmpty else {
                let parseError = VPNSubscriptionParseError.emptyContent
                self.updateSubscriptionStatus(subscription, success: false, error: parseError.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(subscription: subscription, error: parseError))
                }
                return
            }

            // 转换为字符串
            guard let content = String(data: data, encoding: .utf8) else {
                let parseError = VPNSubscriptionParseError.invalidFormat
                self.updateSubscriptionStatus(subscription, success: false, error: parseError.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(subscription: subscription, error: parseError))
                }
                return
            }

            // 解析订阅内容
            do {
                let nodes = try VPNSubscriptionParser.shared.parse(content: content, type: subscription.type)
                self.processParsedNodes(nodes, for: subscription)
                self.updateSubscriptionStatus(subscription, success: true, error: nil, nodeCount: nodes.count)
                DispatchQueue.main.async {
                    completion(.success(subscription: subscription, newNodes: nodes))
                }
            } catch {
                let parseError = error as? VPNSubscriptionParseError ?? VPNSubscriptionParseError.invalidFormat
                self.updateSubscriptionStatus(subscription, success: false, error: parseError.localizedDescription)
                DispatchQueue.main.async {
                    completion(.failure(subscription: subscription, error: parseError))
                }
            }
        }

        task.resume()
    }

    /// 更新所有启用的订阅
    /// - Parameter completion: 全部完成回调（返回成功和失败的数量）
    func updateAllSubscriptions(completion: @escaping (_ successCount: Int, _ failureCount: Int) -> Void) {
        let enabled = enabledSubscriptions()
        guard !enabled.isEmpty else {
            completion(0, 0)
            return
        }

        var successCount = 0
        var failureCount = 0
        let group = DispatchGroup()

        for subscription in enabled {
            group.enter()
            updateSubscription(subscription) { result in
                switch result {
                case .success:
                    successCount += 1
                case .failure:
                    failureCount += 1
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            completion(successCount, failureCount)
        }
    }

    // MARK: - 私有方法

    /// 处理解析出的节点（导入到 VPNManager）
    /// - Parameters:
    ///   - nodes: 解析出的节点列表
    ///   - subscription: 关联的订阅
    private func processParsedNodes(_ nodes: [VPNNode], for subscription: VPNSubscription) {
        // 先移除该订阅旧的节点
        removeNodes(for: subscription)

        // 将新节点添加到 VPNManager，并记录节点 ID
        var nodeIds: [String] = []
        for node in nodes {
            var newNode = node
            newNode.group = subscription.name // 设置分组为订阅名称
            VPNManager.shared.addNode(newNode)
            nodeIds.append(newNode.id)
        }

        // 更新订阅的节点 ID 列表
        if let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            subscriptions[index].nodeIds = nodeIds
            subscriptions[index].nodeCount = nodes.count
            saveSubscriptions()
        }
    }

    /// 移除订阅关联的节点
    /// - Parameter subscription: 订阅
    private func removeNodes(for subscription: VPNSubscription) {
        let nodeIds = subscription.nodeIds
        guard !nodeIds.isEmpty else { return }

        // 从 VPNManager 中移除这些节点
        let nodesToRemove = VPNManager.shared.nodes.filter { nodeIds.contains($0.id) }
        VPNManager.shared.removeNodes(nodesToRemove)
    }

    /// 更新订阅状态（最后更新时间、成功/失败、错误信息）
    /// - Parameters:
    ///   - subscription: 订阅
    ///   - success: 是否成功
    ///   - error: 错误信息（成功时为 nil）
    ///   - nodeCount: 节点数量（成功时有效）
    private func updateSubscriptionStatus(_ subscription: VPNSubscription, success: Bool, error: String?, nodeCount: Int = 0) {
        guard let index = subscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }

        subscriptions[index].lastUpdated = Date()
        subscriptions[index].lastUpdateSuccess = success
        subscriptions[index].lastUpdateError = error
        if success {
            subscriptions[index].nodeCount = nodeCount
        }

        saveSubscriptions()
        notifyChange()
    }

    // MARK: - 持久化方法

    /// 保存订阅列表到 UserDefaults
    private func saveSubscriptions() {
        do {
            let data = try JSONEncoder().encode(subscriptions)
            UserDefaults.standard.set(data, forKey: subscriptionsKey)
        } catch {
            // 编码失败，静默处理（不影响运行）
        }
    }

    /// 从 UserDefaults 加载订阅列表
    private func loadSubscriptions() {
        guard let data = UserDefaults.standard.data(forKey: subscriptionsKey) else {
            subscriptions = []
            return
        }

        do {
            subscriptions = try JSONDecoder().decode([VPNSubscription].self, from: data)
        } catch {
            // 解码失败，清空列表
            subscriptions = []
        }
    }

    /// 通知订阅变化（调用回调）
    private func notifyChange() {
        DispatchQueue.main.async { [weak self] in
            self?.onSubscriptionsChange?()
        }
    }
}

// MARK: - VPN 订阅管理器可观察对象（用于 SwiftUI 响应式更新）

/// VPN 订阅管理器可观察对象
/// 因为 VPNSubscriptionManager 是 NSObject 子类风格的单例，不能直接用 @Observable
/// 使用这个包装类在 SwiftUI 视图中实现响应式更新
final class VPNSubscriptionObservable: ObservableObject {

    /// 订阅列表
    @Published var subscriptions: [VPNSubscription] = []

    /// 是否正在更新
    @Published var isUpdating = false

    /// 初始化
    init() {
        refresh()

        // 监听订阅变化
        VPNSubscriptionManager.shared.onSubscriptionsChange = { [weak self] in
            self?.refresh()
        }
    }

    /// 刷新数据
    func refresh() {
        subscriptions = VPNSubscriptionManager.shared.subscriptions
    }

    /// 添加订阅
    @discardableResult
    func addSubscription(name: String, url: String, type: VPNSubscriptionType = .auto) -> VPNSubscription {
        return VPNSubscriptionManager.shared.addSubscription(name: name, url: url, type: type)
    }

    /// 删除订阅
    func removeSubscription(_ subscription: VPNSubscription) {
        VPNSubscriptionManager.shared.removeSubscription(subscription)
    }

    /// 切换订阅启用状态
    func toggleSubscriptionEnabled(_ subscription: VPNSubscription) {
        VPNSubscriptionManager.shared.toggleSubscriptionEnabled(subscription)
    }

    /// 更新单个订阅
    func updateSubscription(_ subscription: VPNSubscription, completion: @escaping (VPNSubscriptionUpdateResult) -> Void = { _ in }) {
        isUpdating = true
        VPNSubscriptionManager.shared.updateSubscription(subscription) { [weak self] result in
            DispatchQueue.main.async {
                self?.isUpdating = false
                completion(result)
            }
        }
    }

    /// 更新所有订阅
    func updateAllSubscriptions(completion: @escaping (_ successCount: Int, _ failureCount: Int) -> Void = { _, _ in }) {
        isUpdating = true
        VPNSubscriptionManager.shared.updateAllSubscriptions { [weak self] successCount, failureCount in
            DispatchQueue.main.async {
                self?.isUpdating = false
                completion(successCount, failureCount)
            }
        }
    }
}
