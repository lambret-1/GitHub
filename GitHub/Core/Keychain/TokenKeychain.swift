import Security
import Foundation

final class TokenKeychain {
    static let shared = TokenKeychain()

    private let service = "com.github.client.token"
    private let account = "github-pat"

    private init() {}

    /// 清理用户粘贴的 Token，兼容裸 Token、"token xxx" 和 "Bearer xxx" 格式。
    static func normalizedToken(_ rawToken: String) -> String {
        var token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Bearer ", "bearer ", "token ", "Token "] {
            if token.hasPrefix(prefix) {
                token = String(token.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }
        return token
    }

    @discardableResult
    func saveToken(_ rawToken: String) -> Bool {
        let token = Self.normalizedToken(rawToken)
        guard !token.isEmpty, let data = token.data(using: .utf8) else {
            DebugLogger.authError("保存 Token 失败：Token 为空或无法编码")
            return false
        }

        let matchQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]

        let updateAttributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(matchQuery as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            DebugLogger.auth("Token 更新成功")
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            DebugLogger.authError("Token 更新失败 (状态码: \(updateStatus))")
            return false
        }

        var addQuery = matchQuery
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        let success = addStatus == errSecSuccess
        if success {
            DebugLogger.auth("Token 保存成功")
        } else if addStatus == errSecDuplicateItem {
            // 并发保存时，另一请求可能刚好创建了项目；改为更新现有项目。
            let retryStatus = SecItemUpdate(matchQuery as CFDictionary, updateAttributes as CFDictionary)
            if retryStatus == errSecSuccess {
                DebugLogger.auth("Token 并发更新成功")
                return true
            }
            DebugLogger.authError("Token 并发更新失败 (状态码: \(retryStatus))")
            return false
        } else {
            DebugLogger.authError("Token 保存失败 (状态码: \(addStatus))")
        }
        return success
    }

    func getToken() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var data: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &data)
        guard status == errSecSuccess,
              let tokenData = data as? Data,
              let rawToken = String(data: tokenData, encoding: .utf8) else {
            DebugLogger.auth("Token 读取失败或不存在 (状态码: \(status))")
            return nil
        }

        let token = Self.normalizedToken(rawToken)
        guard !token.isEmpty else {
            DebugLogger.authError("Keychain 中的 Token 为空")
            return nil
        }

        // 顺手迁移旧版本可能保存的带前缀 Token，确保所有请求拿到统一格式。
        if token != rawToken {
            _ = saveToken(token)
        }
        return token
    }

    @discardableResult
    func deleteToken() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess || status == errSecItemNotFound
        if success {
            DebugLogger.auth("Token 删除/清理完成")
        } else {
            DebugLogger.authError("Token 删除失败 (状态码: \(status))")
        }
        return success
    }

    var hasToken: Bool {
        guard let token = getToken() else { return false }
        return !token.isEmpty
    }
}
