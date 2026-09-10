# 钥匙串管理目录

本目录存放钥匙串（Keychain）相关的管理类，用于安全存储用户 Token 等敏感信息。

## 文件说明

### TokenKeychain.swift
**Token 钥匙串管理类**

**功能参数说明：**

| 参数/方法 | 中文释义 | 说明 |
|-----------|---------|------|
| `service` | 服务标识符 | Keychain 服务名称，用于区分不同应用的存储项 |
| `account` | 账户标识符 | Keychain 账户名称，用于标识存储的 Token |
| `saveToken(_:)` | 保存 Token | 将用户的 GitHub Personal Access Token 安全存储到 Keychain |
| `getToken()` | 获取 Token | 从 Keychain 中读取存储的 Token，不存在时返回 nil |
| `deleteToken()` | 删除 Token | 从 Keychain 中删除存储的 Token，用于退出登录 |
| `kSecClass` | 安全项目类 | Keychain 项目类型，使用通用密码（kSecClassGenericPassword） |
| `kSecAttrService` | 服务属性 | Keychain 服务属性键 |
| `kSecAttrAccount` | 账户属性 | Keychain 账户属性键 |
| `kSecValueData` | 值数据 | Keychain 存储值的数据键 |
| `kSecMatchLimit` | 匹配限制 | 查询结果数量限制，使用 kSecMatchLimitOne |
| `kSecReturnData` | 返回数据 | 查询时是否返回数据值 |

**安全特性：**
- 使用 iOS 系统 Keychain 安全存储
- Token 以加密形式存储在设备安全区域
- 应用卸载后 Keychain 数据自动清除
- 支持生物识别（Face ID/Touch ID）访问控制（可配置）

**使用方法：**
```swift
// 保存 Token
TokenKeychain.shared.saveToken("ghp_xxxxxxxxxxxx")

// 获取 Token
let token = TokenKeychain.shared.getToken()

// 删除 Token
TokenKeychain.shared.deleteToken()
```

---

## 安全规范

1. Token 等敏感信息必须存储在 Keychain 中
2. 禁止将 Token 打印到日志或控制台
3. 禁止将 Token 存储在 UserDefaults 或文件中
4. Token 传输必须使用 HTTPS
5. 退出登录时必须调用 deleteToken() 清除 Token
6. 多账号场景下需为每个账号使用不同的 account 标识符
