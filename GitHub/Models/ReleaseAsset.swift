//
//  ReleaseAsset.swift
//  GitHub
//
//  用途：GitHub Release 资产文件数据模型
//  对应 GitHub API：GET /repos/{owner}/{repo}/releases/tags/{tag} 返回的 assets 数组
//

import Foundation

/// GitHub Release 资产文件模型
struct ReleaseAsset: Codable, Identifiable {
    /// 资产唯一ID
    let id: Int

    /// 文件名（如 "App-v1.0.0.ipa"）
    let name: String

    /// 文件大小（字节）
    let size: Int

    /// 下载次数
    let downloadCount: Int?

    /// 浏览器下载地址
    let browserDownloadUrl: String

    /// MIME 类型
    let contentType: String?

    /// 创建时间
    let createdAt: String?

    /// 更新时间
    let updatedAt: String?

    /// 格式化文件大小（人类可读）
    var 格式化大小: String {
        let 字节数 = Double(size)
        if 字节数 < 1024 {
            return "\(size) B"
        } else if 字节数 < 1024 * 1024 {
            return String(format: "%.1f KB", 字节数 / 1024)
        } else if 字节数 < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", 字节数 / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", 字节数 / (1024 * 1024 * 1024))
        }
    }

    /// 文件扩展名
    var 文件扩展名: String {
        (name as NSString).pathExtension.lowercased()
    }

    /// 是否为源代码包（zip或tar.gz）
    var 是源代码包: Bool {
        文件扩展名 == "zip" || name.hasSuffix(".tar.gz") || name.hasSuffix(".tgz")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case size
        case downloadCount = "download_count"
        case browserDownloadUrl = "browser_download_url"
        case contentType = "content_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// GitHub Release 模型（仅包含标签下载所需字段）
struct ReleaseInfo: Codable {
    /// Release ID
    let id: Int?

    /// Release 名称
    let name: String?

    /// 标签名
    let tagName: String

    /// 资产文件列表
    let assets: [ReleaseAsset]?

    /// 是否为草稿
    let draft: Bool?

    /// 是否为预发布
    let prerelease: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagName = "tag_name"
        case assets
        case draft
        case prerelease
    }
}
