# 制品说明文档

## 文档信息

| 项目 | 内容 |
|------|------|
| 文档名称 | 制品说明文档 |
| 适用项目 | GitHub iOS 客户端 |
| 文档版本 | v1.0.0 |
| 最后更新 | 2026-09-09 |

---

## 一、制品概述

### 1.1 制品类型

本项目 CI 流水线产出的制品为 **未签名 iOS IPA 包**，专门适配全能签等本地重签名工具导入使用。

| 制品属性 | 值 |
|---------|-----|
| 制品格式 | `.ipa` (iOS App Store Package) |
| 签名状态 | **未签名**（需要本地重签名后安装） |
| 包结构 | 标准 `Payload/*.app` 结构 |
| 最低系统 | iOS 15.0 |
| 支持设备 | iPhone / iPad（通用应用） |
| 架构 | arm64（真机） |

### 1.2 制品下载地址

每次生产构建成功后，制品会上传到 GitHub Actions Artifacts。

**下载步骤**：
1. 进入仓库主页：https://github.com/lambret-1/GitHub
2. 点击顶部「Actions」标签
3. 在左侧选择「生产构建流水线」
4. 点击最新的成功构建记录（绿色对勾标记）
5. 滚动到页面底部「Artifacts」区域
6. 下载以下两个文件：
   - `GitHub-iOS-IPA-v{版本号}` — IPA 安装包
   - `GitHub-iOS-Metadata-v{版本号}` — 制品元数据 JSON

---

## 二、制品元数据说明

### 2.1 元数据文件结构

每次构建会生成一个独立的 `artifact-metadata.json` 文件，随 IPA 一起作为 Artifact 归档。

**JSON 结构示例**：

```json
{
  "artifact_type": "ios-ipa",
  "version": "1.0.1",
  "file_name": "GitHub.ipa",
  "file_size_bytes": 2457600,
  "file_size_human": "2.34 MB",
  "sha256": "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1",
  "git_commit_short": "abc1234",
  "build_time": "2026-09-09 12:00:00 CST",
  "build_time_iso": "2026-09-09T04:00:00Z",
  "build_duration_seconds": 180,
  "build_duration_human": "3分0秒",
  "build_environment": {
    "os": "macOS 14.5",
    "xcode_version": "Xcode 15.4",
    "runner": "GitHub Actions",
    "github_actions": "true"
  }
}
```

### 2.2 元数据字段说明

| 字段 | 类型 | 说明 |
|------|------|------|
| `artifact_type` | string | 制品类型，固定为 `ios-ipa` |
| `version` | string | 应用版本号（三段式语义版本） |
| `file_name` | string | IPA 文件名 |
| `file_size_bytes` | number | 文件大小（字节） |
| `file_size_human` | string | 文件大小（人类可读格式） |
| `sha256` | string | 文件 SHA256 哈希值（64位十六进制） |
| `git_commit_short` | string | 触发构建的 Git 短 Commit 哈希 |
| `build_time` | string | 构建时间（本地时区格式） |
| `build_time_iso` | string | 构建时间（ISO 8601 标准格式） |
| `build_duration_seconds` | number | 构建总耗时（秒） |
| `build_duration_human` | string | 构建总耗时（人类可读格式） |
| `build_environment.os` | string | 构建操作系统 |
| `build_environment.xcode_version` | string | Xcode 版本 |
| `build_environment.runner` | string | 构建 Runner 名称 |
| `build_environment.github_actions` | string | 是否在 GitHub Actions 环境构建 |

### 2.3 元数据用途

1. **制品溯源**：通过 `git_commit_short` 追溯到具体的代码提交
2. **完整性校验**：通过 `sha256` 校验 IPA 文件是否被篡改或损坏
3. **版本管理**：通过 `version` 确认制品对应的应用版本
4. **构建审计**：通过 `build_time`、`build_duration` 等字段审计构建过程
5. **离线归档**：元数据 JSON 可独立保存，用于长期归档和离线校验

---

## 三、SHA256 校验使用说明

### 3.1 为什么需要校验

IPA 文件在下载、传输、存储过程中可能发生损坏或被篡改。通过校验 SHA256 哈希值，可以确保：
- 文件完整性：文件没有在传输中损坏
- 文件真实性：文件与 CI 流水线产出的原始文件一致
- 安全性：文件没有被恶意篡改或植入恶意代码

### 3.2 macOS 校验方法

**方法一：使用 shasum 命令（推荐）**

```bash
# 进入下载目录
cd ~/Downloads

# 计算 IPA 文件的 SHA256 哈希
shasum -a 256 GitHub.ipa

# 输出示例:
# a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1  GitHub.ipa
```

将计算结果与 `artifact-metadata.json` 中的 `sha256` 字段对比，如果一致则说明文件完整。

**方法二：使用 openssl 命令**

```bash
openssl dgst -sha256 GitHub.ipa
```

**方法三：自动校验脚本**

```bash
#!/bin/bash
# save as verify-ipa.sh

IPA_FILE="GitHub.ipa"
METADATA_FILE="artifact-metadata.json"

# 计算实际SHA256
ACTUAL_SHA=$(shasum -a 256 "${IPA_FILE}" | awk '{print $1}')

# 从元数据读取期望SHA256
EXPECTED_SHA=$(grep -o '"sha256": "[^"]*"' "${METADATA_FILE}" | sed 's/"sha256": "//;s/"//')

echo "实际SHA256:   ${ACTUAL_SHA}"
echo "期望SHA256:   ${EXPECTED_SHA}"

if [ "${ACTUAL_SHA}" == "${EXPECTED_SHA}" ]; then
    echo "✅ SHA256校验通过，文件完整可信"
else
    echo "❌ SHA256校验失败，文件可能已损坏或被篡改"
    exit 1
fi
```

### 3.3 Windows 校验方法

**方法一：使用 PowerShell**

```powershell
# 计算SHA256
Get-FileHash -Algorithm SHA256 .\GitHub.ipa

# 输出示例:
# Algorithm       Hash                                                                   Path
# ---------       ----                                                                   ----
# SHA256          A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A1   C:\...\GitHub.ipa
```

**方法二：使用 certutil 命令**

```cmd
certutil -hashfile GitHub.ipa SHA256
```

### 3.4 校验失败处理

如果 SHA256 校验失败：

1. **不要安装该 IPA**：文件可能已损坏或被篡改，安装可能导致安全风险
2. **重新下载**：从 GitHub Actions 重新下载 IPA 文件
3. **检查网络**：确认下载过程中网络稳定，没有中断
4. **检查存储介质**：确认存储设备没有坏道或损坏
5. **联系维护者**：如多次下载均校验失败，联系项目维护者排查

---

## 四、全能签导入 IPA 注意事项

### 4.1 什么是全能签

全能签是一款 iOS 应用重签名工具，可以对未签名的 IPA 进行本地重签名，使其可以安装到 iOS 设备上。

**适用场景**：
- 个人开发者自签名安装
- 企业证书内部分发
- 测试设备安装未上架应用
- 绕过 App Store 分发限制

### 4.2 导入前准备

**必需条件**：
- ✅ 一台 Windows 或 macOS 电脑
- ✅ 全能签工具（最新版本）
- ✅ 有效的签名证书（个人开发者证书 / 企业证书 / 免费开发证书）
- ✅ 对应的 Provisioning Profile（描述文件）
- ✅ iOS 设备（iPhone / iPad）
- ✅ 数据线（用于连接设备安装）

**推荐准备**：
- iOS 设备系统版本 iOS 15.0 或以上
- 电脑已安装最新版 iTunes（Windows）或 Finder（macOS）
- 设备已信任电脑

### 4.3 导入步骤

**步骤 1：下载 IPA 文件**
- 从 GitHub Actions 下载最新的 `GitHub-iOS-IPA-v{版本号}.zip`
- 解压得到 `GitHub.ipa` 文件

**步骤 2：校验文件完整性（推荐）**
- 使用上述 SHA256 校验方法验证文件完整性
- 校验通过后再进行重签名

**步骤 3：打开全能签**
- 启动全能签工具
- 确认工具版本为最新版

**步骤 4：导入 IPA**
- 将 `GitHub.ipa` 文件拖拽到全能签窗口
- 或点击「导入IPA」按钮选择文件
- 等待全能签解析 IPA 包信息

**步骤 5：配置签名参数**
- 选择签名证书（个人/企业证书）
- 选择对应的 Provisioning Profile
- 确认 Bundle ID（建议保持默认，或修改为你证书支持的 Bundle ID）
- 可选：修改应用名称、版本号等

**步骤 6：执行重签名**
- 点击「开始签名」按钮
- 等待签名完成（通常 10-30 秒）
- 签名成功后会生成新的已签名 IPA 文件

**步骤 7：安装到设备**
- 连接 iOS 设备到电脑
- 在全能签中选择已签名的 IPA
- 点击「安装到设备」按钮
- 在 iOS 设备上确认安装
- 安装完成后在桌面找到应用图标

**步骤 8：信任证书（首次安装）**
- 打开 iOS 设备「设置」→「通用」→「VPN与设备管理」
- 找到对应的开发者证书
- 点击「信任」按钮
- 确认信任后即可打开应用

### 4.4 常见问题排查

**问题 1：全能签无法识别 IPA**

**可能原因**：
- IPA 文件下载不完整或损坏
- IPA 包结构不符合标准
- 全能签版本过旧

**解决方案**：
- 重新下载 IPA 文件
- 校验 SHA256 确保文件完整
- 更新全能签到最新版本
- 检查 IPA 是否可以用解压软件打开（应为 zip 格式，内含 Payload 目录）

---

**问题 2：签名失败，提示证书无效**

**可能原因**：
- 证书已过期
- 证书与 Provisioning Profile 不匹配
- 证书没有对应的私钥
- Bundle ID 与 Provisioning Profile 不匹配

**解决方案**：
- 检查证书有效期，过期则重新申请
- 确认证书与 Provisioning Profile 对应
- 确认证书已正确安装到系统钥匙串
- 修改 Bundle ID 为 Provisioning Profile 支持的 ID

---

**问题 3：安装失败，提示无法安装**

**可能原因**：
- 设备 UDID 未添加到 Provisioning Profile
- 设备系统版本低于应用最低要求（iOS 15.0）
- 设备存储空间不足
- 证书类型不支持该设备

**解决方案**：
- 将设备 UDID 添加到 Provisioning Profile 并重新生成
- 确认设备系统版本 ≥ iOS 15.0
- 清理设备存储空间
- 使用正确类型的证书（开发证书/企业证书）

---

**问题 4：安装后打开闪退**

**可能原因**：
- 证书未被信任
- 签名过程中出现错误
- 应用本身存在兼容性问题

**解决方案**：
- 在「设置」→「通用」→「VPN与设备管理」中信任证书
- 重新进行重签名操作
- 确认设备系统版本满足要求
- 查看设备崩溃日志排查具体原因

---

**问题 5：应用功能异常，无法登录**

**可能原因**：
- GitHub Token 权限不足
- 网络连接问题
- Token 已过期或被撤销

**解决方案**：
- 确认 Token 已勾选 `repo` 和 `user` 权限
- 检查设备网络连接
- 重新生成 GitHub Token 并登录
- 确认 GitHub 账号状态正常

---

## 五、制品生命周期管理

### 5.1 制品保留策略

| 制品类型 | 保留天数 | 自动清理 | 说明 |
|---------|---------|---------|------|
| IPA 文件 | 30 天 | ✅ 自动 | 超过30天自动删除，节约存储配额 |
| 元数据 JSON | 30 天 | ✅ 自动 | 与 IPA 同步保留 |
| 编译日志 | 7 天 | ✅ 自动 | 日志仅用于短期问题排查 |

### 5.2 制品版本对应关系

每个 IPA 制品与代码版本严格对应：

| 制品版本 | 对应Git Tag/Commit | 对应Info.plist版本 | 说明 |
|---------|-------------------|-------------------|------|
| v1.0.0 | 初始提交 | 1.0.0 | 首个发布版本 |
| v1.0.1 | main分支第N次提交 | 1.0.1 | 补丁更新 |
| v1.1.0 | main分支第M次提交 | 1.1.0 | 次版本更新（补丁满9进位） |

**版本追溯方法**：
1. 查看 `artifact-metadata.json` 中的 `git_commit_short` 字段
2. 在 GitHub 仓库中使用该 Commit 哈希查看对应代码
3. 通过 README 顶部的更新日志确认该版本的功能变更

### 5.3 旧版本获取

如需获取超过 30 天的历史版本：

1. **重新触发构建**：
   - 进入仓库 Actions 页面
   - 选择「生产构建流水线」
   - 手动触发构建，生成最新版本

2. **从 Git 历史重建**：
   - 检出对应版本的代码提交
   - 本地使用 Xcode 编译导出 IPA

3. **联系维护者**：
   - 如维护者有本地归档，可请求提供

---

## 六、安全建议

### 6.1 下载安全

- ✅ 仅从官方 GitHub Actions 下载 IPA
- ✅ 下载后校验 SHA256 哈希
- ❌ 不要从第三方网站下载本应用的 IPA
- ❌ 不要使用来源不明的重签名版本

### 6.2 签名安全

- ✅ 使用自己的证书进行重签名
- ✅ 妥善保管证书私钥
- ❌ 不要使用来源不明的证书
- ❌ 不要将证书私钥上传到公开仓库

### 6.3 Token 安全

- ✅ Token 仅存储在设备本地 Keychain
- ✅ 定期轮换 GitHub Token
- ✅ 设置合理的 Token 过期时间
- ❌ 不要将 Token 分享给他人
- ❌ 不要将 Token 硬编码到代码中

### 6.4 设备安全

- ✅ 仅在信任的设备上安装应用
- ✅ 及时更新 iOS 系统
- ✅ 启用设备密码保护
- ❌ 不要越狱设备上使用敏感账号
- ❌ 不要在公共设备上登录敏感账号

---

## 七、联系与反馈

如在制品下载、校验、重签名、安装过程中遇到问题，请：

1. **先查阅本文档**：大多数常见问题都有对应的解决方案
2. **查看流水线日志**：确认构建是否成功，制品是否正常生成
3. **校验文件完整性**：使用 SHA256 确认文件没有损坏
4. **提交 Issue**：如问题无法解决，在 GitHub 仓库提交 Issue 描述详细情况
