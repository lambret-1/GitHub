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
        // 代码文件 - 使用代码括号图标
        case "swift", "js", "jsx", "mjs", "ts", "tsx", "py", "java", "kt", "kts", "go", "rs", "cpp", "cc", "cxx", "c", "h", "m", "mm", "rb", "php", "dart", "vue":
            return "chevron.left.forwardslash.chevron.right"
        // 网页文件
        case "html", "htm":
            return "globe"
        // 样式文件
        case "css", "scss", "less":
            return "paintbrush"
        // Shell脚本
        case "sh", "bash", "zsh":
            return "terminal"
        // Markdown文件
        case "md", "markdown":
            return "text.alignleft"
        // JSON文件
        case "json":
            return "curlybraces"
        // XML/Plist文件
        case "xml", "plist":
            return "doc.text"
        // YAML文件
        case "yml", "yaml":
            return "doc.text"
        // 配置文件
        case "mobileconfig", "provisionprofile", "entitlements", "xcconfig", "pbxproj":
            return "gearshape"
        // 图片文件
        case "png", "jpg", "jpeg", "gif", "svg", "webp":
            return "photo"
        // PDF文件
        case "pdf":
            return "doc.richtext"
        // 压缩文件
        case "zip", "tar", "gz", "rar", "7z":
            return "doc.zipper"
        // 文本文件
        case "txt":
            return "doc.text"
        // Word文档
        case "doc", "docx":
            return "doc.text"
        // Excel表格
        case "xls", "xlsx", "csv":
            return "tablecells"
        // PPT演示
        case "ppt", "pptx":
            return "rectangle.on.rectangle"
        // 视频文件
        case "mp4", "mov", "avi", "mkv", "flv":
            return "film"
        // 音频文件
        case "mp3", "wav", "flac", "aac", "ogg":
            return "music.note"
        // 默认文档图标
        default:
            return "doc"
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

    /// 判断是否为图片文件
    var isImageFile: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "tif", "ico", "heic", "heif", "avif"]
        return imageExtensions.contains(fileExtension)
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
        // 先尝试带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: date) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            displayFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
            return displayFormatter.string(from: date)
        }
        // 再尝试不带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime]
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
        // 先尝试带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: date) {
            return calculateRelativeDate(from: date)
        }
        // 再尝试不带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: date) {
            return calculateRelativeDate(from: date)
        }
        // 解析失败返回格式化日期
        return formattedDate
    }

    // 计算相对时间差（核心逻辑：当前时间 - 提交时间）
    private func calculateRelativeDate(from date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 小于1分钟显示1分钟前
        if interval < 60 {
            return "1 分钟前"
        }
        // 小于1小时显示x分钟前
        else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        }
        // 小于1天显示x小时前
        else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        }
        // 小于1年显示x天前
        else if interval < 31536000 {
            return "\(Int(interval / 86400)) 天前"
        }
        // 大于等于1年显示x年前
        else {
            return "\(Int(interval / 31536000)) 年前"
        }
    }
}
