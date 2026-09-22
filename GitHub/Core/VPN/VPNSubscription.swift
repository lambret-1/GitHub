//
//  VPNSubscription.swift
//  GitHub
//
//  用途：VPN 订阅数据模型，支持小火箭（Shadowrocket）和圈X（Quantumult X）订阅格式
//  功能：
//    1. 订阅基本信息（名称、URL、类型、更新时间）
//    2. 订阅节点列表（解析后存储）
//    3. 订阅类型枚举（小火箭/圈X/自动识别）
//

import Foundation

// MARK: - 订阅类型枚举

/// VPN 订阅类型
/// 定义支持的订阅格式，自动识别模式会尝试多种格式解析
enum VPNSubscriptionType: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"           // 自动识别（尝试小火箭→圈X→明文）
    case shadowrocket = "shadowrocket" // 小火箭格式（base64编码的节点链接列表）
    case quantumultX = "quantumultx"  // 圈X格式（[server]段配置或JSON）

    /// 订阅类型显示名称（中文）
    var displayName: String {
        switch self {
        case .auto: return "自动识别"
        case .shadowrocket: return "小火箭"
        case .quantumultX: return "圈X"
        }
    }

    /// 唯一标识（用于 Identifiable）
    var id: String { rawValue }
}

// MARK: - VPN 订阅模型

/// VPN 订阅模型
/// 表示一个订阅源，包含订阅URL和从该订阅解析出的节点列表
struct VPNSubscription: Codable, Identifiable, Hashable {

    // MARK: - 基本属性

    /// 订阅唯一标识（UUID）
    let id: String

    /// 订阅名称（用户自定义或从订阅响应头获取）
    var name: String

    /// 订阅 URL（完整链接）
    var url: String

    /// 订阅类型（小火箭/圈X/自动识别）
    var type: VPNSubscriptionType

    // MARK: - 状态属性

    /// 订阅是否启用（禁用的订阅不会导入节点）
    var isEnabled: Bool

    /// 最后更新时间（成功拉取并解析的时间）
    var lastUpdated: Date?

    /// 最后更新结果（成功/失败）
    var lastUpdateSuccess: Bool

    /// 最后更新错误信息（失败时记录）
    var lastUpdateError: String?

    // MARK: - 节点数据

    /// 订阅包含的节点数量
    var nodeCount: Int

    /// 订阅的节点 ID 列表（关联 VPNNode 的 id，节点实际存储在 VPNManager 中）
    var nodeIds: [String]

    // MARK: - 初始化方法

    /// 初始化订阅
    /// - Parameters:
    ///   - name: 订阅名称
    ///   - url: 订阅 URL
    ///   - type: 订阅类型（默认自动识别）
    init(name: String, url: String, type: VPNSubscriptionType = .auto) {
        self.id = UUID().uuidString
        self.name = name
        self.url = url
        self.type = type
        self.isEnabled = true
        self.lastUpdated = nil
        self.lastUpdateSuccess = false
        self.lastUpdateError = nil
        self.nodeCount = 0
        self.nodeIds = []
    }

    // MARK: - 计算属性

    /// 最后更新时间的中文显示文本
    var lastUpdatedText: String {
        guard let date = lastUpdated else { return "从未更新" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// 订阅状态显示文本
    var statusText: String {
        if lastUpdateSuccess {
            return "已更新（\(nodeCount) 个节点）"
        } else if let error = lastUpdateError {
            return "更新失败：\(error)"
        } else {
            return "待更新"
        }
    }

    // MARK: - Hashable 实现

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VPNSubscription, rhs: VPNSubscription) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 订阅更新结果枚举

/// 订阅更新结果
/// 用于回调通知订阅更新的成功或失败
enum VPNSubscriptionUpdateResult {
    case success(subscription: VPNSubscription, newNodes: [VPNNode])
    case failure(subscription: VPNSubscription, error: Error)
}

// MARK: - 订阅解析错误枚举

/// 订阅解析错误
/// 定义订阅解析过程中可能出现的错误类型
enum VPNSubscriptionParseError: LocalizedError {
    case emptyContent           // 订阅内容为空
    case invalidBase64          // Base64 解码失败
    case noValidNodes           // 没有解析到有效节点
    case invalidFormat          // 格式无法识别
    case networkError(String)   // 网络错误（附带错误描述）
    case httpError(Int)         // HTTP 错误（附带状态码）

    /// 错误描述（中文）
    var errorDescription: String? {
        switch self {
        case .emptyContent:
            return "订阅内容为空"
        case .invalidBase64:
            return "Base64 解码失败，订阅格式不正确"
        case .noValidNodes:
            return "未解析到有效节点，请检查订阅链接是否正确"
        case .invalidFormat:
            return "无法识别的订阅格式"
        case .networkError(let message):
            return "网络错误：\(message)"
        case .httpError(let code):
            return "HTTP 错误：状态码 \(code)"
        }
    }
}
