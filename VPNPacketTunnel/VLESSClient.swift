import Foundation
import Network

// VLESS 节点配置
struct VLESSConfig: Codable {
    var uuid: String
    var host: String
    var port: Int
    var wsPath: String
    var wsHost: String?
    var tls: Bool
    var name: String
    
    enum CodingKeys: String, CodingKey {
        case uuid, host, port, wsPath, wsHost, tls, name
    }
}

// VLESS-WS 客户端
class VLESSClient {
    private var connection: NWConnection?
    private var config: VLESSConfig
    private var onData: ((Data) -> Void)?
    private var onError: ((Error) -> Void)?
    private var isConnected = false
    
    init(config: VLESSConfig) {
        self.config = config
    }
    
    // 连接到VLESS服务器并建立到目标的隧道
    func connect(targetHost: String, targetPort: UInt16, 
                 onData: @escaping (Data) -> Void,
                 onError: @escaping (Error) -> Void,
                 onConnected: @escaping () -> Void) {
        self.onData = onData
        self.onError = onError
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(config.host), port: NWEndpoint.Port(integerLiteral: UInt16(config.port)))
        
        let params: NWParameters
        if config.tls {
            let tlsOptions = NWProtocolTLS.Options()
            if let wsHost = config.wsHost {
                sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, wsHost)
            }
            params = NWParameters(tls: tlsOptions, tcp: NWProtocolTCP.Options())
        } else {
            params = NWParameters.tcp
        }
        
        connection = NWConnection(to: endpoint, using: params)
        
        connection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isConnected = true
                self?.sendVLESSHandshake(targetHost: targetHost, targetPort: targetPort) {
                    onConnected()
                    self?.startReceiving()
                }
            case .failed(let error):
                onError(error)
            default:
                break
            }
        }
        
        connection?.start(queue: .global())
    }
    
    // 发送VLESS握手 + WebSocket升级
    private func sendVLESSHandshake(targetHost: String, targetPort: UInt16, completion: @escaping () -> Void) {
        guard let connection = connection else { return }
        
        // 1. 构建WebSocket升级请求
        let wsKey = Data((0..<16).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
        let hostHeader = config.wsHost ?? config.host
        var wsRequest = "GET \(config.wsPath) HTTP/1.1\r\n"
        wsRequest += "Host: \(hostHeader)\r\n"
        wsRequest += "Upgrade: websocket\r\n"
        wsRequest += "Connection: Upgrade\r\n"
        wsRequest += "Sec-WebSocket-Key: \(wsKey)\r\n"
        wsRequest += "Sec-WebSocket-Version: 13\r\n"
        wsRequest += "\r\n"
        
        // 2. 构建VLESS握手包
        var handshake = Data()
        handshake.append(0x00) // 版本
        
        // UUID转16字节
        if let uuidData = uuidToBytes(config.uuid) {
            handshake.append(uuidData)
        }
        
        handshake.append(0x00) // 附加信息长度=0
        
        handshake.append(0x01) // 指令: TCP
        
        // 端口（大端）
        handshake.append(UInt8(targetPort >> 8))
        handshake.append(UInt8(targetPort & 0xFF))
        
        // 地址类型 + 地址
        if let hostData = targetHost.data(using: .utf8) {
            handshake.append(0x02) // 域名类型
            handshake.append(UInt8(hostData.count))
            handshake.append(hostData)
        }
        
        // 3. 先发送WebSocket升级请求
        connection.send(content: wsRequest.data(using: .utf8), completion: .contentProcessed { _ in
            // 等待WebSocket响应（简化处理，直接发送VLESS握手）
            // 实际应该先读取101响应，这里简化
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                // 4. 发送WebSocket帧（VLESS握手作为payload）
                let wsFrame = self.buildWebSocketFrame(payload: handshake)
                connection.send(content: wsFrame, completion: .contentProcessed { _ in
                    completion()
                })
            }
        })
    }
    
    // 构建WebSocket客户端帧
    private func buildWebSocketFrame(payload: Data, isBinary: Bool = true) -> Data {
        var frame = Data()
        frame.append(0x80 | (isBinary ? 0x02 : 0x01)) // FIN + opcode
        
        let maskKey = (0..<4).map { _ in UInt8.random(in: 0...255) }
        let payloadLen = payload.count
        
        if payloadLen < 126 {
            frame.append(UInt8(0x80 | payloadLen)) // MASK + 长度
        } else if payloadLen < 65536 {
            frame.append(0x80 | 126)
            frame.append(UInt8(payloadLen >> 8))
            frame.append(UInt8(payloadLen & 0xFF))
        } else {
            frame.append(0x80 | 127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payloadLen >> (i * 8)) & 0xFF))
            }
        }
        
        frame.append(contentsOf: maskKey)
        
        // 掩码处理
        var maskedPayload = Data()
        for (i, byte) in payload.enumerated() {
            maskedPayload.append(byte ^ maskKey[i % 4])
        }
        frame.append(maskedPayload)
        
        return frame
    }
    
    // 发送数据（包装成WebSocket帧）
    func send(_ data: Data) {
        guard isConnected, let connection = connection else { return }
        let frame = buildWebSocketFrame(payload: data)
        connection.send(content: frame, completion: .idempotent)
    }
    
    // 接收数据（解析WebSocket帧）
    private func startReceiving() {
        guard let connection = connection else { return }
        
        connection.receive(minimumIncompleteLength: 2, maximumLength: 65535) { [weak self] data, _, isComplete, error in
            if let error = error {
                self?.onError?(error)
                return
            }
            
            if let data = data, !data.isEmpty {
                // 简化：直接把数据传给上层（实际应该解析WebSocket帧）
                self?.onData?(data)
            }
            
            if !isComplete {
                self?.startReceiving()
            }
        }
    }
    
    func disconnect() {
        connection?.cancel()
        isConnected = false
    }
    
    // UUID字符串转16字节
    private func uuidToBytes(_ uuidString: String) -> Data? {
        let clean = uuidString.replacingOccurrences(of: "-", with: "")
        guard clean.count == 32 else { return nil }
        
        var data = Data()
        var index = clean.startIndex
        for _ in 0..<16 {
            let next = clean.index(index, offsetBy: 2)
            if let byte = UInt8(clean[index..<next], radix: 16) {
                data.append(byte)
            }
            index = next
        }
        return data
    }
}

// VLESS节点管理器
class VLESSNodeManager {
    static let shared = VLESSNodeManager()
    private let nodesKey = "vlessNodes"
    private let currentNodeKey = "currentVLESSNode"
    
    var nodes: [VLESSConfig] {
        get {
            guard let data = UserDefaults.standard.data(forKey: nodesKey),
                  let nodes = try? JSONDecoder().decode([VLESSConfig].self, from: data) else {
                return []
            }
            return nodes
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: nodesKey)
            }
        }
    }
    
    var currentNode: VLESSConfig? {
        get {
            guard let data = UserDefaults.standard.data(forKey: currentNodeKey),
                  let node = try? JSONDecoder().decode(VLESSConfig.self, from: data) else {
                return nil
            }
            return node
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: currentNodeKey)
            }
        }
    }
    
    func addNode(_ node: VLESSConfig) {
        var list = nodes
        list.append(node)
        nodes = list
    }
    
    func removeNode(at index: Int) {
        var list = nodes
        list.remove(at: index)
        nodes = list
    }
    
    func parseVLESSURL(_ url: String) -> VLESSConfig? {
        // vless://uuid@host:port?path=xxx&security=tls&type=ws&host=wsHost#name
        guard url.hasPrefix("vless://") else { return nil }
        
        let content = String(url.dropFirst(8))
        let parts = content.components(separatedBy: "#")
        let name = parts.count > 1 ? (parts[1].removingPercentEncoding ?? parts[1]) : "未命名节点"
        
        let mainPart = parts[0]
        let atParts = mainPart.components(separatedBy: "@")
        guard atParts.count == 2 else { return nil }
        
        let uuid = atParts[0]
        let hostPortQuery = atParts[1]
        
        let queryParts = hostPortQuery.components(separatedBy: "?")
        let hostPort = queryParts[0]
        let query = queryParts.count > 1 ? queryParts[1] : ""
        
        let hpParts = hostPort.components(separatedBy: ":")
        guard hpParts.count == 2, let port = Int(hpParts[1]) else { return nil }
        let host = hpParts[0]
        
        var wsPath = "/"
        var wsHost: String? = nil
        var tls = false
        
        for param in query.components(separatedBy: "&") {
            let kv = param.components(separatedBy: "=")
            if kv.count == 2 {
                switch kv[0] {
                case "path":
                    wsPath = kv[1].removingPercentEncoding ?? "/"
                case "host":
                    wsHost = kv[1].removingPercentEncoding
                case "security":
                    tls = kv[1] == "tls"
                default:
                    break
                }
            }
        }
        
        return VLESSConfig(uuid: uuid, host: host, port: port, wsPath: wsPath, wsHost: wsHost, tls: tls, name: name)
    }
}
