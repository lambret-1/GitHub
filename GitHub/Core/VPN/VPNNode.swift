//
//  VPNNode.swift
//  GitHub
//
//  用途：VPN 节点数据模型，定义节点的所有属性
//  支持协议：VMess、VLESS（第一期），后续扩展 Trojan、Shadowsocks、Hysteria 等
//

import Foundation

// MARK: - VPN 协议类型枚举

/// VPN 协议类型
/// 定义支持的所有代理协议，第一期实现 VMess 和 VLESS
enum VPNProtocolType: String, Codable, CaseIterable, Identifiable {
    case vmess = "vmess"       // VMess 协议（V2Ray 经典协议）
    case vless = "vless"       // VLESS 协议（V2Ray 新一代轻量协议）
    case trojan = "trojan"     // Trojan 协议（伪装 HTTPS）
    case shadowsocks = "ss"    // Shadowsocks 协议（经典轻量协议）
    case hysteria = "hysteria" // Hysteria 协议（基于 QUIC）
    case tuic = "tuic"         // TUIC 协议（基于 QUIC）

    /// 协议显示名称（中文）
    var displayName: String {
        switch self {
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .shadowsocks: return "Shadowsocks"
        case .hysteria: return "Hysteria"
        case .tuic: return "TUIC"
        }
    }

    /// 协议唯一标识（用于 Identifiable）
    var id: String { rawValue }
}

// MARK: - 传输协议类型枚举

/// 传输协议类型
/// 定义底层传输方式，影响流量特征和性能
enum VPNTransportType: String, Codable, CaseIterable, Identifiable {
    case tcp = "tcp"           // TCP 传输（默认，最稳定）
    case websocket = "ws"      // WebSocket 传输（可伪装成 HTTP）
    case grpc = "grpc"         // gRPC 传输（基于 HTTP/2）
    case mkcp = "mkcp"         // mKCP 传输（基于 KCP，低延迟）
    case quic = "quic"         // QUIC 传输（基于 UDP）
    case http2 = "h2"          // HTTP/2 传输

    /// 传输协议显示名称（中文）
    var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .websocket: return "WebSocket"
        case .grpc: return "gRPC"
        case .mkcp: return "mKCP"
        case .quic: return "QUIC"
        case .http2: return "HTTP/2"
        }
    }

    /// 唯一标识
    var id: String { rawValue }
}

// MARK: - 加密方式枚举

/// 加密方式
/// 定义 VMess 协议支持的加密算法
enum VPNEncryptionType: String, Codable, CaseIterable, Identifiable {
    case auto = "auto"                 // 自动选择（推荐）
    case aes128gcm = "aes-128-gcm"    // AES-128-GCM（高性能）
    case aes256gcm = "aes-256-gcm"    // AES-256-GCM（高安全）
    case chacha20poly1305 = "chacha20-poly1305" // ChaCha20-Poly1305（移动设备优化）
    case none = "none"                 // 不加密（仅 VLESS + Reality 可用）

    /// 加密方式显示名称
    var displayName: String {
        switch self {
        case .auto: return "自动"
        case .aes128gcm: return "AES-128-GCM"
        case .aes256gcm: return "AES-256-GCM"
        case .chacha20poly1305: return "ChaCha20-Poly1305"
        case .none: return "不加密"
        }
    }

    /// 唯一标识
    var id: String { rawValue }
}

// MARK: - VPN 节点模型

/// VPN 节点数据模型
/// 存储节点的所有配置信息，支持序列化和持久化
struct VPNNode: Codable, Identifiable, Hashable {

    // MARK: - 基础信息

    /// 节点唯一标识（UUID 格式，自动生成）
    let id: String

    /// 节点备注名称（用户自定义，用于识别节点）
    var remark: String

    /// 节点分组（用户自定义分组，如"免费节点"、"付费节点"）
    var group: String?

    // MARK: - 连接信息

    /// 协议类型（VMess/VLESS/Trojan 等）
    var protocolType: VPNProtocolType

    /// 服务器地址（域名或 IP）
    var serverAddress: String

    /// 服务器端口（1-65535）
    var serverPort: Int

    /// 用户 UUID（VMess/VLESS 的用户标识）
    var uuid: String

    /// 加密方式（VMess 专用，VLESS 通常为 none）
    var encryption: VPNEncryptionType

    // MARK: - 传输配置

    /// 传输协议类型（TCP/WebSocket/gRPC 等）
    var transportType: VPNTransportType

    /// WebSocket 路径（仅 WebSocket 传输时使用）
    var wsPath: String?

    /// WebSocket Host（仅 WebSocket 传输时使用，用于伪装）
    var wsHost: String?

    /// gRPC 服务名称（仅 gRPC 传输时使用）
    var grpcServiceName: String?

    // MARK: - TLS 配置

    /// 是否启用 TLS（传输层加密）
    var enableTLS: Bool

    /// TLS 服务器名称（SNI，用于证书验证和伪装）
    var tlsServerName: String?

    /// 是否跳过证书验证（不推荐，存在安全风险）
    var allowInsecure: Bool

    /// ALPN 协议列表（TLS 应用层协议协商，如 h2、http/1.1）
    var alpn: [String]?

    // MARK: - 流控配置（VLESS 专用）

    /// 流控类型（VLESS 专用，如 xtls-rprx-vision）
    var flow: String?

    // MARK: - 测速信息（运行时数据，不持久化）

    /// 延迟（毫秒，测速结果）
    var latency: Int?

    /// 下载速度（MB/s，测速结果）
    var downloadSpeed: Double?

    /// 最后测速时间
    var lastSpeedTest: Date?

    /// 节点是否可用（测速失败时标记为不可用）
    var isAvailable: Bool?

    // MARK: - 使用统计

    /// 总连接次数
    var connectionCount: Int

    /// 总连接时长（秒）
    var totalConnectionTime: TimeInterval

    /// 最后连接时间
    var lastConnected: Date?

    // MARK: - 其他

    /// 创建时间
    let createdAt: Date

    /// 更新时间
    var updatedAt: Date

    // MARK: - 初始化方法

    /// 初始化节点（基础参数）
    /// - Parameters:
    ///   - remark: 节点备注名称
    ///   - protocolType: 协议类型
    ///   - serverAddress: 服务器地址
    ///   - serverPort: 服务器端口
    ///   - uuid: 用户 UUID
    init(remark: String,
         protocolType: VPNProtocolType,
         serverAddress: String,
         serverPort: Int,
         uuid: String) {
        self.id = UUID().uuidString
        self.remark = remark
        self.group = nil
        self.protocolType = protocolType
        self.serverAddress = serverAddress
        self.serverPort = serverPort
        self.uuid = uuid
        self.encryption = .auto
        self.transportType = .tcp
        self.wsPath = nil
        self.wsHost = nil
        self.grpcServiceName = nil
        self.enableTLS = false
        self.tlsServerName = nil
        self.allowInsecure = false
        self.alpn = nil
        self.flow = nil
        self.latency = nil
        self.downloadSpeed = nil
        self.lastSpeedTest = nil
        self.isAvailable = nil
        self.connectionCount = 0
        self.totalConnectionTime = 0
        self.lastConnected = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // MARK: - 计算属性

    /// 节点显示地址（地址:端口）
    var displayAddress: String {
        "\(serverAddress):\(serverPort)"
    }

    /// 延迟显示文本
    var latencyText: String {
        guard let latency = latency else { return "未测速" }
        return "\(latency)ms"
    }

    /// 延迟颜色（用于 UI 显示）
    /// 绿色：< 100ms，黄色：100-300ms，红色：> 300ms
    var latencyColor: String {
        guard let latency = latency else { return "gray" }
        if latency < 100 { return "green" }
        if latency < 300 { return "yellow" }
        return "red"
    }

    /// 速度显示文本
    var speedText: String {
        guard let speed = downloadSpeed else { return "-" }
        if speed >= 1 {
            return String(format: "%.1f MB/s", speed)
        }
        return String(format: "%.0f KB/s", speed * 1024)
    }

    /// 节点完整描述（用于调试和日志）
    var description: String {
        "[\(protocolType.displayName)] \(remark) - \(displayAddress)"
    }

    // MARK: - Hashable 实现

    /// 哈希比较（仅比较 id）
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// 相等比较（仅比较 id）
    static func == (lhs: VPNNode, rhs: VPNNode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 节点数组扩展

extension Array where Element == VPNNode {

    /// 按延迟排序（延迟低的在前，未测速的在后）
    func sortedByLatency() -> [VPNNode] {
        sorted { node1, node2 in
            let lat1 = node1.latency ?? Int.max
            let lat2 = node2.latency ?? Int.max
            return lat1 < lat2
        }
    }

    /// 按速度排序（速度快的在前，未测速的在后）
    func sortedBySpeed() -> [VPNNode] {
        sorted { node1, node2 in
            let speed1 = node1.downloadSpeed ?? 0
            let speed2 = node2.downloadSpeed ?? 0
            return speed1 > speed2
        }
    }

    /// 按名称排序（字母顺序）
    func sortedByName() -> [VPNNode] {
        sorted { $0.remark.localizedCaseInsensitiveCompare($1.remark) == .orderedAscending }
    }

    /// 按添加时间排序（最新的在前）
    func sortedByDate() -> [VPNNode] {
        sorted { $0.createdAt > $1.createdAt }
    }

    /// 过滤可用节点
    func filterAvailable() -> [VPNNode] {
        filter { $0.isAvailable ?? true }
    }

    /// 按分组分组
    func groupedByGroup() -> [String: [VPNNode]] {
        Dictionary(grouping: self) { $0.group ?? "未分组" }
    }
}
