//
//  VPNNodeImporter.swift
//  GitHub
//
//  用途：VPN 节点导入工具，支持从剪贴板/字符串导入节点
//  支持格式：
//    - VMess: vmess://base64(json)
//    - VLESS: vless://uuid@server:port?params#remark
//

import Foundation
import UIKit

// MARK: - 导入错误类型

/// 节点导入错误
enum VPNNodeImportError: Error, LocalizedError {
    case invalidFormat          // 格式无效
    case invalidURL             // URL 无效
    case invalidBase64          // Base64 解码失败
    case invalidJSON            // JSON 解析失败
    case missingRequiredField   // 缺少必填字段
    case unsupportedProtocol    // 不支持的协议

    /// 错误描述（中文）
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "节点链接格式无效"
        case .invalidURL: return "节点 URL 无效"
        case .invalidBase64: return "Base64 解码失败"
        case .invalidJSON: return "JSON 解析失败"
        case .missingRequiredField: return "缺少必填字段（服务器地址、端口、UUID）"
        case .unsupportedProtocol: return "不支持的协议类型"
        }
    }
}

// MARK: - 节点导入工具

/// VPN 节点导入工具
/// 提供从各种格式导入节点的静态方法
struct VPNNodeImporter {

    // MARK: - 从剪贴板导入

    /// 从剪贴板导入节点
    /// 自动识别剪贴板内容格式（VMess/VLESS）
    /// - Parameter completion: 导入完成回调，返回节点数组或错误
    static func importFromPasteboard(completion: @escaping (Result<[VPNNode], Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            // 读取剪贴板内容
            guard let pasteboardString = UIPasteboard.general.string else {
                DispatchQueue.main.async {
                    completion(.failure(VPNNodeImportError.invalidFormat))
                }
                return
            }

            let trimmedString = pasteboardString.trimmingCharacters(in: .whitespacesAndNewlines)

            // 按行分割，支持批量导入（每行一个节点链接）
            let lines = trimmedString.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            var importedNodes: [VPNNode] = []
            var importError: Error?

            for line in lines {
                do {
                    let node = try importNode(from: line)
                    importedNodes.append(node)
                } catch {
                    // 如果只有一行且失败，返回错误
                    if lines.count == 1 {
                        importError = error
                    }
                    // 多行时跳过失败的行，继续导入其他行
                }
            }

            DispatchQueue.main.async {
                if importedNodes.isEmpty {
                    completion(.failure(importError ?? VPNNodeImportError.invalidFormat))
                } else {
                    completion(.success(importedNodes))
                }
            }
        }
    }

    // MARK: - 从字符串导入单个节点

    /// 从字符串导入单个节点
    /// 自动识别协议类型（VMess/VLESS）
    /// - Parameter string: 节点链接字符串
    /// - Returns: 导入的节点
    static func importNode(from string: String) throws -> VPNNode {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if trimmed.hasPrefix("vmess://") {
            return try importVMess(from: string)
        } else if trimmed.hasPrefix("vless://") {
            return try importVLESS(from: string)
        } else {
            throw VPNNodeImportError.unsupportedProtocol
        }
    }

    // MARK: - VMess 导入

    /// 从 VMess 链接导入节点
    /// VMess 链接格式：vmess://base64(json)
    /// JSON 字段参考 V2RayN 标准格式
    /// - Parameter string: VMess 链接字符串
    /// - Returns: 导入的节点
    private static func importVMess(from string: String) throws -> VPNNode {
        // 移除前缀 "vmess://"
        let base64String = String(string.dropFirst(8))

        // Base64 解码
        guard let data = Data(base64Encoded: base64String),
              let jsonString = String(data: data, encoding: .utf8) else {
            throw VPNNodeImportError.invalidBase64
        }

        // 解析 JSON
        guard let jsonData = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw VPNNodeImportError.invalidJSON
        }

        // 提取必填字段
        guard let address = json["add"] as? String,
              let portString = json["port"] as? String,
              let port = Int(portString),
              let uuid = json["id"] as? String else {
            throw VPNNodeImportError.missingRequiredField
        }

        // 提取可选字段
        let remark = (json["ps"] as? String) ?? "VMess 节点"
        let alterIdString = json["aid"] as? String
        _ = Int(alterIdString ?? "0") // alterId，现代 VMess 已废弃

        // 加密方式
        let securityString = (json["scy"] as? String)?.lowercased() ?? "auto"
        let encryption = parseEncryption(securityString)

        // 传输协议
        let networkString = (json["net"] as? String)?.lowercased() ?? "tcp"
        let transportType = parseTransportType(networkString)

        // 创建节点
        var node = VPNNode(
            remark: remark,
            protocolType: .vmess,
            serverAddress: address,
            serverPort: port,
            uuid: uuid
        )
        node.encryption = encryption
        node.transportType = transportType

        // WebSocket 配置
        if transportType == .websocket {
            node.wsPath = json["path"] as? String
            node.wsHost = json["host"] as? String
        }

        // gRPC 配置
        if transportType == .grpc {
            node.grpcServiceName = json["path"] as? String
        }

        // TLS 配置
        let tlsString = (json["tls"] as? String)?.lowercased() ?? ""
        node.enableTLS = (tlsString == "tls")
        if node.enableTLS {
            node.tlsServerName = json["sni"] as? String
            node.allowInsecure = (json["allowInsecure"] as? Int) == 1
            if let alpnString = json["alpn"] as? String {
                node.alpn = alpnString.components(separatedBy: ",")
            }
        }

        // 流控（VLESS 专用，VMess 一般没有）
        node.flow = json["flow"] as? String

        return node
    }

    // MARK: - VLESS 导入

    /// 从 VLESS 链接导入节点
    /// VLESS 链接格式：vless://uuid@server:port?params#remark
    /// - Parameter string: VLESS 链接字符串
    /// - Returns: 导入的节点
    private static func importVLESS(from string: String) throws -> VPNNode {
        // 移除前缀 "vless://"
        let urlString = String(string.dropFirst(8))

        // 分离备注（# 后面的部分）
        var remark = "VLESS 节点"
        var mainPart = urlString
        if let range = urlString.range(of: "#") {
            remark = String(urlString[range.upperBound...]).removingPercentEncoding ?? remark
            mainPart = String(urlString[..<range.lowerBound])
        }

        // 分离查询参数（? 后面的部分）
        var queryString = ""
        if let range = mainPart.range(of: "?") {
            queryString = String(mainPart[range.upperBound...])
            mainPart = String(mainPart[..<range.lowerBound])
        }

        // 分离 UUID 和服务器地址（@ 分隔）
        let parts = mainPart.components(separatedBy: "@")
        guard parts.count == 2 else {
            throw VPNNodeImportError.invalidURL
        }

        let uuid = parts[0].removingPercentEncoding ?? parts[0]
        let serverPart = parts[1]

        // 分离服务器地址和端口（: 分隔）
        let serverParts = serverPart.components(separatedBy: ":")
        guard serverParts.count >= 2,
              let port = Int(serverParts.last ?? "") else {
            throw VPNNodeImportError.missingRequiredField
        }

        let serverAddress = serverParts.dropLast().joined(separator: ":")
            .removingPercentEncoding ?? serverParts[0]

        // 解析查询参数
        let queryParams = parseQueryString(queryString)

        // 创建节点
        var node = VPNNode(
            remark: remark,
            protocolType: .vless,
            serverAddress: serverAddress,
            serverPort: port,
            uuid: uuid
        )

        // VLESS 默认不加密
        node.encryption = .none

        // 传输协议
        let typeString = (queryParams["type"] as? String)?.lowercased() ?? "tcp"
        node.transportType = parseTransportType(typeString)

        // WebSocket 配置
        if node.transportType == .websocket {
            node.wsPath = (queryParams["path"] as? String)?.removingPercentEncoding
            node.wsHost = (queryParams["host"] as? String)?.removingPercentEncoding
        }

        // gRPC 配置
        if node.transportType == .grpc {
            node.grpcServiceName = (queryParams["serviceName"] as? String)?.removingPercentEncoding
        }

        // TLS 配置
        let securityString = (queryParams["security"] as? String)?.lowercased() ?? "none"
        node.enableTLS = (securityString == "tls" || securityString == "reality")
        if node.enableTLS {
            node.tlsServerName = (queryParams["sni"] as? String)?.removingPercentEncoding
            node.allowInsecure = (queryParams["allowInsecure"] as? String) == "1"
            if let alpnString = queryParams["alpn"] as? String {
                node.alpn = alpnString.components(separatedBy: ",")
            }
        }

        // 流控
        node.flow = (queryParams["flow"] as? String)?.removingPercentEncoding

        return node
    }

    // MARK: - 辅助方法

    /// 解析查询字符串为字典
    /// - Parameter queryString: 查询字符串（如 "type=tcp&security=tls"）
    /// - Returns: 参数字典
    private static func parseQueryString(_ queryString: String) -> [String: Any] {
        var params: [String: Any] = [:]
        let pairs = queryString.components(separatedBy: "&")
        for pair in pairs {
            let keyValue = pair.components(separatedBy: "=")
            if keyValue.count == 2 {
                let key = keyValue[0]
                let value = keyValue[1]
                params[key] = value
            }
        }
        return params
    }

    /// 解析加密方式字符串
    /// - Parameter string: 加密方式字符串
    /// - Returns: 加密方式枚举
    private static func parseEncryption(_ string: String) -> VPNEncryptionType {
        switch string.lowercased() {
        case "aes-128-gcm", "aes128gcm":
            return .aes128gcm
        case "aes-256-gcm", "aes256gcm":
            return .aes256gcm
        case "chacha20-poly1305", "chacha20", "chacha20poly1305":
            return .chacha20poly1305
        case "none", "zero":
            return .none
        default:
            return .auto
        }
    }

    /// 解析传输协议类型字符串
    /// - Parameter string: 传输协议字符串
    /// - Returns: 传输协议枚举
    private static func parseTransportType(_ string: String) -> VPNTransportType {
        switch string.lowercased() {
        case "ws", "websocket":
            return .websocket
        case "grpc", "gun":
            return .grpc
        case "kcp", "mkcp":
            return .mkcp
        case "quic":
            return .quic
        case "h2", "http2":
            return .http2
        default:
            return .tcp
        }
    }

    // MARK: - 检测剪贴板是否包含节点链接

    /// 检测剪贴板是否包含可导入的节点链接
    /// - Returns: 是否包含节点链接
    static func pasteboardContainsNodeLink() -> Bool {
        guard let pasteboardString = UIPasteboard.general.string else {
            return false
        }
        let trimmed = pasteboardString.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("vmess://") || trimmed.hasPrefix("vless://")
    }
}
