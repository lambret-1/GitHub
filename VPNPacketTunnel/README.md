# VPNPacketTunnel（VPN 网络扩展）

## 模块概述

本目录是 iOS NetworkExtension 的 PacketTunnelProvider 扩展 Target，负责在系统层面拦截和处理网络数据包，是 VPN 功能的核心运行时。

## 目录结构

```
VPNPacketTunnel/
├── Info.plist                    # 扩展配置文件
├── VPNPacketTunnel.entitlements  # 扩展权限配置
├── PacketTunnelProvider.swift    # 数据包隧道提供者（核心类）
└── README.md                     # 本说明文档
```

## 文件说明

| 文件名 | 用途 | 核心功能 |
|--------|------|----------|
| `Info.plist` | 扩展配置 | 声明扩展类型为 `com.apple.networkextension.packet-tunnel`，指定主类为 `PacketTunnelProvider` |
| `VPNPacketTunnel.entitlements` | 权限配置 | 声明 NetworkExtension 权限（packet-tunnel-provider）和 App Group 权限 |
| `PacketTunnelProvider.swift` | 核心类 | 继承 `NEPacketTunnelProvider`，实现 VPN 隧道的启动/停止、数据包处理、与主 APP 通信 |

## PacketTunnelProvider 核心方法

### 1. startTunnel(options:completionHandler:)

**用途：** 启动 VPN 隧道，系统在用户点击连接时调用

**执行流程：**
1. 从 App Group 共享数据读取当前节点配置
2. 创建隧道网络设置（NEPacketTunnelNetworkSettings）
3. 配置 IPv4 地址、路由规则、DNS 服务器
4. 调用 `setTunnelNetworkSettings` 应用配置
5. 启动数据包处理循环
6. 调用 completionHandler(nil) 表示启动成功

### 2. stopTunnel(with:completionHandler:)

**用途：** 停止 VPN 隧道，系统在用户点击断开或 VPN 异常时调用

**执行流程：**
1. 设置 `isRunning = false`，停止数据包处理循环
2. 清理资源（关闭网络连接、释放内存）
3. 调用 completionHandler() 表示停止完成

### 3. handleAppMessage(_:completionHandler:)

**用途：** 处理来自主 APP 的消息，主 APP 可以通过此方法与扩展实时通信

**支持的消息：**
- `"getStatus"`: 返回 VPN 扩展运行状态（是否运行、当前节点信息）

### 4. createTunnelNetworkSettings()

**用途：** 创建隧道网络配置

**配置内容：**
- 远程服务器地址：`127.0.0.1`（第一期占位）
- IPv4 地址：`10.0.0.2`，子网掩码 `255.255.255.0`
- 包含路由：默认路由（捕获所有流量）
- 排除路由：局域网地址（10.0.0.0/8、172.16.0.0/12、192.168.0.0/16、127.0.0.0/8）
- DNS 服务器：`8.8.8.8`、`1.1.1.1`（第一期使用公共 DNS）
- MTU：`1400`（避免 VPN 隧道分片）

### 5. startPacketHandling()

**用途：** 启动数据包处理循环

**执行流程：**
1. 在后台队列（`com.github.client.vpn.packet`）运行循环
2. 循环调用 `packetFlow.readPackets()` 读取系统网络数据包
3. 第一期：直接调用 `packetFlow.writePackets()` 将数据包写回（直连，不做代理）
4. 后续期：将数据包通过 VLESS/VMess 协议发送到代理节点

### 6. loadNodeConfiguration(completion:)

**用途：** 从 App Group 共享数据读取当前节点配置

**数据来源：**
- App Group 标识：`group.com.github.client`
- 存储 Key：`vpn_current_node`
- 数据格式：JSON 序列化的 VPNNode 对象

### 7. cleanupResources()

**用途：** 清理资源，在 VPN 隧道停止时调用

**第一期：** 暂无特殊资源需要清理
**后续期：** 需要关闭网络连接、清理协议栈、释放内存等

## 网络设置说明

### 虚拟网卡地址

使用 `10.0.0.2` 作为 VPN 虚拟网卡地址，这是 VPN 隧道的标准做法。虚拟网卡用于在系统中创建一个网络接口，所有被路由到 VPN 的流量都会通过这个接口发送给扩展处理。

### 路由规则

**包含路由（走 VPN）：**
- 默认路由 `0.0.0.0/0`：所有流量默认走 VPN

**排除路由（直连，不走 VPN）：**
- `10.0.0.0/8`：A 类私有地址
- `172.16.0.0/12`：B 类私有地址
- `192.168.0.0/16`：C 类私有地址
- `127.0.0.0/8`：回环地址

排除局域网地址是为了让局域网内的设备通信（如访问路由器、局域网共享）不经过 VPN 隧道，直接连接。

### DNS 配置

第一期使用公共 DNS 服务器：
- `8.8.8.8`（Google DNS）
- `1.1.1.1`（Cloudflare DNS）

`matchDomains = [""]` 表示匹配所有域名，即所有 DNS 查询都通过 VPN 隧道发送，防止 DNS 泄漏。

后续期将支持：
- 自定义 DNS 服务器
- DNS 分流（国内域名用国内 DNS，国外域名用国外 DNS）
- DNS over HTTPS (DoH) / DNS over TLS (DoT)
- DNS 缓存

## 与主 APP 通信

### 数据共享（App Group）

主 APP 和 VPN 扩展通过 App Group 共享数据：

**主 APP → 扩展：**
- 当前节点配置（`vpn_current_node`）

**扩展 → 主 APP：**
- 第一期暂无主动推送
- 后续期可通过 App Group 共享流量统计、连接日志等

### 消息通信

主 APP 可以通过 `NETunnelProviderSession.sendProviderMessage(_:responseHandler:)` 向扩展发送消息：

```swift
// 主 APP 发送消息
let session = vpnManager.connection as! NETunnelProviderSession
try session.sendProviderMessage(Data("getStatus".utf8)) { responseData in
    // 处理扩展回复
}
```

扩展通过 `handleAppMessage(_:completionHandler:)` 接收并回复消息。

## 第一期功能限制

1. **数据包处理**：第一期读取数据包后直接写回（直连），不做任何协议代理
2. **节点配置**：虽然读取了节点配置，但第一期并未使用节点信息建立代理连接
3. **流量统计**：第一期未实现流量统计功能
4. **路由分流**：第一期仅使用简单的全局路由+局域网排除，未实现按域名/IP 精确分流
5. **DNS 功能**：第一期仅使用固定公共 DNS，未实现自定义 DNS、DNS 分流等功能

## 后续期开发计划

### 第二期：协议实现
- 集成 V2RayCore 或自研 VMess/VLESS 协议栈
- 实现 TCP/UDP 代理转发
- 实现真正的数据包代理逻辑

### 第三期：高级功能
- 路由分流（按域名/IP/应用分流）
- DNS 功能（自定义 DNS、DNS 分流、DoH/DoT）
- 流量统计（实时速度、周期统计）
- 节点测速

### 第四期：性能优化
- 协议性能优化
- 内存优化（扩展有 50MB 内存限制）
- 电池消耗优化
- 稳定性优化

## 注意事项

1. **内存限制**：NetworkExtension 扩展有内存限制（约 50MB），协议实现必须注意内存优化，避免内存泄漏
2. **独立进程**：扩展运行在独立进程，与主 APP 不共享内存，必须通过 App Group 或消息通信
3. **生命周期**：扩展由系统管理，系统可能在资源紧张时终止扩展，需要实现状态恢复
4. **TrollStore 安装**：NetworkExtension 需要完整 entitlements，必须通过 TrollStore 安装才能正常使用，普通重签名可能导致 entitlements 失效
5. **日志记录**：扩展使用 `OSLog` 记录日志，可通过 macOS Console.app 或 Xcode 查看
