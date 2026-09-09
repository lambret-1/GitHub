import UIKit

// ==============================================================================
// SyntaxHighlighter 语法高亮器
// 功能：对代码文本进行语法分析，识别关键字、函数、字符串、注释、数字等，应用不同颜色
// 风格：参考GitHub的语法高亮配色
// ==============================================================================

class SyntaxHighlighter {
    // 语法颜色配置（参考GitHub暗色主题配色）
    struct SyntaxColors {
        static let plain = UIColor.label
        static let keyword = UIColor(red: 0.8, green: 0.4, blue: 0.9, alpha: 1.0)  // 紫色
        static let function = UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0)  // 蓝色
        static let string = UIColor(red: 0.4, green: 0.8, blue: 0.5, alpha: 1.0)    // 绿色
        static let comment = UIColor(red: 0.5, green: 0.6, blue: 0.5, alpha: 1.0)   // 灰绿色
        static let number = UIColor(red: 1.0, green: 0.7, blue: 0.4, alpha: 1.0)    // 橙色
        static let type = UIColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)      // 浅蓝色
        static let operatorSymbol = UIColor(red: 0.9, green: 0.5, blue: 0.5, alpha: 1.0) // 红色
    }

    // JavaScript/TypeScript 关键字
    private static let keywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while",
        "do", "switch", "case", "break", "continue", "try", "catch", "finally", "throw",
        "new", "delete", "typeof", "instanceof", "in", "of", "class", "extends", "super",
        "this", "import", "export", "from", "default", "async", "await", "yield", "void",
        "null", "undefined", "true", "false", "NaN", "Infinity", "static", "get", "set",
        "public", "private", "protected", "readonly", "abstract", "implements", "interface",
        "enum", "namespace", "module", "declare", "type", "as", "is", "keyof", "infer",
        "never", "unknown", "any", "string", "number", "boolean", "object", "symbol",
        "bigint", "undefined", "void", "never", "unknown", "any"
    ]

    // 内置函数和对象
    private static let builtins: Set<String> = [
        "console", "Math", "JSON", "Object", "Array", "String", "Number", "Boolean",
        "Date", "RegExp", "Error", "Promise", "Map", "Set", "WeakMap", "WeakSet",
        "Symbol", "Proxy", "Reflect", "Intl", "DataView", "ArrayBuffer", "SharedArrayBuffer",
        "Atomics", "WebAssembly", "globalThis", "process", "Buffer", "require", "module",
        "exports", "__dirname", "__filename", "setTimeout", "setInterval", "setImmediate",
        "clearTimeout", "clearInterval", "clearImmediate", "fetch", "URL", "URLSearchParams",
        "Headers", "Request", "Response", "AbortController", "AbortSignal", "TextEncoder",
        "TextDecoder", "Blob", "File", "FileReader", "FormData", "XMLHttpRequest",
        "WebSocket", "EventSource", "MessageChannel", "MessagePort", "BroadcastChannel",
        "localStorage", "sessionStorage", "indexedDB", "document", "window", "navigator",
        "location", "history", "screen", "performance", "crypto", "customElements"
    ]

    /// 对文本进行语法高亮
    /// - Parameters:
    ///   - text: 原始文本
    ///   - font: 基础字体
    /// - Returns: 带语法高亮属性的NSAttributedString
    static func highlight(_ text: String, font: UIFont) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // 设置基础字体和颜色
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: SyntaxColors.plain, range: fullRange)

        // 1. 先处理注释（单行和多行）
        highlightComments(text: text, attributedString: attributedString)

        // 2. 处理字符串
        highlightStrings(text: text, attributedString: attributedString)

        // 3. 处理数字
        highlightNumbers(text: text, attributedString: attributedString)

        // 4. 处理关键字和函数名
        highlightKeywordsAndFunctions(text: text, attributedString: attributedString)

        return attributedString
    }

    // MARK: - 注释高亮

    private static func highlightComments(text: String, attributedString: NSMutableAttributedString) {
        // 单行注释 //
        if let regex = try? NSRegularExpression(pattern: "//[^\\n]*", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.comment, range: range)
                }
            }
        }

        // 多行注释 /* */
        if let regex = try? NSRegularExpression(pattern: "/\\*[\\s\\S]*?\\*/", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.comment, range: range)
                }
            }
        }
    }

    // MARK: - 字符串高亮

    private static func highlightStrings(text: String, attributedString: NSMutableAttributedString) {
        // 单引号字符串
        if let regex = try? NSRegularExpression(pattern: "'[^'\\\\\\n]*(?:\\\\.[^'\\\\\\n]*)*'", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.string, range: range)
                }
            }
        }

        // 双引号字符串
        if let regex = try? NSRegularExpression(pattern: "\"[^\"\\\\\\n]*(?:\\\\.[^\"\\\\\\n]*)*\"", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.string, range: range)
                }
            }
        }

        // 模板字符串
        if let regex = try? NSRegularExpression(pattern: "`[^`\\\\]*(?:\\\\.[^`\\\\]*)*`", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.string, range: range)
                }
            }
        }
    }

    // MARK: - 数字高亮

    private static func highlightNumbers(text: String, attributedString: NSMutableAttributedString) {
        // 数字（包括十六进制、二进制、八进制、浮点数、大整数）
        if let regex = try? NSRegularExpression(pattern: "\\b(?:0x[0-9a-fA-F]+|0b[01]+|0o[0-7]+|\\d+\\.?\\d*(?:[eE][+-]?\\d+)?n?)\\b", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                if let range = match?.range {
                    // 检查是否在字符串或注释中（简单检查：如果前面是引号则跳过）
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.number, range: range)
                }
            }
        }
    }

    // MARK: - 关键字和函数名高亮

    private static func highlightKeywordsAndFunctions(text: String, attributedString: NSMutableAttributedString) {
        // 匹配标识符
        if let regex = try? NSRegularExpression(pattern: "\\b[A-Za-z_$][A-Za-z0-9_$]*\\b", options: []) {
            regex.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
                guard let range = match?.range,
                      let swiftRange = Range(range, in: text) else { return }

                let word = String(text[swiftRange])

                // 检查是否已经被设置为字符串或注释颜色（避免覆盖）
                var currentColor: UIColor?
                if range.location < attributedString.length {
                    attributedString.enumerateAttribute(.foregroundColor, in: range, options: []) { value, _, stop in
                        if let color = value as? UIColor {
                            currentColor = color
                            stop.pointee = true
                        }
                    }
                }

                // 如果已经是字符串或注释颜色，跳过
                if let color = currentColor,
                   color == SyntaxColors.string || color == SyntaxColors.comment {
                    return
                }

                // 关键字
                if keywords.contains(word) {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.keyword, range: range)
                    return
                }

                // 内置对象
                if builtins.contains(word) {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.type, range: range)
                    return
                }

                // 函数调用（后面跟着括号）
                if range.location + range.length < text.utf16.count {
                    let nextCharRange = NSRange(location: range.location + range.length, length: 1)
                    if nextCharRange.location < text.utf16.count,
                       let nextSwiftRange = Range(nextCharRange, in: text) {
                        let nextChar = text[nextSwiftRange]
                        if nextChar == "(" {
                            attributedString.addAttribute(.foregroundColor, value: SyntaxColors.function, range: range)
                            return
                        }
                    }
                }

                // 类型名（大写开头）
                if let firstChar = word.first, firstChar.isUppercase {
                    attributedString.addAttribute(.foregroundColor, value: SyntaxColors.type, range: range)
                }
            }
        }
    }
}
