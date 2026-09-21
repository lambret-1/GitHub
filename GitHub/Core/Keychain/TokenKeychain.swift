import Security
import Foundation

class TokenKeychain {
    static let shared = TokenKeychain()
    private let service = "com.github.client.token"
    private let account = "github-pat"
    
    private init() {}
    
    @discardableResult
    func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else {
            DebugLogger.authError("保存Token失败：无法转换为Data")
            return false
        }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        let success = status == errSecSuccess
        if success {
            DebugLogger.auth("Token保存成功 (长度: \(token.count))")
        } else {
            DebugLogger.authError("Token保存失败 (状态码: \(status))")
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

        if status == errSecSuccess, let tokenData = data as? Data {
            let token = String(data: tokenData, encoding: .utf8)
            DebugLogger.auth("Token读取成功 (长度: \(token?.count ?? 0))")
            return token
        }
        DebugLogger.auth("Token读取失败或不存在 (状态码: \(status))")
        return nil
    }

    @discardableResult
    func deleteToken() -> Bool {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        let success = status == errSecSuccess
        if success {
            DebugLogger.auth("Token删除成功")
        } else {
            DebugLogger.authError("Token删除失败 (状态码: \(status))")
        }
        return success
    }
    
    var hasToken: Bool {
        return getToken() != nil
    }
}
