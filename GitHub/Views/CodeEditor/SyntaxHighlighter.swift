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
    func getTokenizer(for language: ProgrammingLanguage) -> LanguageTokenizer {
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
        case .javascript:
            tokenizer = JavaScriptTokenizer()
        case .typescript:
            tokenizer = TypeScriptTokenizer()
        case .markdown:
            tokenizer = MarkdownTokenizer()
        case .java:
            tokenizer = JavaTokenizer()
        case .go:
            tokenizer = GoTokenizer()
        case .c:
            tokenizer = CTokenizer()
        case .cpp:
            tokenizer = CppTokenizer()
        case .objectiveC:
            tokenizer = CppTokenizer() // Objective-C使用C++Tokenizer（语法相似）
        case .ruby:
            tokenizer = RubyTokenizer()
        case .php:
            tokenizer = PHPTokenizer()
        case .rust:
            tokenizer = RustTokenizer()
        case .kotlin:
            tokenizer = KotlinTokenizer()
        case .csharp:
            tokenizer = CppTokenizer() // C#使用C++Tokenizer（语法相似）
        case .scala:
            tokenizer = JavaTokenizer() // Scala使用JavaTokenizer（语法相似）
        case .dart:
            tokenizer = JavaTokenizer() // Dart使用JavaTokenizer（语法相似）
        case .lua:
            tokenizer = LuaTokenizer()
        case .r:
            tokenizer = RTokenizer()
        case .shell:
            tokenizer = ShellTokenizer()
        case .yaml:
            tokenizer = YAMLTokenizer()
        case .json:
            tokenizer = JSONTokenizer()
        case .xml:
            tokenizer = XMLTokenizer()
        case .html:
            tokenizer = HTMLTokenizer()
        case .css:
            tokenizer = CSSTokenizer()
        case .sql:
            tokenizer = SQLTokenizer()
        case .ini:
            tokenizer = INITokenizer()
        case .toml:
            tokenizer = TOMLTokenizer()
        case .plainText:
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

    // MARK: - 异步高亮（性能优化）

    /// 异步执行语法高亮（带缓存，后台线程执行）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    ///   - fileName: 文件名（用于语言检测）
    ///   - theme: 语法主题（nil则自动根据系统外观选择）
    ///   - completion: 完成回调（在主线程调用）
    /// - Returns: 任务ID（可用于取消）
    @discardableResult
    static func highlightAsync(
        _ text: String,
        font: UIFont,
        fileName: String = "",
        theme: SyntaxTheme? = nil,
        completion: @escaping (NSAttributedString) -> Void
    ) -> Int {
        // 检测语言
        let language = LanguageDetector.shared.detectLanguage(fileName: fileName, fileContent: text)
        let syntaxTheme = theme ?? ThemeManager.shared.currentTheme

        // 使用任务管理器异步执行
        return HighlightTaskManager.shared.highlightAsync(
            text: text,
            language: language,
            font: font,
            theme: syntaxTheme,
            completion: completion
        )
    }

    /// 异步执行语法高亮（指定语言，带缓存，后台线程执行）
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    ///   - language: 编程语言
    ///   - theme: 语法主题（nil则自动根据系统外观选择）
    ///   - completion: 完成回调（在主线程调用）
    /// - Returns: 任务ID（可用于取消）
    @discardableResult
    static func highlightAsync(
        _ text: String,
        font: UIFont,
        language: ProgrammingLanguage,
        theme: SyntaxTheme? = nil,
        completion: @escaping (NSAttributedString) -> Void
    ) -> Int {
        let syntaxTheme = theme ?? ThemeManager.shared.currentTheme

        // 使用任务管理器异步执行
        return HighlightTaskManager.shared.highlightAsync(
            text: text,
            language: language,
            font: font,
            theme: syntaxTheme,
            completion: completion
        )
    }

    /// 取消当前异步高亮任务
    static func cancelCurrentHighlight() {
        HighlightTaskManager.shared.cancelCurrent()
    }

    // MARK: - 缓存管理

    /// 清除所有高亮缓存
    static func clearHighlightCache() {
        HighlightCache.shared.clearAll()
    }

    /// 清除指定语言的高亮缓存
    static func clearHighlightCache(for language: ProgrammingLanguage) {
        HighlightCache.shared.clear(for: language)
    }

    /// 获取缓存统计信息
    static var cacheStats: (count: Int, memory: Int, hitRate: Double) {
        let stats = HighlightCache.shared.stats
        return (stats.count, stats.memory, HighlightCache.shared.hitRate)
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
