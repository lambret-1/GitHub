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
        let textExtensions = ["txt", "md", "markdown", "swift", "js", "jsx", "ts", "tsx", "py", "java", "kt", "go", "rs", "cpp", "c", "h", "m", "mm", "rb", "php", "html", "htm", "css", "scss", "less", "sh", "bash", "zsh", "dart", "vue", "json", "xml", "plist", "yml", "yaml", "toml", "ini", "cfg", "conf", "log", "csv", "sql", "r", "scala", "clj", "ex", "exs", "erl", "hs", "lua", "pl", "pm", "r", "rmd", "tex", "bib", "sty", "dockerfile", "makefile", "cmake", "gradle", "podfile", "cartfile", "package", "gemfile", "requirements", "pipfile", "lock", "env", "gitignore", "gitattributes", "editorconfig", "eslintrc", "prettierrc", "babelrc", "tsconfig", "jsconfig", "webpack", "rollup", "vite", "jest", "mocha", "karma", "protractor", "cypress", "playwright", "storybook", "readme", "changelog", "license", "contributing", "code_of_conduct", "security", "authors", "thanks", "acknowledgments", "notice", "third_party", "notices"]
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
