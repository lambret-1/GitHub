import Foundation

// ==============================================================================
// LanguageDetector 语言检测器
// 功能：根据文件扩展名、Shebang、文件名检测编程语言
// 位置：语法高亮系统的语言检测层
// ==============================================================================

class LanguageDetector {
    static let shared = LanguageDetector()

    private init() {}

    // MARK: - 公共检测方法

    /// 检测文件的编程语言
    /// - Parameters:
    ///   - fileName: 文件名（包含扩展名）
    ///   - fileContent: 文件内容（可选，用于Shebang检测）
    /// - Returns: 检测到的编程语言
    func detectLanguage(fileName: String, fileContent: String? = nil) -> ProgrammingLanguage {
        // 1. 优先通过Shebang检测（脚本文件）
        if let content = fileContent, let shebangLanguage = detectFromShebang(content) {
            return shebangLanguage
        }

        // 2. 通过文件扩展名检测
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        if let language = detectFromExtension(fileExtension) {
            return language
        }

        // 3. 通过特殊文件名检测（如 Makefile、Dockerfile）
        if let language = detectFromSpecialFileName(fileName) {
            return language
        }

        // 4. 兜底返回纯文本
        return .plainText
    }

    /// 检测文件扩展名对应的编程语言
    /// - Parameter fileExtension: 文件扩展名（小写，不含点）
    /// - Returns: 对应的编程语言，如果未找到返回nil
    func detectFromExtension(_ fileExtension: String) -> ProgrammingLanguage? {
        for language in ProgrammingLanguage.allCases {
            if language.extensions.contains(fileExtension) {
                return language
            }
        }
        return nil
    }

    // MARK: - Shebang检测

    /// 从Shebang行检测脚本语言
    /// - Parameter content: 文件内容
    /// - Returns: 检测到的编程语言，如果不是脚本文件返回nil
    private func detectFromShebang(_ content: String) -> ProgrammingLanguage? {
        // 读取第一行
        let lines = content.components(separatedBy: .newlines)
        guard let firstLine = lines.first, firstLine.hasPrefix("#!") else {
            return nil
        }

        // 常见Shebang模式
        let shebangPatterns: [(String, ProgrammingLanguage)] = [
            ("python", .python),
            ("python3", .python),
            ("python2", .python),
            ("node", .javascript),
            ("bash", .shell),
            ("sh", .shell),
            ("zsh", .shell),
            ("fish", .shell),
            ("ruby", .ruby),
            ("php", .php),
            ("perl", .plainText),
            ("lua", .lua),
            ("Rscript", .r),
            ("deno", .typescript),
            ("bun", .javascript)
        ]

        for (pattern, language) in shebangPatterns {
            if firstLine.contains(pattern) {
                return language
            }
        }

        return nil
    }

    // MARK: - 特殊文件名检测

    /// 从特殊文件名检测语言
    /// - Parameter fileName: 文件名
    /// - Returns: 检测到的编程语言，如果不是特殊文件返回nil
    private func detectFromSpecialFileName(_ fileName: String) -> ProgrammingLanguage? {
        let lowercasedName = fileName.lowercased()

        let specialFiles: [(String, ProgrammingLanguage)] = [
            ("makefile", .shell),
            ("dockerfile", .shell),
            ("gemfile", .ruby),
            ("podfile", .ruby),
            ("rakefile", .ruby),
            ("gruntfile", .javascript),
            ("gulpfile", .javascript),
            ("webpack.config", .javascript),
            ("babel.config", .javascript),
            ("jest.config", .javascript),
            ("tsconfig", .json),
            ("jsconfig", .json),
            ("package.json", .json),
            ("composer.json", .json),
            ("cargo.toml", .yaml),
            ("go.mod", .plainText),
            ("go.sum", .plainText),
            ("requirements.txt", .plainText),
            ("pipfile", .yaml),
            ("CMakeLists.txt", .plainText),
            ("Podfile.lock", .plainText),
            ("package-lock.json", .json),
            ("yarn.lock", .plainText),
            ("pnpm-lock.yaml", .yaml)
        ]

        for (pattern, language) in specialFiles {
            if lowercasedName == pattern || lowercasedName.hasPrefix(pattern) {
                return language
            }
        }

        return nil
    }

    // MARK: - 支持的扩展名列表

    /// 获取所有支持的文件扩展名
    /// - Returns: 扩展名列表
    func allSupportedExtensions() -> [String] {
        var extensions: Set<String> = []
        for language in ProgrammingLanguage.allCases {
            for ext in language.extensions {
                extensions.insert(ext)
            }
        }
        return Array(extensions).sorted()
    }

    /// 检查文件是否支持语法高亮
    /// - Parameter fileName: 文件名
    /// - Returns: 是否支持
    func isSupported(fileName: String) -> Bool {
        let language = detectLanguage(fileName: fileName)
        return language != .plainText
    }
}
