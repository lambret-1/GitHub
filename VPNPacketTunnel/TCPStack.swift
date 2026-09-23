//
//  TCPStack.swift
//  VPNPacketTunnel
//
//  用途：简化版用户态 TCP/IP 协议栈
//  职责：解析 IP 数据包、管理 TCP 连接、将 TCP 数据流转发给代理客户端
//  注意：这是简化实现，仅支持 IPv4 TCP 流量，不支持 UDP/ICMP
//

import Foundation
import Network

// MARK: - IP 协议号枚举

/// IP 协议号
enum IPProtocol: UInt8 {
    case icmp = 1
    case tcp = 6
    case udp = 17
}

// MARK: - IPv4 数据包头

/// IPv4 数据包头结构（20 字节，无选项）
struct IPv4Header {
    var versionAndIHL: UInt8      // 版本(高4位) + IHL(低4位)
    var typeOfService: UInt8      // 服务类型
    var totalLength: UInt16       // 总长度
    var identification: UInt16    // 标识
    var flagsAndFragmentOffset: UInt16 // 标志(高3位) + 片偏移(低13位)
    var timeToLive: UInt8         // 生存时间
    var protocol: UInt8           // 协议号
    var headerChecksum: UInt16    // 头校验和
    var sourceAddress: UInt32     // 源 IP 地址（大端）
    var destinationAddress: UInt32 // 目标 IP 地址（大端）

    /// 从数据解析 IPv4 头
    static func parse(from data: Data) -> IPv4Header? {
        guard data.count >= 20 else { return nil }
        return IPv4Header(
            versionAndIHL: data[0],
            typeOfService: data[1],
            totalLength: UInt16(bigEndian: data.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self) }),
            identification: UInt16(bigEndian: data.subdata(in: 4..<6).withUnsafeBytes { $0.load(as: UInt16.self) }),
            flagsAndFragmentOffset: UInt16(bigEndian: data.subdata(in: 6..<8).withUnsafeBytes { $0.load(as: UInt16.self) }),
            timeToLive: data[8],
            protocol: data[9],
            headerChecksum: UInt16(bigEndian: data.subdata(in: 10..<12).withUnsafeBytes { $0.load(as: UInt16.self) }),
            sourceAddress: UInt32(bigEndian: data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self) }),
            destinationAddress: UInt32(bigEndian: data.subdata(in: 16..<20).withUnsafeBytes { $0.load(as: UInt32.self) })
        )
    }

    /// 头长度（IHL * 4）
    var headerLength: Int {
        Int(versionAndIHL & 0x0F) * 4
    }

    /// 源 IP 地址字符串
    var sourceAddressString: String {
        let addr = sourceAddress.bigEndian
        return "\((addr >> 24) & 0xFF).\((addr >> 16) & 0xFF).\((addr >> 8) & 0xFF).\(addr & 0xFF)"
    }

    /// 目标 IP 地址字符串
    var destinationAddressString: String {
        let addr = destinationAddress.bigEndian
        return "\((addr >> 24) & 0xFF).\((addr >> 16) & 0xFF).\((addr >> 8) & 0xFF).\(addr & 0xFF)"
    }
}

// MARK: - TCP 标志位

/// TCP 标志位
struct TCPFlags: OptionSet {
    let rawValue: UInt8
    static let fin = TCPFlags(rawValue: 0x01)
    static let syn = TCPFlags(rawValue: 0x02)
    static let rst = TCPFlags(rawValue: 0x04)
    static let psh = TCPFlags(rawValue: 0x08)
    static let ack = TCPFlags(rawValue: 0x10)
    static let urg = TCPFlags(rawValue: 0x20)
}

// MARK: - TCP 段头

/// TCP 段头结构（20 字节，无选项）
struct TCPHeader {
    var sourcePort: UInt16         // 源端口（大端）
    var destinationPort: UInt16    // 目标端口（大端）
    var sequenceNumber: UInt32     // 序列号
    var acknowledgmentNumber: UInt32 // 确认号
    var dataOffsetAndReserved: UInt8 // 数据偏移(高4位) + 保留(低4位)
    var flags: UInt8               // 标志位
    var windowSize: UInt16         // 窗口大小
    var checksum: UInt16           // 校验和
    var urgentPointer: UInt16      // 紧急指针

    /// 从数据解析 TCP 头
    static func parse(from data: Data) -> TCPHeader? {
        guard data.count >= 20 else { return nil }
        return TCPHeader(
            sourcePort: UInt16(bigEndian: data.subdata(in: 0..<2).withUnsafeBytes { $0.load(as: UInt16.self) }),
            destinationPort: UInt16(bigEndian: data.subdata(in: 2..<4).withUnsafeBytes { $0.load(as: UInt16.self) }),
            sequenceNumber: UInt32(bigEndian: data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self) }),
            acknowledgmentNumber: UInt32(bigEndian: data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self) }),
            dataOffsetAndReserved: data[12],
            flags: data[13],
            windowSize: UInt16(bigEndian: data.subdata(in: 14..<16).withUnsafeBytes { $0.load(as: UInt16.self) }),
            checksum: UInt16(bigEndian: data.subdata(in: 16..<18).withUnsafeBytes { $0.load(as: UInt16.self) }),
            urgentPointer: UInt16(bigEndian: data.subdata(in: 18..<20).withUnsafeBytes { $0.load(as: UInt16.self) })
        )
    }

    /// TCP 头长度（数据偏移 * 4）
    var headerLength: Int {
        Int(dataOffsetAndReserved >> 4) * 4
    }

    /// TCP 标志位集合
    var flagSet: TCPFlags {
        TCPFlags(rawValue: flags)
    }
}

// MARK: - TCP 连接状态

/// TCP 连接状态
enum TCPConnectionState {
    case synReceived      // 收到 SYN，等待发送 SYN-ACK
    case established      // 连接已建立
    case finWait          // 收到 FIN，等待关闭
    case closed           // 连接已关闭
}

// MARK: - TCP 连接标识

/// TCP 连接唯一标识（四元组）
struct TCPConnectionKey: Hashable {
    let sourceAddress: UInt32
    let sourcePort: UInt16
    let destinationAddress: UInt32
    let destinationPort: UInt16
}

// MARK: - TCP 连接

/// 单个 TCP 连接
class TCPConnection {
    /// 连接标识
    let key: TCPConnectionKey

    /// 连接状态
    var state: TCPConnectionState = .synReceived

    /// 我方序列号（发送给客户端的下一个字节的序列号）
    var mySequenceNumber: UInt32 = 0

    /// 客户端确认号（客户端期望收到的下一个字节的序列号）
    var clientAcknowledgmentNumber: UInt32 = 0

    /// 待发送给客户端的数据缓冲区
    var sendBuffer: Data = Data()

    /// 从客户端接收的数据缓冲区（待发送到代理）
    var receiveBuffer: Data = Data()

    /// 代理连接是否已建立
    var proxyConnected: Bool = false

    /// 代理连接
    var proxyConnection: NWConnection?

    /// 连接创建时间
    let createdAt: Date = Date()

    init(key: TCPConnectionKey) {
        self.key = key
    }
}

// MARK: - TCP 协议栈

/// 简化版 TCP/IP 协议栈
/// 负责解析 IP 数据包、管理 TCP 连接、与代理客户端交互
class TCPStack {

    // MARK: - 属性

    /// 所有 TCP 连接（按四元组索引）
    private var connections: [TCPConnectionKey: TCPConnection] = [:]

    /// 代理连接建立回调（参数：连接、目标地址、目标端口）
    var onNewConnection: ((TCPConnection, String, UInt16) -> Void)?

    /// 从客户端收到数据回调（参数：连接、数据）
    var onClientData: ((TCPConnection, Data) -> Void)?

    /// 写回 IP 数据包的回调
    var writePacket: ((Data) -> Void)?

    /// 下一个可用的 IP 标识
    private var nextIPIdentification: UInt16 = 0

    // MARK: - 处理 IP 数据包

    /// 处理一个 IP 数据包
    /// - Parameter packetData: IP 数据包数据
    func processPacket(_ packetData: Data) {
        // 解析 IP 头
        guard let ipHeader = IPv4Header.parse(from: packetData) else { return }

        // 只处理 IPv4
        guard (ipHeader.versionAndIHL >> 4) == 4 else { return }

        // 只处理 TCP
        guard ipHeader.protocol == IPProtocol.tcp.rawValue else { return }

        // 提取 TCP 数据
        let ipHeaderLength = ipHeader.headerLength
        guard packetData.count >= ipHeaderLength + 20 else { return }
        let tcpData = packetData.subdata(in: ipHeaderLength..<packetData.count)

        // 解析 TCP 头
        guard let tcpHeader = TCPHeader.parse(from: tcpData) else { return }

        // 构建连接标识
        let key = TCPConnectionKey(
            sourceAddress: ipHeader.sourceAddress,
            sourcePort: tcpHeader.sourcePort,
            destinationAddress: ipHeader.destinationAddress,
            destinationPort: tcpHeader.destinationPort
        )

        // 获取或创建连接
        let connection = connections[key] ?? createConnection(key: key)
        connections[key] = connection

        // 处理 TCP 标志位
        let flags = tcpHeader.flagSet

        if flags.contains(.syn) {
            handleSYN(connection: connection, ipHeader: ipHeader, tcpHeader: tcpHeader)
        } else if flags.contains(.ack) && !flags.contains(.fin) {
            handleACK(connection: connection, ipHeader: ipHeader, tcpHeader: tcpHeader, tcpData: tcpData)
        } else if flags.contains(.fin) {
            handleFIN(connection: connection, ipHeader: ipHeader, tcpHeader: tcpHeader)
        }
    }

    // MARK: - 创建连接

    /// 创建新的 TCP 连接
    private func createConnection(key: TCPConnectionKey) -> TCPConnection {
        let connection = TCPConnection(key: key)
        return connection
    }

    // MARK: - 处理 SYN

    /// 处理 SYN 包（客户端发起连接）
    private func handleSYN(connection: TCPConnection, ipHeader: IPv4Header, tcpHeader: TCPHeader) {
        // 记录客户端的初始序列号
        connection.clientAcknowledgmentNumber = tcpHeader.sequenceNumber &+ 1

        // 生成我方初始序列号（随机）
        connection.mySequenceNumber = UInt32.random(in: 0...UInt32.max)

        // 发送 SYN-ACK
        sendTCP(
            connection: connection,
            flags: [.syn, .ack],
            sequenceNumber: connection.mySequenceNumber,
            acknowledgmentNumber: connection.clientAcknowledgmentNumber,
            payload: Data()
        )

        // 更新状态
        connection.state = .synReceived

        // 通知代理建立连接
        let destAddress = ipHeader.destinationAddressString
        let destPort = tcpHeader.destinationPort
        onNewConnection?(connection, destAddress, destPort)
    }

    // MARK: - 处理 ACK

    /// 处理 ACK 包（可能携带数据）
    private func handleACK(connection: TCPConnection, ipHeader: IPv4Header, tcpHeader: TCPHeader, tcpData: Data) {
        // 如果是 SYN-ACK 的确认，连接建立
        if connection.state == .synReceived {
            connection.state = .established
            connection.mySequenceNumber &+= 1
        }

        // 提取 TCP 载荷数据
        let tcpHeaderLength = tcpHeader.headerLength
        if tcpData.count > tcpHeaderLength {
            let payload = tcpData.subdata(in: tcpHeaderLength..<tcpData.count)
            if !payload.isEmpty {
                // 更新客户端确认号
                connection.clientAcknowledgmentNumber = tcpHeader.sequenceNumber &+ UInt32(payload.count)

                // 发送 ACK
                sendTCP(
                    connection: connection,
                    flags: [.ack],
                    sequenceNumber: connection.mySequenceNumber,
                    acknowledgmentNumber: connection.clientAcknowledgmentNumber,
                    payload: Data()
                )

                // 将数据传递给代理
                onClientData?(connection, payload)
            }
        }
    }

    // MARK: - 处理 FIN

    /// 处理 FIN 包（客户端关闭连接）
    private func handleFIN(connection: TCPConnection, ipHeader: IPv4Header, tcpHeader: TCPHeader) {
        // 更新确认号
        connection.clientAcknowledgmentNumber = tcpHeader.sequenceNumber &+ 1

        // 发送 ACK
        sendTCP(
            connection: connection,
            flags: [.ack],
            sequenceNumber: connection.mySequenceNumber,
            acknowledgmentNumber: connection.clientAcknowledgmentNumber,
            payload: Data()
        )

        // 发送 FIN
        sendTCP(
            connection: connection,
            flags: [.fin, .ack],
            sequenceNumber: connection.mySequenceNumber,
            acknowledgmentNumber: connection.clientAcknowledgmentNumber,
            payload: Data()
        )

        connection.mySequenceNumber &+= 1
        connection.state = .closed

        // 关闭代理连接
        connection.proxyConnection?.cancel()

        // 移除连接
        connections.removeValue(forKey: connection.key)
    }

    // MARK: - 发送数据给客户端

    /// 向客户端发送数据
    /// - Parameters:
    ///   - connection: TCP 连接
    ///   - data: 要发送的数据
    func sendToClient(connection: TCPConnection, data: Data) {
        guard connection.state == .established else { return }

        // 将数据加入发送缓冲区
        connection.sendBuffer.append(data)

        // 立即发送
        flushSendBuffer(connection: connection)
    }

    /// 刷新发送缓冲区
    private func flushSendBuffer(connection: TCPConnection) {
        guard !connection.sendBuffer.isEmpty else { return }

        // 每次最多发送 1400 字节（避免 IP 分片）
        let maxSegmentSize = 1400
        while !connection.sendBuffer.isEmpty {
            let chunkSize = min(connection.sendBuffer.count, maxSegmentSize)
            let chunk = connection.sendBuffer.subdata(in: 0..<chunkSize)
            connection.sendBuffer.removeFirst(chunkSize)

            sendTCP(
                connection: connection,
                flags: [.psh, .ack],
                sequenceNumber: connection.mySequenceNumber,
                acknowledgmentNumber: connection.clientAcknowledgmentNumber,
                payload: chunk
            )

            connection.mySequenceNumber &+= UInt32(chunk.count)
        }
    }

    // MARK: - 构造并发送 TCP 包

    /// 构造并发送一个 TCP 包（封装为 IP 数据包）
    private func sendTCP(connection: TCPConnection, flags: TCPFlags, sequenceNumber: UInt32, acknowledgmentNumber: UInt32, payload: Data) {
        // 构造 TCP 头
        var tcpHeader = Data(count: 20)
        tcpHeader[0..<2] = withUnsafeBytes(of: connection.key.destinationPort.bigEndian) { Data($0) }
        tcpHeader[2..<4] = withUnsafeBytes(of: connection.key.sourcePort.bigEndian) { Data($0) }
        tcpHeader[4..<8] = withUnsafeBytes(of: sequenceNumber.bigEndian) { Data($0) }
        tcpHeader[8..<12] = withUnsafeBytes(of: acknowledgmentNumber.bigEndian) { Data($0) }
        tcpHeader[12] = 0x50 // 数据偏移 5（20 字节）
        tcpHeader[13] = flags.rawValue
        tcpHeader[14..<16] = withUnsafeBytes(of: UInt16(65535).bigEndian) { Data($0) } // 窗口大小
        tcpHeader[16..<18] = withUnsafeBytes(of: UInt16(0).bigEndian) { Data($0) } // 校验和（暂为0）
        tcpHeader[18..<20] = withUnsafeBytes(of: UInt16(0).bigEndian) { Data($0) } // 紧急指针

        // TCP 校验和（伪首部 + TCP 头 + 数据）
        let tcpSegment = tcpHeader + payload
        let tcpChecksum = calculateTCPChecksum(
            sourceAddress: connection.key.destinationAddress,
            destinationAddress: connection.key.sourceAddress,
            tcpSegment: tcpSegment
        )
        var tcpSegmentWithChecksum = tcpSegment
        tcpSegmentWithChecksum[16..<18] = withUnsafeBytes(of: tcpChecksum.bigEndian) { Data($0) }

        // 构造 IP 头
        let totalLength = UInt16(20 + tcpSegmentWithChecksum.count)
        var ipHeader = Data(count: 20)
        ipHeader[0] = 0x45 // 版本 4，IHL 5
        ipHeader[1] = 0x00 // 服务类型
        ipHeader[2..<4] = withUnsafeBytes(of: totalLength.bigEndian) { Data($0) }
        ipHeader[4..<6] = withUnsafeBytes(of: nextIPIdentification.bigEndian) { Data($0) }
        nextIPIdentification &+= 1
        ipHeader[6..<8] = withUnsafeBytes(of: UInt16(0x4000).bigEndian) { Data($0) } // 不分片
        ipHeader[8] = 64 // TTL
        ipHeader[9] = IPProtocol.tcp.rawValue
        ipHeader[10..<12] = withUnsafeBytes(of: UInt16(0).bigEndian) { Data($0) } // 校验和（暂为0）
        ipHeader[12..<16] = withUnsafeBytes(of: connection.key.destinationAddress.bigEndian) { Data($0) }
        ipHeader[16..<20] = withUnsafeBytes(of: connection.key.sourceAddress.bigEndian) { Data($0) }

        // IP 头校验和
        let ipChecksum = calculateIPChecksum(ipHeader)
        var ipHeaderWithChecksum = ipHeader
        ipHeaderWithChecksum[10..<12] = withUnsafeBytes(of: ipChecksum.bigEndian) { Data($0) }

        // 完整 IP 数据包
        let packet = ipHeaderWithChecksum + tcpSegmentWithChecksum

        // 写回 packetFlow
        writePacket?(packet)
    }

    // MARK: - 校验和计算

    /// 计算 IP 头校验和
    private func calculateIPChecksum(_ data: Data) -> UInt16 {
        var sum: UInt32 = 0
        let words = data.count / 2
        for i in 0..<words {
            let word = UInt16(bigEndian: data.subdata(in: i*2..<i*2+2).withUnsafeBytes { $0.load(as: UInt16.self) })
            sum += UInt32(word)
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return UInt16(~sum & 0xFFFF)
    }

    /// 计算 TCP 校验和（包含伪首部）
    private func calculateTCPChecksum(sourceAddress: UInt32, destinationAddress: UInt32, tcpSegment: Data) -> UInt16 {
        // 伪首部：源地址(4) + 目标地址(4) + 保留(1) + 协议(1) + TCP长度(2)
        var pseudoHeader = Data(count: 12)
        pseudoHeader[0..<4] = withUnsafeBytes(of: sourceAddress.bigEndian) { Data($0) }
        pseudoHeader[4..<8] = withUnsafeBytes(of: destinationAddress.bigEndian) { Data($0) }
        pseudoHeader[8] = 0
        pseudoHeader[9] = IPProtocol.tcp.rawValue
        pseudoHeader[10..<12] = withUnsafeBytes(of: UInt16(tcpSegment.count).bigEndian) { Data($0) }

        let checksumData = pseudoHeader + tcpSegment
        var sum: UInt32 = 0
        let words = checksumData.count / 2
        for i in 0..<words {
            let word = UInt16(bigEndian: checksumData.subdata(in: i*2..<i*2+2).withUnsafeBytes { $0.load(as: UInt16.self) })
            sum += UInt32(word)
        }
        // 处理奇数字节
        if checksumData.count % 2 == 1 {
            sum += UInt32(checksumData[checksumData.count - 1]) << 8
        }
        while sum >> 16 != 0 {
            sum = (sum & 0xFFFF) + (sum >> 16)
        }
        return UInt16(~sum & 0xFFFF)
    }

    // MARK: - 清理

    /// 清理超时的连接
    func cleanupTimeoutConnections(timeout: TimeInterval = 300) {
        let now = Date()
        for (key, connection) in connections {
            if now.timeIntervalSince(connection.createdAt) > timeout {
                connection.proxyConnection?.cancel()
                connections.removeValue(forKey: key)
            }
        }
    }
}
