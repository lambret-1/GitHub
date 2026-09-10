import Foundation

// MARK: - 镜像加速 URLSession（允许无效证书）

/// 自定义 URLSessionDelegate，用于允许镜像站点的无效证书
/// 注意：仅用于镜像加速的请求，不用于 API 请求（API 请求使用官方服务器，证书有效）
class MirrorURLSessionDelegate: NSObject, URLSessionDelegate {
    static let shared = MirrorURLSessionDelegate()

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        // 允许所有证书（包括无效证书）
        // 仅用于镜像加速的文件下载、HTML预览等公开资源
        // API 请求始终使用官方 GitHub 服务器，证书有效，不需要此处理
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let credential = URLCredential(trust: serverTrust)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

/// 镜像加速专用 URLSession，允许无效证书
/// 用于文件下载、HTML预览、头像加载等公开资源的镜像加速请求
extension URLSession {
    static let mirrorSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration, delegate: MirrorURLSessionDelegate.shared, delegateQueue: .main)
    }()
}
