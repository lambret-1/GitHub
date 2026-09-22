//
//  VPNSubscriptionParser.swift
//  GitHub
//
//  用途：VPN 订阅解析器，支持解析小火箭（Shadowrocket）和圈X（Quantumult X）订阅格式
//  功能：
//    1. 小火箭格式：base64 编码的节点链接列表（每行一个 vmess://、vless://、trojan://、ss://）
//    2. 圈X格式：[server] 段配置或 base64 编码的节点列表
//    3. 自动识别：尝试多种格式解析，返回第一个成功的结果
//    4. 复用 VPNNodeImporter 解析单个节点链接
//

import Foundation

// MARK: - VPN 订阅解析器

/// VPN 订阅解析器
/// 负责将订阅 URL 返回的原始内容解析为 VPNNode 节点列表
/// 支持小火箭和圈X两种主流订阅格式，以及自动识别模式
final class VPNSubscriptionParser {

    // MARK: - 单例

    /// 共享实例
    static let shared = VPNSubscriptionParser()

    /// 私有初始化（单例模式）
    private init() {}

    // MARK: - 公共解析方法

    /// 解析订阅内容
    /// - Parameters:
    ///   - content: 订阅 URL 返回的原始内容（可能是 base64 或明文）
    ///   - type: 订阅类型（小火箭/圈X/自动识别）
    /// - Returns: 解析出的节点列表
    /// - Throws: VPNSubscriptionParseError 解析错误
    func parse(content: String, type: VPNSubscriptionType) throws -> [VPNNode] {
        // 内容为空检查
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw VPNSubscriptionParseError.emptyContent
        }

        // 根据订阅类型选择解析方式
        switch type {
        case .shadowrocket:
            return try parseShadowrocket(content: trimmedContent)
        case .quantumultX:
            return try parseQuantumultX(content: trimmedContent)
        case .auto:
            return try parseAuto(content: trimmedContent)
        }
    }

    // MARK: - 自动识别解析

    /// 自动识别格式并解析
    /// 尝试顺序：小火箭 base64 → 圈X [server] → 明文节点链接
    /// - Parameter content: 原始内容
    /// - Returns: 解析出的节点列表
    /// - Throws: 所有格式都解析失败时抛出错误
    private func parseAuto(content: String) throws -> [VPNNode] {
        // 尝试1：小火箭 base64 格式
        if let nodes = try? parseShadowrocket(content: content), !nodes.isEmpty {
            return nodes
        }

        // 尝试2：圈X [server] 段格式
        if let nodes = try? parseQuantumultX(content: content), !nodes.isEmpty {
            return nodes
        }

        // 尝试3：明文节点链接列表（每行一个链接）
        if let nodes = try? parsePlainLinks(content: content), !nodes.isEmpty {
            return nodes
        }

        // 所有格式都失败
        throw VPNSubscriptionParseError.noValidNodes
    }

    // MARK: - 小火箭格式解析

    /// 解析小火箭（Shadowrocket）订阅格式
    /// 小火箭订阅通常是 base64 编码的文本，解码后每行是一个节点链接
    /// 也可能直接是明文的节点链接列表
    /// - Parameter content: 原始内容
    /// - Returns: 解析出的节点列表
    /// - Throws: 解析错误
    private func parseShadowrocket(content: String) throws -> [VPNNode] {
        var decodedContent = content

        // 尝试 base64 解码（小火箭标准格式是 base64 编码）
        if let decoded = decodeBase64(content) {
            decodedContent = decoded
        }

        // 按行分割，解析每个节点链接
        let lines = decodedContent.components(separatedBy: .newlines)
        var nodes: [VPNNode] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            // 跳过注释行（以 # 或 // 开头）
            if trimmedLine.hasPrefix("#") || trimmedLine.hasPrefix("//") {
                continue
            }

            // 使用 VPNNodeImporter 解析单个节点链接
            if let node = parseSingleNodeLink(trimmedLine) {
                nodes.append(node)
            }
        }

        guard !nodes.isEmpty else {
            throw VPNSubscriptionParseError.noValidNodes
        }

        return nodes
    }

    // MARK: - 圈X格式解析

    /// 解析圈X（Quantumult X）订阅格式
    /// 圈X订阅可能是 [server] 段配置格式，也可能是 base64 编码的节点列表
    /// - Parameter content: 原始内容
    /// - Returns: 解析出的节点列表
    /// - Throws: 解析错误
    private func parseQuantumultX(content: String) throws -> [VPNNode] {
        var decodedContent = content

        // 尝试 base64 解码
        if let decoded = decodeBase64(content) {
            decodedContent = decoded
        }

        // 检查是否包含 [server] 段（圈X配置文件格式）
        if decodedContent.contains("[server]") {
            return try parseQuantumultXServerSection(content: decodedContent)
        }

        // 否则按明文节点链接列表解析（圈X也支持标准节点链接格式）
        return try parsePlainLinks(content: decodedContent)
    }

    /// 解析圈X [server] 段配置
    /// 圈X配置文件中 [server] 段的每一行是一个节点配置
    /// 格式示例：
    ///   vmess = vmess, server.com, 443, username=uuid, ws-host=example.com, ws-path=/path, tls=true
    ///   vless = vless, server.com, 443, username=uuid, ws-host=example.com, ws-path=/path, tls=true
    ///   trojan = trojan, server.com, 443, password=xxx, tls=true
    ///   ss = ss, server.com, 443, encrypt-method=aes-256-gcm, password=xxx
    /// - Parameter content: 包含 [server] 段的配置内容
    /// - Returns: 解析出的节点列表
    /// - Throws: 解析错误
    private func parseQuantumultXServerSection(content: String) throws -> [VPNNode] {
        let lines = content.components(separatedBy: .newlines)
        var inServerSection = false
        var nodes: [VPNNode] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // 检测段标记
            if trimmedLine.hasPrefix("[") {
                inServerSection = (trimmedLine == "[server]")
                continue
            }

            // 只处理 [server] 段内的内容
            guard inServerSection else { continue }
            guard !trimmedLine.isEmpty else { continue }
            guard !trimmedLine.hasPrefix("#") else { continue }

            // 解析圈X server 行格式
            if let node = parseQuantumultXServerLine(trimmedLine) {
                nodes.append(node)
            }
        }

        guard !nodes.isEmpty else {
            throw VPNSubscriptionParseError.noValidNodes
        }

        return nodes
    }

    /// 解析单行圈X server 配置
    /// 格式：标签 = 协议, 服务器, 端口, 参数1=值1, 参数2=值2, ...
    /// - Parameter line: 单行配置
    /// - Returns: 解析出的 VPNNode，解析失败返回 nil
    private func parseQuantumultXServerLine(_ line: String) -> VPNNode? {
        // 分割标签和配置部分
        let parts = line.components(separatedBy: "=")
        guard parts.count >= 2 else { return nil }

        let remark = parts[0].trimmingCharacters(in: .whitespaces)
        let configPart = parts[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)

        // 按逗号分割配置项
        let configItems = configPart.components(separatedBy: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        guard configItems.count >= 3 else { return nil }

        let protocolString = configItems[0].lowercased()
        let server = configItems[1]
        guard let port = Int(configItems[2]) else { return nil }

        // 解析剩余的键值对参数
        var params: [String: String] = [:]
        for item in configItems.dropFirst(3) {
            let kv = item.components(separatedBy: "=")
            if kv.count >= 2 {
                let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
                let value = kv[1...].joined(separator: "=").trimmingCharacters(in: .whitespaces)
                params[key] = value
            }
        }

        // 根据协议类型构建节点
        switch protocolString {
        case "vmess":
            return buildVMessNode(remark: remark, server: server, port: port, params: params)
        case "vless":
            return buildVLESSNode(remark: remark, server: server, port: port, params: params)
        case "trojan":
            return buildTrojanNode(remark: remark, server: server, port: port, params: params)
        case "ss", "shadowsocks":
            return buildShadowsocksNode(remark: remark, server: server, port: port, params: params)
        default:
            return nil
        }
    }

    // MARK: - 明文节点链接解析

    /// 解析明文节点链接列表
    /// 每行一个标准节点链接（vmess://、vless://、trojan://、ss://）
    /// - Parameter content: 明文内容
    /// - Returns: 解析出的节点列表
    /// - Throws: 解析错误
    private func parsePlainLinks(content: String) throws -> [VPNNode] {
        let lines = content.components(separatedBy: .newlines)
        var nodes: [VPNNode] = []

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            guard !trimmedLine.hasPrefix("#") else { continue }

            if let node = parseSingleNodeLink(trimmedLine) {
                nodes.append(node)
            }
        }

        guard !nodes.isEmpty else {
            throw VPNSubscriptionParseError.noValidNodes
        }

        return nodes
    }

    // MARK: - 辅助方法

    /// Base64 解码
    /// 支持标准 Base64 和 URL Safe Base64，自动处理填充
    /// - Parameter content: 可能是 base64 编码的字符串
    /// - Returns: 解码后的字符串，如果不是有效 base64 返回 nil
    private func decodeBase64(_ content: String) -> String? {
        var base64String = content.trimmingCharacters(in: .whitespacesAndNewlines)

        // 移除可能的换行（base64 编码内容可能被分行）
        base64String = base64String.components(separatedBy: .newlines).joined()

        // URL Safe Base64 转换为标准 Base64
        base64String = base64String
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // 补齐填充
        while base64String.count % 4 != 0 {
            base64String.append("=")
        }

        // 尝试解码
        guard let data = Data(base64Encoded: base64String),
              let decoded = String(data: data, encoding: .utf8) else {
            return nil
        }

        // 解码后内容必须包含至少一个节点链接前缀才算有效
        let lowercased = decoded.lowercased()
        guard lowercased.contains("vmess://") ||
              lowercased.contains("vless://") ||
              lowercased.contains("trojan://") ||
              lowercased.contains("ss://") ||
              lowercased.contains("[server]") else {
            return nil
        }

        return decoded
    }

    /// 解析单个节点链接
    /// 复用 VPNNodeImporter 的解析能力
    /// - Parameter link: 节点链接字符串
    /// - Returns: 解析出的 VPNNode，解析失败返回 nil
    private func parseSingleNodeLink(_ link: String) -> VPNNode? {
        do {
            return try VPNNodeImporter.importNode(from: link)
        } catch {
            return nil
        }
    }

    // MARK: - 圈X节点构建方法

    /// 构建 VMess 节点（从圈X配置参数）
    private func buildVMessNode(remark: String, server: String, port: Int, params: [String: String]) -> VPNNode? {
        guard let uuid = params["username"] else { return nil }

        var node = VPNNode(
            remark: remark,
            protocolType: .vmess,
            serverAddress: server,
            serverPort: port,
            uuid: uuid
        )

        // 传输协议
        if let obfs = params["obfs"]?.lowercased() {
            switch obfs {
            case "ws", "websocket":
                node.transportType = .websocket
                node.wsHost = params["ws-host"]
                node.wsPath = params["ws-path"]
            case "grpc":
                node.transportType = .grpc
                node.grpcServiceName = params["grpc-service-name"]
            case "h2", "http2":
                node.transportType = .http2
            default:
                node.transportType = .tcp
            }
        }

        // TLS
        if let tls = params["tls"], tls == "true" || tls == "1" {
            node.enableTLS = true
            node.tlsServerName = params["peer"] ?? params["tls-host"] ?? server
        }

        return node
    }

    /// 构建 VLESS 节点（从圈X配置参数）
    private func buildVLESSNode(remark: String, server: String, port: Int, params: [String: String]) -> VPNNode? {
        guard let uuid = params["username"] else { return nil }

        var node = VPNNode(
            remark: remark,
            protocolType: .vless,
            serverAddress: server,
            serverPort: port,
            uuid: uuid
        )

        // 传输协议
        if let obfs = params["obfs"]?.lowercased() {
            switch obfs {
            case "ws", "websocket":
                node.transportType = .websocket
                node.wsHost = params["ws-host"]
                node.wsPath = params["ws-path"]
            case "grpc":
                node.transportType = .grpc
                node.grpcServiceName = params["grpc-service-name"]
            default:
                node.transportType = .tcp
            }
        }

        // TLS
        if let tls = params["tls"], tls == "true" || tls == "1" {
            node.enableTLS = true
            node.tlsServerName = params["peer"] ?? params["tls-host"] ?? server
        }

        // Flow（VLESS 流控）
        if let flow = params["flow"] {
            node.flow = flow
        }

        return node
    }

    /// 构建 Trojan 节点（从圈X配置参数）
    private func buildTrojanNode(remark: String, server: String, port: Int, params: [String: String]) -> VPNNode? {
        guard let password = params["password"] else { return nil }

        // Trojan 密码存储在 uuid 字段（当前模型共用此字段）
        var node = VPNNode(
            remark: remark,
            protocolType: .trojan,
            serverAddress: server,
            serverPort: port,
            uuid: password
        )

        // TLS（Trojan 默认开启 TLS）
        node.enableTLS = true
        node.tlsServerName = params["peer"] ?? params["tls-host"] ?? server

        // 传输协议
        if let obfs = params["obfs"]?.lowercased() {
            switch obfs {
            case "ws", "websocket":
                node.transportType = .websocket
                node.wsHost = params["ws-host"]
                node.wsPath = params["ws-path"]
            default:
                node.transportType = .tcp
            }
        }

        return node
    }

    /// 构建 Shadowsocks 节点（从圈X配置参数）
    private func buildShadowsocksNode(remark: String, server: String, port: Int, params: [String: String]) -> VPNNode? {
        guard let password = params["password"] else { return nil }

        // Shadowsocks 密码存储在 uuid 字段（当前模型共用此字段）
        let node = VPNNode(
            remark: remark,
            protocolType: .shadowsocks,
            serverAddress: server,
            serverPort: port,
            uuid: password
        )

        return node
    }
}
