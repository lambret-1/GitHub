//
//  VLESSClient.swift
//  VPNPacketTunnel
//
//  用途：VLESS 协议客户端
//  职责：建立到 VLESS 代理服务器的连接，进行协议握手，转发 TCP 数据
//  支持：VLESS over TCP、VLESS over WebSocket、VLESS over TLS
//

import Foundation
import Network

// MARK: - VLESS 协议版本

/// VLESS 协议版本
private let vlessVersion: UInt8 = 0

// MARK: - VLESS 指令类型

/// VLESS 指令类型
enum VLESSCommand: UInt8 {
    case connect = 1   // TCP 连接
    case bind = 2      // 绑定
    case udp = 3       // UDP 关联
}

// MARK: - VLESS 地址类型

/// VLESS 地址类型
enum VLESSAddressType: UInt8 {
    case ipv4 = 1      // IPv4 地址
    case domain = 2    // 域名
    case ipv6 = 3      // IPv6 地址
}

// MARK: - VLESS 客户端配置

/// VLESS 客户端配置
struct VLESSClientConfig {
    /// 服务器地址
    let serverAddress: String
    /// 服务器端口
    let serverPort: UInt16
    /// 用户 UUID
    let uuid: String
    /// 传输方式（tcp / websocket）
    let transportType: String
    /// 是否启用 TLS
    let enableTLS: Bool
    /// TLS 服务器名（SNI）
    let tlsServerName: String?
    /// WebSocket 主机
    let wsHost: String?
    /// WebSocket 路径
    let wsPath: String?
    /// 流控（xtls-rprx-vision 等）
    let flow: String?
}

// MARK: - VLESS 客户端

/// VLESS 协议客户端
/// 负责建立到代理服务器的连接并转发 TCP 数据
class VLESSClient {

    // MARK: - 属性

    /// 配置
    let config: VLESSClientConfig

    /// 网络连接
    private var connection: NWConnection?

    /// 是否已完成 VLESS 握手
    private var handshakeCompleted: Bool = false

    /// 待发送的数据缓冲区（握手完成前缓存）
    private var pendingData: Data = Data()

    /// 接收到的数据回调
    var onData: ((Data) -> Void)?

    /// 连接状态变化回调
    var onStateChange: ((NWConnection.State) -> Void)?

    /// 连接失败回调
    var onError: ((Error) -> Void)?

    // MARK: - 初始化

    init(config: VLESSClientConfig) {
        self.config = config
    }

    // MARK: - 连接

    /// 建立到代理服务器的连接
    /// - Parameters:
    ///   - targetHost: 目标主机（要访问的网站域名或 IP）
    ///   - targetPort: 目标端口
    func connect(targetHost: String, targetPort: UInt16) {
        // 创建连接参数
        let parameters: NWParameters
        if config.enableTLS {
            // TLS 配置
            let tlsOptions = NWProtocolTLS.Options()
            if let serverName = config.tlsServerName {
                sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, serverName)
            }
            parameters = NWParameters(tls: tlsOptions, tcp: .init())
        } else {
            parameters = NWParameters.tcp
        }

        // 创建连接
        let host = NWEndpoint.Host(config.serverAddress)
        let port = NWEndpoint.Port(rawValue: config.serverPort)!
        connection = NWConnection(host: host, port: port, using: parameters)

        // 设置状态回调
        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            self.onStateChange?(state)

            switch state {
            case .ready:
                // 连接已建立，发送 VLESS 握手
                self.sendVLESSHandshake(targetHost: targetHost, targetPort: targetPort)
            case .failed(let error):
                self.onError?(error)
            default:
                break
            }
        }

        // 开始接收数据
        startReceiving()

        // 启动连接
        connection?.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - VLESS 握手

    /// 发送 VLESS 握手包
    private func sendVLESSHandshake(targetHost: String, targetPort: UInt16) {
        var handshake = Data()

        // 1. 协议版本
        handshake.append(vlessVersion)

        // 2. UUID（16 字节）
        if let uuidData = uuidToBytes(config.uuid) {
            handshake.append(uuidData)
        } else {
            // UUID 解析失败，使用全零
            handshake.append(contentsOf: [UInt8](repeating: 0, count: 16))
        }

        // 3. 附加信息长度（0 表示无附加信息）
        handshake.append(0)

        // 4. 指令类型（CONNECT）
        handshake.append(VLESSCommand.connect.rawValue)

        // 5. 端口（2 字节，大端）
        handshake.append(contentsOf: withUnsafeBytes(of: targetPort.bigEndian) { Array($0) })

        // 6. 地址类型 + 地址
        if let ipv4 = IPv4Address(targetHost) {
            // IPv4 地址
            handshake.append(VLESSAddressType.ipv4.rawValue)
            handshake.append(ipv4.rawValue)
        } else if let ipv6 = IPv6Address(targetHost) {
            // IPv6 地址
            handshake.append(VLESSAddressType.ipv6.rawValue)
            handshake.append(ipv6.rawValue)
        } else {
            // 域名
            handshake.append(VLESSAddressType.domain.rawValue)
            let hostData = targetHost.data(using: .utf8) ?? Data()
            handshake.append(UInt8(hostData.count))
            handshake.append(hostData)
        }

        // 如果是 WebSocket 传输，需要先进行 WebSocket 握手
        if config.transportType == "websocket" {
            sendWebSocketHandshake(initialData: handshake)
        } else {
            // 直接发送 VLESS 握手
            sendData(handshake)
            handshakeCompleted = true
            // 发送缓存的数据
            flushPendingData()
        }
    }

    // MARK: - WebSocket 握手

    /// 发送 WebSocket 握手请求
    private func sendWebSocketHandshake(initialData: Data) {
        // 生成 WebSocket Key
        let wsKey = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            .data(using: .utf8)?.base64EncodedString() ?? "dGhlIHNhbXBsZSBub25jZQ=="

        let host = config.wsHost ?? config.serverAddress
        let path = config.wsPath ?? "/"

        // 构造 HTTP 升级请求
        var request = "GET \(path) HTTP/1.1\r\n"
        request += "Host: \(host)\r\n"
        request += "Upgrade: websocket\r\n"
        request += "Connection: Upgrade\r\n"
        request += "Sec-WebSocket-Key: \(wsKey)\r\n"
        request += "Sec-WebSocket-Version: 13\r\n"
        request += "\r\n"

        guard let requestData = request.data(using: .utf8) else { return }

        // 缓存 VLESS 握手数据，等 WebSocket 握手完成后发送
        pendingData.append(initialData)

        // 发送 WebSocket 握手请求
        sendData(requestData)

        // 等待 WebSocket 握手响应（在 startReceiving 中处理）
        // 简化实现：假设服务器立即响应，直接标记握手完成
        // 实际实现中需要解析 HTTP 101 响应
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.handshakeCompleted = true
            self?.flushPendingData()
        }
    }

    // MARK: - 发送数据

    /// 发送数据到代理服务器
    /// - Parameter data: 要发送的数据
    func send(_ data: Data) {
        if handshakeCompleted {
            if config.transportType == "websocket" {
                sendWebSocketFrame(data: data)
            } else {
                sendData(data)
            }
        } else {
            // 握手未完成，缓存数据
            pendingData.append(data)
        }
    }

    /// 发送 WebSocket 数据帧
    private func sendWebSocketFrame(data: Data) {
        var frame = Data()
        // FIN=1, 操作码=0x2（二进制帧）
        frame.append(0x82)

        // 掩码位 + 长度
        if data.count < 126 {
            frame.append(0x80 | UInt8(data.count))
        } else if data.count < 65536 {
            frame.append(0x80 | 126)
            frame.append(contentsOf: withUnsafeBytes(of: UInt16(data.count).bigEndian) { Array($0) })
        } else {
            frame.append(0x80 | 127)
            frame.append(contentsOf: withUnsafeBytes(of: UInt64(data.count).bigEndian) { Array($0) })
        }

        // 掩码密钥（4 字节）
        let maskKey: [UInt8] = [0x12, 0x34, 0x56, 0x78]
        frame.append(contentsOf: maskKey)

        // 掩码后的数据
        var maskedData = Data()
        for (index, byte) in data.enumerated() {
            maskedData.append(byte ^ maskKey[index % 4])
        }
        frame.append(maskedData)

        sendData(frame)
    }

    /// 刷新待发送数据
    private func flushPendingData() {
        guard !pendingData.isEmpty else { return }
        let data = pendingData
        pendingData = Data()
        send(data)
    }

    /// 底层发送数据
    private func sendData(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                self.onError?(error)
            }
        })
    }

    // MARK: - 接收数据

    /// 开始接收数据
    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.onError?(error)
                return
            }

            if let content = content, !content.isEmpty {
                self.handleReceivedData(content)
            }

            if isComplete {
                return
            }

            // 继续接收
            self.startReceiving()
        }
    }

    /// 处理接收到的数据
    private func handleReceivedData(_ data: Data) {
        if config.transportType == "websocket" {
            // WebSocket 模式：解析 WebSocket 帧
            handleWebSocketFrame(data)
        } else {
            // 裸 TCP 模式：直接传递
            onData?(data)
        }
    }

    /// 处理 WebSocket 数据帧（简化实现）
    private func handleWebSocketFrame(_ data: Data) {
        // 简化实现：假设数据是完整的 WebSocket 帧，直接去除帧头
        // 实际实现中需要处理分片、多帧等情况
        guard data.count >= 2 else { return }

        let opcode = data[0] & 0x0F
        let masked = (data[1] & 0x80) != 0
        var payloadLength = Int(data[1] & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= 4 else { return }
            payloadLength = Int(UInt16(bigEndian: data.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self) }))
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else { return }
            payloadLength = Int(UInt64(bigEndian: data.subdata(in: 2..<10).withUnsafeBytes { $0.load(as: UInt64.self) }))
            offset = 10
        }

        if masked {
            guard data.count >= offset + 4 else { return }
            let maskKey = Array(data[offset..<offset+4])
            offset += 4

            guard data.count >= offset + payloadLength else { return }
            var payload = Data()
            for i in 0..<payloadLength {
                payload.append(data[offset + i] ^ maskKey[i % 4])
            }
            onData?(payload)
        } else {
            guard data.count >= offset + payloadLength else { return }
            let payload = data.subdata(in: offset..<offset+payloadLength)
            onData?(payload)
        }
    }

    // MARK: - 断开连接

    /// 断开连接
    func disconnect() {
        connection?.cancel()
        connection = nil
        handshakeCompleted = false
        pendingData = Data()
    }

    // MARK: - 工具方法

    /// 将 UUID 字符串转换为 16 字节数据
    private func uuidToBytes(_ uuidString: String) -> Data? {
        let cleaned = uuidString.replacingOccurrences(of: "-", with: "")
        guard cleaned.count == 32 else { return nil }

        var data = Data()
        var index = cleaned.startIndex
        for _ in 0..<16 {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}
