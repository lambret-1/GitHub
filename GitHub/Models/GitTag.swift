//
//  GitTag.swift
//  GitHub
//
//  用途：Git 标签数据模型
//  对应 GitHub API：GET /repos/{owner}/{repo}/tags
//

import Foundation

/// Git 标签模型
struct GitTag: Codable, Identifiable {
    /// 标签名称（如 "v1.2.3"）
    let name: String

    /// 标签指向的提交信息
    let commit: TagCommit

    /// Identifiable 唯一标识（用标签名）
    var id: String { name }

    /// 标签指向的提交
    struct TagCommit: Codable {
        /// 提交 SHA
        let sha: String
    }

    /// 提交短码（前7位）
    var 短码: String {
        String(commit.sha.prefix(7))
    }
}
