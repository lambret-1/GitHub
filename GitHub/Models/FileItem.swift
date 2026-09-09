import Foundation

struct FileItem: Codable, Identifiable {
    let name: String
    let path: String
    let sha: String
    let size: Int?
    let type: String
    let downloadUrl: String?
    let htmlUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, type
        case downloadUrl = "download_url"
        case htmlUrl = "html_url"
    }
    
    var id: String { sha }
    
    var isDirectory: Bool {
        return type == "dir"
    }
    
    var isFile: Bool {
        return type == "file"
    }
    
    var fileExtension: String {
        return (name as NSString).pathExtension.lowercased()
    }
    
    var iconName: String {
        if isDirectory {
            return "folder.fill"
        }
        return iconForFileExtension(fileExtension)
    }
    
    var formattedSize: String {
        guard let size = size else { return "-" }
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024 * 1024))
        }
    }
    
    private func iconForFileExtension(_ ext: String) -> String {
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "mjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "java": return "java"
        case "kt", "kts": return "kotlin"
        case "go": return "go"
        case "rs": return "rust"
        case "cpp", "cc", "cxx": return "cplusplus"
        case "c", "h": return "c"
        case "m", "mm": return "objectivec"
        case "rb": return "ruby"
        case "php": return "php"
        case "html", "htm": return "html"
        case "css", "scss", "less": return "css"
        case "sh", "bash", "zsh": return "terminal"
        case "dart": return "dart"
        case "vue": return "vue"
        case "md", "markdown": return "markdown"
        case "json": return "json"
        case "xml", "plist": return "xml"
        case "yml", "yaml": return "yaml"
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return "photo"
        case "pdf": return "pdf"
        case "zip", "tar", "gz", "rar": return "archive"
        case "txt": return "text"
        default: return "doc"
        }
    }
}

struct FileContent: Codable {
    let name: String
    let path: String
    let sha: String
    let size: Int
    let type: String
    let content: String?
    let encoding: String?
    let downloadUrl: String?
    let htmlUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case name, path, sha, size, type, content, encoding
        case downloadUrl = "download_url"
        case htmlUrl = "html_url"
    }
    
    var decodedContent: String {
        guard let content = content, let encoding = encoding, encoding == "base64" else {
            return content ?? ""
        }
        let cleanedContent = content.replacingOccurrences(of: "\n", with: "")
        if let data = Data(base64Encoded: cleanedContent), let text = String(data: data, encoding: .utf8) {
            return text
        }
        return content
    }
    
    var fileExtension: String {
        return (name as NSString).pathExtension.lowercased()
    }
    
    var isTextFile: Bool {
        let textExtensions = ["txt", "md", "markdown", "swift", "js", "jsx", "ts", "tsx", "py", "java", "kt", "go", "rs", "cpp", "c", "h", "m", "mm", "rb", "php", "html", "htm", "css", "scss", "less", "sh", "bash", "zsh", "dart", "vue", "json", "xml", "plist", "yml", "yaml", "toml", "ini", "cfg", "conf", "log", "csv", "sql", "r", "scala", "clj", "ex", "exs", "erl", "hs", "lua", "pl", "pm", "rmd", "tex", "bib", "sty", "dockerfile", "makefile", "cmake", "gradle", "podfile", "cartfile", "package", "gemfile", "requirements", "pipfile", "lock", "env", "gitignore", "gitattributes", "editorconfig", "eslintrc", "prettierrc", "babelrc", "tsconfig", "jsconfig", "webpack", "rollup", "vite", "jest", "mocha", "karma", "protractor", "cypress", "playwright", "storybook", "readme", "changelog", "license", "contributing", "code_of_conduct", "security", "authors", "thanks", "acknowledgments", "notice", "third_party", "notices", "mobileconfig", "provisionprofile", "mobileprovision", "ics", "webarchive", "strings", "entitlements", "xcconfig", "pbxproj", "xcscheme", "xcworkspacedata", "storyboard", "xib", "intentdefinition", "metal", "shader", "glsl", "vert", "frag", "geom", "comp", "svg", "bat", "cmd", "ps1", "psm1", "psd1", "reg", "inf", "xcprivacy", "resign", "cert", "crt", "cer", "pem", "key", "csr", "p7b", "p7c", "p7m", "p7s", "p7r", "pkcs7", "pkcs8", "pkcs1", "der", "asn1", "p10", "crl", "ocsp", "spc", "sst", "stl", "ca-bundle", "ca-certificates", "truststore", "jks", "keystore", "p12", "pfx", "pvk", "pkcs12"]
        return textExtensions.contains(fileExtension) || fileExtension.isEmpty
    }
}

struct Branch: Codable, Identifiable {
    let name: String
    let commit: BranchCommit
    let protected: Bool
    
    var id: String { name }
}

struct BranchCommit: Codable {
    let sha: String
    let url: String
}

// MARK: - 文件大小格式化扩展

extension Int {
    var formattedFileSize: String {
        if self < 1024 {
            return "\(self) B"
        } else if self < 1024 * 1024 {
            return String(format: "%.1f KB", Double(self) / 1024)
        } else if self < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(self) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(self) / (1024 * 1024 * 1024))
        }
    }
}

// MARK: - 提交时间格式化扩展

extension CommitPerson {
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        return date
    }

    var relativeDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: date) else { return formattedDate }

        let now = Date()
        let interval = now.timeIntervalSince(date)

        if interval < 60 {
            return "刚刚"
        } else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        } else if interval < 2592000 {
            return "\(Int(interval / 86400)) 天前"
        } else {
            return formattedDate
        }
    }
}
