//
//  VLESSClient.swift
//  VPNPacketTunnel
//
//  用途：VLESS 协议客户端（生产级实现）
//  职责：建立到 VLESS 代理服务器的连接，处理 WebSocket/TLS 握手，转发 TCP 数据
//  支持：VLESS over TCP、VLESS over WebSocket、VLESS over TLS
//

import Foundation
import Network

// MARK: - VLESS 协议常量

/// VLESS 协议版本
private let vlessVersion: UInt8 = 0

/// VLESS 指令类型
private enum VLESSCommand: UInt8 {
    case connect = 1
}

/// VLESS 地址类型
private enum VLESSAddressType: UInt8 {
    case ipv4 = 1
    case domain = 2
    case ipv6 = 3
}

// MARK: - VLESS 客户端配置

/// VLESS 客户端配置
struct VLESSClientConfig {
    let serverAddress: String
    let serverPort: UInt16
    let uuid: String
    let transportType: String
    let enableTLS: Bool
    let tlsServerName: String?
    let wsHost: String?
    let wsPath: String?
    let flow: String?
}

// MARK: - 连接状态

/// VLESS 客户端连接状态
private enum ConnectionState {
    case idle
    case connecting
    case websocketHandshake
    case vlessHandshake
    case connected
    case failed
    case closed
}

// MARK: - VLESS 客户端

/// VLESS 协议客户端（生产级实现）
class VLESSClient {

    // MARK: - 属性

    let config: VLESSClientConfig
    private var connection: NWConnection?
    private var state: ConnectionState = .idle

    private var pendingData: Data = Data()
    private var receiveBuffer: Data = Data()
    private var vlessResponseHeaderParsed: Bool = false

    // MARK: - 回调

    var onData: ((Data) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - 初始化

    init(config: VLESSClientConfig) {
        self.config = config
    }

    // MARK: - 连接

    func connect(targetHost: String, targetPort: UInt16) {
        guard state == .idle || state == .closed || state == .failed else { return }

        state = .connecting

        let parameters: NWParameters
        if config.enableTLS {
            let tlsOptions = NWProtocolTLS.Options()
            if let serverName = config.tlsServerName ?? config.wsHost {
                sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, serverName)
            }
            parameters = NWParameters(tls: tlsOptions, tcp: .init())
        } else {
            parameters = NWParameters.tcp
        }

        let host = NWEndpoint.Host(config.serverAddress)
        let port = NWEndpoint.Port(rawValue: config.serverPort)!
        connection = NWConnection(host: host, port: port, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            switch state {
            case .ready:
                if self.config.transportType == "websocket" {
                    self.startWebSocketHandshake(targetHost: targetHost, targetPort: targetPort)
                } else {
                    self.sendVLESSHandshake(targetHost: targetHost, targetPort: targetPort)
                }
            case .failed(let error):
                self.state = .failed
                self.onError?(error)
            case .cancelled:
                self.state = .closed
            default:
                break
            }
        }

        startReceiving()
        connection?.start(queue: .global(qos: .userInitiated))
    }

    // MARK: - WebSocket 握手

    private func startWebSocketHandshake(targetHost: String, targetPort: UInt16) {
        state = .websocketHandshake

        var wsKeyBytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 { wsKeyBytes[i] = UInt8.random(in: 0...255) }
        let wsKey = Data(wsKeyBytes).base64EncodedString()

        let host = config.wsHost ?? config.serverAddress
        let path = config.wsPath ?? "/"

        var request = "GET \(path) HTTP/1.1\r\n"
        request += "Host: \(host)\r\n"
        request += "Upgrade: websocket\r\n"
        request += "Connection: Upgrade\r\n"
        request += "Sec-WebSocket-Key: \(wsKey)\r\n"
        request += "Sec-WebSocket-Version: 13\r\n"
        request += "User-Agent: Mozilla/5.0\r\n"
        request += "\r\n"

        guard let requestData = request.data(using: .utf8) else {
            failWithError(NSError(domain: "VLESSClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebSocket请求编码失败"]))
            return
        }

        let vlessHandshake = buildVLESSHandshake(targetHost: targetHost, targetPort: targetPort)
        pendingData.append(vlessHandshake)

        sendRaw(requestData)
    }

    private func handleWebSocketHandshakeResponse(_ data: Data) -> Bool {
        guard let headerEnd = data.range(of: Data("\r\n\r\n".utf8)) else {
            return false
        }

        let headerData = data.subdata(in: 0..<headerEnd.lowerBound)
        guard let headerString = String(data: headerData, encoding: .utf8) else {
            failWithError(NSError(domain: "VLESSClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "WebSocket响应解析失败"]))
            return true
        }

        if headerString.contains("101") {
            state = .connected

            let remainingData = data.subdata(in: headerEnd.upperBound..<data.count)
            receiveBuffer = remainingData

            flushPendingData()
            processReceiveBuffer()

            return true
        } else {
            failWithError(NSError(domain: "VLESSClient", code: -3, userInfo: [NSLocalizedDescriptionKey: "WebSocket握手失败"]))
            return true
        }
    }

    // MARK: - VLESS 握手

    private func sendVLESSHandshake(targetHost: String, targetPort: UInt16) {
        state = .vlessHandshake

        let handshake = buildVLESSHandshake(targetHost: targetHost, targetPort: targetPort)
        sendRaw(handshake)

        state = .connected
        flushPendingData()
    }

    private func buildVLESSHandshake(targetHost: String, targetPort: UInt16) -> Data {
        var handshake = Data()

        handshake.append(vlessVersion)

        if let uuidData = uuidToBytes(config.uuid) {
            handshake.append(uuidData)
        } else {
            handshake.append(contentsOf: [UInt8](repeating: 0, count: 16))
        }

        handshake.append(0) // 附加信息长度

        handshake.append(VLESSCommand.connect.rawValue)

        handshake.append(contentsOf: withUnsafeBytes(of: targetPort.bigEndian) { Array($0) })

        if let ipv4 = IPv4Address(targetHost) {
            handshake.append(VLESSAddressType.ipv4.rawValue)
            handshake.append(ipv4.rawValue)
        } else if let ipv6 = IPv6Address(targetHost) {
            handshake.append(VLESSAddressType.ipv6.rawValue)
            handshake.append(ipv6.rawValue)
        } else {
            handshake.append(VLESSAddressType.domain.rawValue)
            let hostData = targetHost.data(using: .utf8) ?? Data()
            handshake.append(UInt8(min(hostData.count, 255)))
            handshake.append(hostData)
        }

        return handshake
    }

    // MARK: - 发送数据

    func send(_ data: Data) {
        if state == .connected {
            if config.transportType == "websocket" {
                sendWebSocketFrame(data: data)
            } else {
                sendRaw(data)
            }
        } else {
            pendingData.append(data)
        }
    }

    private func flushPendingData() {
        guard !pendingData.isEmpty else { return }
        let data = pendingData
        pendingData = Data()
        send(data)
    }

    private func sendWebSocketFrame(data: Data) {
        var frame = Data()
        frame.append(0x82) // FIN=1, 二进制帧

        if data.count < 126 {
            frame.append(0x80 | UInt8(data.count))
        } else if data.count < 65536 {
            frame.append(0x80 | 126)
            frame.append(contentsOf: withUnsafeBytes(of: UInt16(data.count).bigEndian) { Array($0) })
        } else {
            frame.append(0x80 | 127)
            frame.append(contentsOf: withUnsafeBytes(of: UInt64(data.count).bigEndian) { Array($0) })
        }

        let maskKey: [UInt8] = (0..<4).map { _ in UInt8.random(in: 0...255) }
        frame.append(contentsOf: maskKey)

        var maskedData = Data()
        maskedData.reserveCapacity(data.count)
        for (index, byte) in data.enumerated() {
            maskedData.append(byte ^ maskKey[index % 4])
        }
        frame.append(maskedData)

        sendRaw(frame)
    }

    private func sendRaw(_ data: Data) {
        connection?.send(content: data, completion: .contentProcessed { [weak self] error in
            if let error = error {
                self?.failWithError(error)
            }
        })
    }

    // MARK: - 接收数据

    private func startReceiving() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                self.failWithError(error)
                return
            }

            if let content = content, !content.isEmpty {
                self.receiveBuffer.append(content)
                self.processReceiveBuffer()
            }

            if isComplete {
                self.state = .closed
                return
            }

            self.startReceiving()
        }
    }

    private func processReceiveBuffer() {
        guard !receiveBuffer.isEmpty else { return }

        if state == .websocketHandshake {
            if handleWebSocketHandshakeResponse(receiveBuffer) {
                return
            }
            return
        }

        if config.transportType == "websocket" {
            processWebSocketFrames()
        } else {
            processVLESSData()
        }
    }

    private func processWebSocketFrames() {
        while receiveBuffer.count >= 2 {
            let firstByte = receiveBuffer[0]
            let secondByte = receiveBuffer[1]

            let opcode = firstByte & 0x0F
            let masked = (secondByte & 0x80) != 0
            var payloadLength = Int(secondByte & 0x7F)
            var offset = 2

            if payloadLength == 126 {
                guard receiveBuffer.count >= 4 else { return }
                payloadLength = Int(UInt16(bigEndian: receiveBuffer.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self) }))
                offset = 4
            } else if payloadLength == 127 {
                guard receiveBuffer.count >= 10 else { return }
                payloadLength = Int(UInt64(bigEndian: receiveBuffer.subdata(in: 2..<10).withUnsafeBytes { $0.load(as: UInt64.self) }))
                offset = 10
            }

            if masked {
                guard receiveBuffer.count >= offset + 4 else { return }
                offset += 4
            }

            guard receiveBuffer.count >= offset + payloadLength else { return }

            var payload = receiveBuffer.subdata(in: offset..<offset+payloadLength)

            if opcode == 0x8 {
                state = .closed
                return
            }

            receiveBuffer.removeFirst(offset + payloadLength)

            if !vlessResponseHeaderParsed {
                if let stripped = stripVLESSResponseHeader(payload) {
                    payload = stripped
                    vlessResponseHeaderParsed = true
                } else {
                    receiveBuffer.insert(contentsOf: payload, at: 0)
                    return
                }
            }

            if !payload.isEmpty {
                onData?(payload)
            }
        }
    }

    private func processVLESSData() {
        if !vlessResponseHeaderParsed {
            guard receiveBuffer.count >= 2 else { return }
            if let stripped = stripVLESSResponseHeader(receiveBuffer) {
                receiveBuffer = stripped
                vlessResponseHeaderParsed = true
            } else {
                return
            }
        }

        if !receiveBuffer.isEmpty {
            let data = receiveBuffer
            receiveBuffer = Data()
            onData?(data)
        }
    }

    private func stripVLESSResponseHeader(_ data: Data) -> Data? {
        guard data.count >= 2 else { return nil }

        let addonLength = Int(data[1])
        guard data.count >= 2 + addonLength else { return nil }

        return data.subdata(in: (2 + addonLength)..<data.count)
    }

    // MARK: - 错误处理

    private func failWithError(_ error: Error) {
        guard state != .failed && state != .closed else { return }
        state = .failed
        onError?(error)
        connection?.cancel()
    }

    // MARK: - 断开连接

    func disconnect() {
        state = .closed
        connection?.cancel()
        connection = nil
        pendingData = Data()
        receiveBuffer = Data()
        vlessResponseHeaderParsed = false
    }

    // MARK: - 工具方法

    private func uuidToBytes(_ uuidString: String) -> Data? {
        let cleaned = uuidString.replacingOccurrences(of: "-", with: "")
        guard cleaned.count == 32 else { return nil }

        var data = Data()
        data.reserveCapacity(16)
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
