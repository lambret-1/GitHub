import Foundation

// ==============================================================================
// AppVersion 应用版本信息工具类
// 功能：读取当前版本号、构建号、检查GitHub Releases最新版本
// ==============================================================================

struct AppVersion {
    // MARK: - 当前版本信息

    /// 应用版本号（CFBundleShortVersionString）
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    /// 构建号（CFBundleVersion）
    static var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }

    /// 应用名称
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "GitHub"
    }

    /// 完整版本描述（如 "v1.1.1 (1)"）
    static var fullVersionDescription: String {
        "v\(currentVersion) (\(buildNumber))"
    }

    // MARK: - GitHub Release 信息

    /// GitHub Release 信息模型
    struct ReleaseInfo: Decodable {
        let tagName: String
        let name: String?
        let body: String?
        let htmlUrl: String
        let publishedAt: String
        let assets: [ReleaseAsset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case htmlUrl = "html_url"
            case publishedAt = "published_at"
            case assets
        }
    }

    /// Release 附件信息
    struct ReleaseAsset: Decodable {
        let name: String
        let size: Int
        let downloadCount: Int
        let url: String           // API端点URL（直接返回文件内容，需要认证）
        let browserDownloadUrl: String  // 浏览器下载URL（公开访问，需要重定向）

        enum CodingKeys: String, CodingKey {
            case name
            case size
            case downloadCount = "download_count"
            case url
            case browserDownloadUrl = "browser_download_url"
        }
    }

    /// 检查更新结果
    enum UpdateCheckResult {
        case upToDate          // 已是最新版本
        case updateAvailable(ReleaseInfo)  // 有新版本
        case checkFailed(Error) // 检查失败
    }

    // MARK: - 检查更新

    /// 检查GitHub最新Release版本
    /// - Parameters:
    ///   - owner: 仓库所有者
    ///   - repo: 仓库名称
    ///   - token: 访问令牌（可选，默认从Keychain获取）
    ///   - completion: 完成回调
    static func checkForUpdates(
        owner: String = "lambret-1",
        repo: String = "GitHub",
        token: String? = nil,
        completion: @escaping (UpdateCheckResult) -> Void
    ) {
        let urlString = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: urlString) else {
            completion(.checkFailed(NSError(domain: "AppVersion", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("GitHub-iOS-Client", forHTTPHeaderField: "User-Agent")

        // 优先使用传入的token，否则从Keychain获取
        // 私有仓库必须有正确的token才能访问Release API
        let authToken = token ?? TokenKeychain.shared.getToken()
        if let authToken = authToken, !authToken.isEmpty {
            request.setValue("token \(authToken)", forHTTPHeaderField: "Authorization")
        } else {
            // 没有token，私有仓库会返回404
            completion(.checkFailed(NSError(domain: "AppVersion", code: -3, userInfo: [NSLocalizedDescriptionKey: "未获取到登录令牌，无法访问私有仓库"])))
            return
        }

        request.timeoutInterval = 15

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.checkFailed(error))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.checkFailed(NSError(domain: "AppVersion", code: -2, userInfo: [NSLocalizedDescriptionKey: "服务器响应异常"])))
                    return
                }

                // 检查HTTP状态码
                guard httpResponse.statusCode == 200 else {
                    var errorMessage = "服务器返回错误 \(httpResponse.statusCode)"
                    if httpResponse.statusCode == 404 {
                        errorMessage = "未找到Release（可能是私有仓库认证失败或仓库不存在）"
                    } else if httpResponse.statusCode == 401 {
                        errorMessage = "登录令牌已过期，请重新登录"
                    } else if httpResponse.statusCode == 403 {
                        errorMessage = "访问被拒绝（可能是API速率限制）"
                    }
                    completion(.checkFailed(NSError(domain: "AppVersion", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                    return
                }

                guard let data = data else {
                    completion(.checkFailed(NSError(domain: "AppVersion", code: -4, userInfo: [NSLocalizedDescriptionKey: "服务器返回数据为空"])))
                    return
                }

                do {
                    let release = try JSONDecoder().decode(ReleaseInfo.self, from: data)
                    let latestVersion = extractVersion(from: release.tagName)

                    if isNewerVersion(latest: latestVersion, current: currentVersion) {
                        completion(.updateAvailable(release))
                    } else {
                        completion(.upToDate)
                    }
                } catch {
                    completion(.checkFailed(error))
                }
            }
        }.resume()
    }

    // MARK: - 版本比较

    /// 从tag名中提取版本号（如 "v1.1.1" -> "1.1.1"）
    private static func extractVersion(from tag: String) -> String {
        var version = tag
        if version.hasPrefix("v") {
            version = String(version.dropFirst())
        }
        return version
    }

    /// 比较两个版本号，判断latest是否比current新
    /// - Parameters:
    ///   - latest: 最新版本号
    ///   - current: 当前版本号
    /// - Returns: latest是否比current新
    static func isNewerVersion(latest: String, current: String) -> Bool {
        let latestParts = latest.split(separator: ".").compactMap { Int($0) }
        let currentParts = current.split(separator: ".").compactMap { Int($0) }

        let maxLength = max(latestParts.count, currentParts.count)

        for i in 0..<maxLength {
            let latestNum = i < latestParts.count ? latestParts[i] : 0
            let currentNum = i < currentParts.count ? currentParts[i] : 0

            if latestNum > currentNum {
                return true
            } else if latestNum < currentNum {
                return false
            }
        }

        return false
    }
}
