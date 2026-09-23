# VPNPacketTunnel（VPN 网络扩展 - Xray-core 动态框架版）

## 模块概述

本目录是 iOS NetworkExtension 的 PacketTunnelProvider 扩展 Target，负责在系统层面拦截和处理网络数据包。

**核心架构**：采用动态框架方案，将 Xray-core（Go 语言编译的静态库）封装为 `XrayKit.framework` 动态框架，扩展只包含 Swift 代码（二进制 < 1MB），运行时动态加载 Xray 核心。

**为什么用动态框架？**
- Xray 静态库约 64MB，直接链接到扩展会导致扩展二进制达 54MB
- NetworkExtension 内存限制约 50MB，超限时系统在 dyld 加载阶段直接杀死扩展进程
- 动态框架方案：扩展二进制仅 127KB（参考官方 sing-box），Go 运行时在框架中动态加载
- 参考实现：官方 sing-box-for-apple（Extension.appex 二进制 127KB，Library.framework 91MB）

## 目录结构

```
VPNPacketTunnel/
├── Info.plist                          # 扩展配置文件
├── VPNPacketTunnel.entitlements        # 扩展权限配置
├── PacketTunnelProvider.swift          # 数据包隧道提供者（核心类，导入 XrayKit）
├── SignalHandler.c                     # C 级信号处理器（崩溃日志捕获）
├── Xray.xcframework/                   # Xray 核心框架（Go 静态库，不纳入版本控制）
│   ├── ios-arm64/                      # 真机版本
│   │   ├── libxray.a                   # 静态库（约64MB）
│   │   └── Headers/libxray.h           # C API 头文件
│   ├── ios-arm64-simulator/            # 模拟器版本
│   └── Info.plist                      # 框架配置
├── XrayKit/                            # Xray 动态框架 Target 源码
│   ├── XrayKit-Bridging-Header.h       # 桥接头文件（导入 Xray C API）
│   └── XrayCore.swift                  # Xray C API 的 Swift 封装（公开类）
└── README.md                           # 本说明文档
```

## 文件说明

| 文件名 | 用途 | 核心功能 |
|--------|------|----------|
| `Info.plist` | 扩展配置 | 声明扩展类型为 `com.apple.networkextension.packet-tunnel`，指定主类为 `PacketTunnelProvider` |
| `VPNPacketTunnel.entitlements` | 权限配置 | 声明 NetworkExtension 权限（packet-tunnel-provider）和 App Group 权限 |
| `PacketTunnelProvider.swift` | 核心类 | 继承 `NEPacketTunnelProvider`，管理 VPN 隧道生命周期，通过 `XrayKit` 动态框架启动 Xray 核心 |
| `SignalHandler.c` | 崩溃捕获 | C 级信号处理器，使用 `__attribute__((constructor))` 在库加载时注册信号，崩溃日志写入 /tmp |
| `Xray.xcframework` | Xray 核心 | Go 语言编译的静态库，提供 VLESS/VMess/Trojan/Shadowsocks 等协议支持（CI 构建时自动下载） |
| `XrayKit/XrayKit-Bridging-Header.h` | 桥接头文件 | 导入 `libxray.h`，使 Swift 能够调用 Xray C API（属于动态框架 Target） |
| `XrayKit/XrayCore.swift` | Swift 封装 | 将 Xray C API 封装为 `XrayCore` 公开类，供扩展调用 |

## XrayKit 动态框架 API

```swift
import XrayKit

// 启动 Xray 核心
// configJSON: Xray JSON 配置字符串
// tunFd: TUN 设备文件描述符
// 返回: 0 表示成功，非 0 表示失败
let result = XrayCore.shared.start(configJSON: config, tunFd: tunFd)

// 停止 Xray 核心
let result = XrayCore.shared.stop()

// 获取 Xray 版本
let version = XrayCore.shared.getVersion()

// 查询出站流量统计
let stats = XrayCore.shared.queryStats(tag: "proxy")
```

## PacketTunnelProvider 核心方法

### 1. startTunnel(options:completionHandler:)

**用途**：启动 VPN 隧道，系统在用户点击连接时调用

**执行流程**：
1. 从 App Group UserDefaults 读取 Xray JSON 配置（key: `xray_config_json`）
2. 创建隧道网络设置（NEPacketTunnelNetworkSettings）
3. 配置 IPv4/IPv6 地址、路由规则、DNS 服务器
4. 调用 `setTunnelNetworkSettings` 应用配置
5. 获取 TUN 设备文件描述符（扫描所有 fd 找最高编号 utun）
6. 调用 `XrayCore.shared.start(configJSON:tunFd:)` 启动 Xray 核心（通过动态框架）
7. 调用 completionHandler(nil) 表示启动成功

### 2. stopTunnel(with:completionHandler:)

**用途**：停止 VPN 隧道，系统在用户点击断开或 VPN 异常时调用

**执行流程**：
1. 调用 `XrayCore.shared.stop()` 停止 Xray 核心（通过动态框架）
2. 调用 completionHandler() 表示停止完成

### 3. handleAppMessage(_:completionHandler:)

**用途**：处理来自主 APP 的消息

**支持的消息**：
- `"getStatus"`: 返回 VPN 运行状态（running/stopped）
- `"getVersion"`: 返回 Xray 核心版本（通过 XrayKit）
- `"getStats"`: 返回流量统计（JSON 格式，通过 XrayKit）

### 4. getTunnelFileDescriptor()

**用途**：获取 TUN 设备文件描述符

**实现原理**：
- 扫描 0-1023 范围内的所有文件描述符
- 通过 `getsockopt(fd, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, ...)` 获取接口名称
- 找到名称以 "utun" 开头的最高编号 fd（当前 VPN 隧道）
- 备用方案：通过 KVC `packetFlow.socket.fileDescriptor` 获取

## 网络设置说明

### 虚拟网卡地址

- IPv4: `198.18.0.1/16`（Xray 标准虚拟地址段）
- IPv6: `fd6e:a81b:704f:1211::1/64`

### 路由规则

- 包含路由：默认路由 `0.0.0.0/0`（所有流量走 VPN）
- 包含路由：IPv6 默认路由 `::/0`

### DNS 配置

- 服务器：`1.1.1.1`（Cloudflare）、`8.8.8.8`（Google）
- matchDomains = `[""]`：匹配所有域名，防止 DNS 泄漏

### MTU

- `1500`：标准以太网 MTU，避免 VPN 隧道分片

## 与主 APP 通信

### 数据共享（App Group）

主 APP 和 VPN 扩展通过 App Group（`group.com.github.client`）共享数据：

**主 APP → 扩展：**
- Xray JSON 配置（key: `xray_config_json`）
- 当前节点配置（key: `vpn_current_node`）

**扩展 → 主 APP：**
- 通过 `handleAppMessage` 实时查询状态、版本、流量统计

### Xray 配置生成

主 APP 的 `VPNManager.generateXrayConfig(from:)` 方法根据节点类型生成 Xray JSON 配置：

**配置结构**：
- `log`: 日志级别（warning）
- `inbounds`: TUN 入站（dokodemo-door，捕获所有流量，开启嗅探）
- `outbounds`: 代理出站（根据节点类型生成 VLESS/VMess/Trojan/Shadowsocks）
- `routing`: 路由规则
- `dns`: DNS 服务器

**支持的协议**：
- VLESS（支持 XTLS Vision flow）
- VMess
- Trojan
- Shadowsocks

**支持的传输方式**：
- TCP
- WebSocket（支持 Host 头和 Path）
- gRPC
- HTTP/2
- mKCP
- QUIC

**支持的安全层**：
- TLS（支持 serverName、fingerprint）
- 无加密（明文传输）

## 构建注意事项

### XcodeGen 配置

在 `project.yml` 中，有两个相关 Target：

**XrayKit（动态框架 Target）：**
```yaml
XrayKit:
  type: framework
  settings:
    base:
      # 桥接头文件（属于动态框架）
      SWIFT_OBJC_BRIDGING_HEADER: VPNPacketTunnel/XrayKit/XrayKit-Bridging-Header.h
      # 头文件搜索路径
      HEADER_SEARCH_PATHS: "$(SRCROOT)/VPNPacketTunnel/Xray.xcframework/ios-arm64/Headers"
      # 链接 resolv 库（Go 静态库 DNS 解析需要）
      OTHER_LDFLAGS: "-lresolv"
      # 动态框架不剥离符号（运行时需要）
      STRIP_INSTALLED_PRODUCT: NO
      DEAD_CODE_STRIPPING: NO
  dependencies:
    - framework: VPNPacketTunnel/Xray.xcframework
      embed: false  # 静态库链接到动态框架中，不嵌入
```

**VPNPacketTunnel（扩展 Target）：**
```yaml
VPNPacketTunnel:
  type: app-extension
  settings:
    base:
      # 扩展二进制很小，不需要特殊链接参数
      # 运行路径搜索：让扩展能找到嵌入的动态框架
      LD_RUNPATH_SEARCH_PATHS: "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks"
  dependencies:
    - target: XrayKit
      embed: true  # 动态框架嵌入到扩展的 Frameworks 目录
```

### CI 构建

- Xray.xcframework 不纳入版本控制（.gitignore），CI 构建时通过 `scripts/download_xray_framework.sh` 自动下载
- 构建时 XcodeGen 会自动生成 XrayKit 动态框架 Target 和 VPNPacketTunnel 扩展 Target
- 导出 IPA 时需要确保：
  1. 扩展被正确嵌入到 .app 包的 PlugIns 目录
  2. XrayKit.framework 被正确嵌入到扩展的 Frameworks 目录
  3. ldid 注入 entitlements 到主应用和扩展二进制

## 内存限制解决方案

**问题**：NetworkExtension 扩展有内存限制（约 50MB），Xray 静态库直接链接会导致扩展二进制 54MB，系统在 dyld 加载阶段直接杀死进程。

**解决方案**：动态框架架构
1. 将 Xray 静态库链接到 `XrayKit.framework` 动态框架中
2. 扩展只链接动态框架，二进制体积 < 1MB
3. 运行时系统动态加载 XrayKit.framework，Go 运行时在框架中初始化
4. 参考官方 sing-box-for-apple：扩展二进制 127KB，动态框架 91MB

**验证方法**：
- 构建后检查扩展二进制大小：应 < 1MB
- 检查扩展包内 Frameworks 目录：应包含 XrayKit.framework
- VPN 连接时扩展应能正常启动，不会立即断开

## TrollStore 安装注意事项

NetworkExtension 需要完整 entitlements：
- 必须通过 TrollStore 安装才能正常使用
- 普通重签名（如全能签）可能导致 entitlements 失效
- CI 流水线已添加 ldid 注入 entitlements 步骤，确保 IPA 包含完整权限
- 动态框架也需要正确签名，ldid 会自动处理

## 故障排查

### VPN 连接后立即断开（扩展启动失败）

1. **检查扩展二进制大小**：应 < 1MB，如果 > 50MB 说明动态框架方案未生效
2. **检查 XrayKit.framework 是否嵌入**：扩展包内 Frameworks 目录应包含 XrayKit.framework
3. **检查 entitlements**：使用 `ldid -e` 查看扩展二进制是否包含 packet-tunnel-provider 权限
4. **查看扩展日志**：主 APP 调试日志中会自动读取扩展日志（App Group 共享）

### VPN 连接成功但节点不通

1. 检查 Xray 配置是否正确生成（在主 APP 中查看调试日志）
2. 检查节点信息是否正确（服务器地址、端口、UUID、协议类型）
3. 检查传输方式和安全层配置是否与服务器匹配
4. 查看 Xray 核心日志（可通过 macOS Console.app 查看系统日志）

### 启动失败：获取 TUN 文件描述符失败

1. 确保扩展 entitlements 包含 `packet-tunnel-provider`
2. 确保通过 TrollStore 安装（普通重签名可能丢失权限）
3. 尝试重启设备后重新连接

### 启动失败：Xray 核心启动失败

1. 检查 Xray JSON 配置格式是否正确
2. 检查配置中的协议、传输方式、安全层是否匹配
3. 查看错误码（XrayCore.start 返回值），对照 Xray 文档排查
4. 检查 XrayKit.framework 是否被正确加载（动态框架路径问题）

---

## 第一期重构说明（v0.1.0 底层基座）

### 重构日期
2026-09-23

### 本次重构解决的问题
1. 修复“连接中秒断、扩展日志为空”：废弃 UserDefaults 拼接日志，改为 App Group 文件日志
   - 日志路径：`<AppGroup容器>/vpn扩展日志/隧道启动日志.log`
2. 启动链路严格分段校验并输出日志：
   - 进程 init → 读取配置 → JSON 语法校验 → setTunnelNetworkSettings → 获取 utun fd → StartXray
3. 任意阶段失败均回调具体错误码，不再静默失败
4. C 层信号处理器改用 `sigaction` 注册，移除无用宏定义，崩溃记录在 init 阶段自动转存
5. 扩展 Info.plist 版本号改用 `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)`，与主 App 版本对齐，消除 CFBundleVersion 不一致警告
6. `project.yml` 中扩展显式关闭 `BUILD_LIBRARY_FOR_DISTRIBUTION`，消除 XrayKit 库演化警告

### 一期验收标准
- App Group 内必然生成 `vpn扩展日志/隧道启动日志.log`
- 隧道状态流转：已断开 → 连接中 → 已连接
- StartXray 返回非 0 时可在日志中直接看到错误码与失败阶段
