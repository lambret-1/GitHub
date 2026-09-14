import UIKit

// ==============================================================================
// SyntaxHighlighter 语法高亮器（入口门面）
// 功能：对代码文本进行语法高亮，自动检测语言，调用对应Tokenizer
// 架构：门面模式，统一入口，内部调度各语言Tokenizer
// 位置：语法高亮系统的入口层
// ==============================================================================

class SyntaxHighlighter {
    // MARK: - 共享实例

    static let shared = SyntaxHighlighter()

    private init() {}

    // MARK: - Tokenizer缓存

    private var tokenizerCache: [ProgrammingLanguage: LanguageTokenizer] = [:]

    // MARK: - 公共高亮方法

    /// 对文本进行语法高亮（自动检测语言）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    ///   - fileName: 文件名（用于语言检测）
    ///   - theme: 语法主题（nil则自动根据系统外观选择）
    /// - Returns: 带语法高亮的NSAttributedString
    static func highlight(
        _ text: String,
        font: UIFont,
        fileName: String = "",
        theme: SyntaxTheme? = nil
    ) -> NSAttributedString {
        return shared.highlight(text, font: font, fileName: fileName, theme: theme)
    }

    /// 对文本进行语法高亮（指定语言）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    ///   - language: 编程语言
    ///   - theme: 语法主题（nil则自动根据系统外观选择）
    /// - Returns: 带语法高亮的NSAttributedString
    static func highlight(
        _ text: String,
        font: UIFont,
        language: ProgrammingLanguage,
        theme: SyntaxTheme? = nil
    ) -> NSAttributedString {
        return shared.highlight(text, font: font, language: language, theme: theme)
    }

    // MARK: - 实例方法

    private func highlight(
        _ text: String,
        font: UIFont,
        fileName: String,
        theme: SyntaxTheme?
    ) -> NSAttributedString {
        // 1. 检测语言
        let language = LanguageDetector.shared.detectLanguage(fileName: fileName, fileContent: text)

        // 2. 使用检测到的语言进行高亮
        return highlight(text, font: font, language: language, theme: theme)
    }

    private func highlight(
        _ text: String,
        font: UIFont,
        language: ProgrammingLanguage,
        theme: SyntaxTheme?
    ) -> NSAttributedString {
        // 1. 获取主题
        let syntaxTheme = theme ?? ThemeManager.shared.currentTheme

        // 2. 获取Tokenizer
        let tokenizer = getTokenizer(for: language)

        // 3. 词法分析
        let tokens = tokenizer.tokenize(text)

        // 4. 应用高亮
        return HighlightEngine.shared.applyHighlight(
            text: text,
            tokens: tokens,
            font: font,
            theme: syntaxTheme
        )
    }

    // MARK: - Tokenizer获取与缓存

    /// 获取指定语言的Tokenizer（带缓存）
    /// - Parameter language: 编程语言
    /// - Returns: 对应的Tokenizer
    private func getTokenizer(for language: ProgrammingLanguage) -> LanguageTokenizer {
        // 检查缓存
        if let cached = tokenizerCache[language] {
            return cached
        }

        // 创建新的Tokenizer
        let tokenizer: LanguageTokenizer
        switch language {
        case .swift:
            tokenizer = SwiftTokenizer()
        case .python:
            tokenizer = PythonTokenizer()
        case .javascript, .typescript:
            tokenizer = JavaScriptTokenizer()
        case .markdown:
            tokenizer = MarkdownTokenizer()
        default:
            // 其他语言暂时使用纯文本Tokenizer兜底
            tokenizer = PlainTextTokenizer()
        }

        // 缓存
        tokenizerCache[language] = tokenizer
        return tokenizer
    }

    // MARK: - 语言检测

    /// 检测文件的编程语言
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - fileContent: 文件内容（可选）
    /// - Returns: 检测到的编程语言
    static func detectLanguage(fileName: String, fileContent: String? = nil) -> ProgrammingLanguage {
        return LanguageDetector.shared.detectLanguage(fileName: fileName, fileContent: fileContent)
    }

    // MARK: - 主题获取

    /// 获取当前主题
    static var currentTheme: SyntaxTheme {
        return ThemeManager.shared.currentTheme
    }

    /// 获取指定外观模式的主题
    static func theme(for style: UIUserInterfaceStyle) -> SyntaxTheme {
        return ThemeManager.shared.theme(for: style)
    }

    // MARK: - 清除缓存

    /// 清除Tokenizer缓存（内存不足时调用）
    func clearCache() {
        tokenizerCache.removeAll()
    }
}

// MARK: - 向后兼容（旧API）

extension SyntaxHighlighter {
    /// 旧版高亮方法（向后兼容）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    /// - Returns: 带语法高亮的NSAttributedString
    @available(*, deprecated, message: "请使用 highlight(_:font:fileName:theme:) 方法")
    static func highlight(_ text: String, font: UIFont) -> NSAttributedString {
        return highlight(text, font: font, fileName: "")
    }
}
