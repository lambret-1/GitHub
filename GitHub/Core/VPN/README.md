# VPN 核心模块

## 模块概述

本目录包含 VPN 功能的核心逻辑代码，负责 VPN 节点管理、连接控制、节点导入等功能。

## 文件说明

| 文件名 | 用途 | 核心功能 |
|--------|------|----------|
| `VPNNode.swift` | VPN 节点数据模型 | 定义节点的所有属性（协议、地址、端口、UUID、加密方式、传输协议、TLS配置等），支持序列化和持久化 |
| `VPNManager.swift` | VPN 管理器 | 单例模式，负责 VPN 配置管理、连接/断开控制、节点数据持久化、与 VPN 扩展通信、监听连接状态变化 |
| `VPNNodeImporter.swift` | 节点导入工具 | 支持从剪贴板导入 VMess/VLESS 节点链接，自动识别协议格式，解析节点配置参数 |

## 数据结构

### VPNNode（节点模型）

**基础信息：**
- `id`: 节点唯一标识（UUID）
- `remark`: 节点备注名称
- `group`: 节点分组

**连接信息：**
- `protocolType`: 协议类型（VMess/VLESS/Trojan/Shadowsocks/Hysteria/TUIC）
- `serverAddress`: 服务器地址
- `serverPort`: 服务器端口
- `uuid`: 用户 UUID
- `encryption`: 加密方式

**传输配置：**
- `transportType`: 传输协议（TCP/WebSocket/gRPC/mKCP/QUIC/HTTP2）
- `wsPath`: WebSocket 路径
- `wsHost`: WebSocket Host
- `grpcServiceName`: gRPC 服务名

**TLS 配置：**
- `enableTLS`: 是否启用 TLS
- `tlsServerName`: TLS 服务器名称（SNI）
- `allowInsecure`: 是否跳过证书验证
- `alpn`: ALPN 协议列表

**测速信息：**
- `latency`: 延迟（毫秒）
- `downloadSpeed`: 下载速度（MB/s）
- `lastSpeedTest`: 最后测速时间
- `isAvailable`: 节点是否可用

## VPNManager 使用说明

### 获取单例

```swift
let vpnManager = VPNManager.shared
```

### 请求 VPN 权限

```swift
VPNManager.shared.requestVPNPermission { success, error in
    if success {
        print("VPN 权限获取成功")
    } else {
        print("VPN 权限获取失败: \(error?.localizedDescription ?? "未知错误")")
    }
}
```

### 连接/断开 VPN

```swift
// 连接
VPNManager.shared.connect { error in
    if let error = error {
        print("连接失败: \(error.localizedDescription)")
    }
}

// 断开
VPNManager.shared.disconnect()

// 切换连接状态
VPNManager.shared.toggleConnection()
```

### 节点管理

```swift
// 添加节点
VPNManager.shared.addNode(node)

// 删除节点
VPNManager.shared.removeNode(node)

// 更新节点
VPNManager.shared.updateNode(node)

// 选择节点（设置为当前连接节点）
VPNManager.shared.selectNode(node)

// 批量删除
VPNManager.shared.removeNodes(nodes)

// 清空所有节点
VPNManager.shared.clearAllNodes()
```

### 监听连接状态

```swift
VPNManager.shared.onStatusChange = { status in
    print("VPN 状态变化: \(status.displayText)")
}
```

## 节点导入格式

### VMess 链接格式

```
vmess://base64(json)
```

JSON 字段（V2RayN 标准格式）：
- `v`: 版本
- `ps`: 备注名称
- `add`: 服务器地址
- `port`: 端口
- `id`: UUID
- `aid`: 额外 ID（已废弃）
- `scy`: 加密方式
- `net`: 传输协议
- `type`: 伪装类型
- `host`: 伪装域名
- `path`: 路径
- `tls`: TLS 类型
- `sni`: SNI
- `alpn`: ALPN

### VLESS 链接格式

```
vless://uuid@server:port?type=tcp&security=tls&sni=example.com#备注名称
```

查询参数：
- `type`: 传输协议（tcp/ws/grpc/quic）
- `security`: 安全类型（none/tls/reality）
- `sni`: SNI 服务器名称
- `host`: WebSocket Host
- `path`: WebSocket 路径
- `serviceName`: gRPC 服务名
- `flow`: 流控类型
- `alpn`: ALPN 协议列表
- `allowInsecure`: 是否跳过证书验证

## 注意事项

1. **App Group 数据共享**：主 APP 与 VPN 扩展通过 `group.com.github.client` 共享数据，节点配置存储在 App Group 的 UserDefaults 中
2. **扩展内存限制**：VPN 扩展运行在独立进程，有内存限制（约 50MB），协议实现需要注意内存优化
3. **第一期限制**：第一期仅实现基础框架和节点管理，VPN 隧道启动后数据包直接转发（不做代理），后续期将集成 VLESS/VMess 协议实现真正的代理
4. **TrollStore 安装**：NetworkExtension 需要完整 entitlements，必须通过 TrollStore 安装才能正常使用
