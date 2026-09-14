import Foundation

// ==============================================================================
// JavaScriptTokenizer JavaScript/TypeScript语言词法分析器
// 功能：对JS/TS代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class JavaScriptTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - JS/TS关键字

    private static let keywords: Set<String> = [
        "const", "let", "var", "function", "return", "if", "else", "for", "while",
        "do", "switch", "case", "break", "continue", "try", "catch", "finally", "throw",
        "new", "delete", "typeof", "instanceof", "in", "of", "class", "extends", "super",
        "this", "import", "export", "from", "default", "async", "await", "yield", "void",
        "null", "undefined", "true", "false", "NaN", "Infinity", "static", "get", "set",
        "public", "private", "protected", "readonly", "abstract", "implements", "interface",
        "enum", "namespace", "module", "declare", "type", "as", "is", "keyof", "infer",
        "never", "unknown", "any", "string", "number", "boolean", "object", "symbol",
        "bigint", "satisfies", "using", "await"
    ]

    // MARK: - 内置对象和函数

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
        "location", "history", "screen", "performance", "crypto", "customElements",
        "parseInt", "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
        "encodeURIComponent", "decodeURIComponent", "escape", "unescape", "eval",
        "Function", "Generator", "GeneratorFunction", "AsyncFunction", "AsyncGenerator",
        "AsyncGeneratorFunction", "Reflect", "FinalizationRegistry", "WeakRef"
    ]

    // MARK: - 初始化

    override init() {
        super.init(language: .javascript)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            let start = index

            // 跳过空白字符
            if char.isWhitespace {
                index = text.index(after: index)
                continue
            }

            // 单行注释 //
            if char == "/" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "/" {
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 多行注释 /* */
            if char == "/" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "*" {
                let _ = readBlockComment(text, index: &index, endSymbol: "*/")
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 字符串
            if char == "\"" || char == "'" {
                let _ = readString(text, index: &index, quote: char)
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 模板字符串 `
            if char == "`" {
                let _ = readTemplateString(text, index: &index)
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 装饰器 @ (TypeScript)
            if char == "@" {
                let _ = readDecorator(text, index: &index)
                tokens.append(makeToken(type: .decorator, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let identifier = readIdentifier(text, index: &index)

                // 关键字
                if JavaScriptTokenizer.keywords.contains(identifier) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 内置对象
                if JavaScriptTokenizer.builtins.contains(identifier) {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 类名/类型（大写开头）
                if let firstChar = identifier.first, firstChar.isUppercase {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 普通变量名
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 正则表达式（简单检测：/开头，后面不是注释）
            // 为了简化，这里不做正则表达式的精确识别

            // 运算符
            if isOperator(char) {
                let _ = readOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 私有方法

    private func makeToken(type: SyntaxTokenType, text: String, start: String.Index, end: String.Index) -> SyntaxToken {
        let nsRange = NSRange(start..<end, in: text)
        let tokenText = String(text[start..<end])
        return SyntaxToken(type: type, range: nsRange, text: tokenText)
    }

    private func readTemplateString(_ text: String, index: inout String.Index) -> String {
        let start = index
        index = text.index(after: index) // 跳过 `

        while index < text.endIndex {
            let char = text[index]
            if char == "\\" {
                index = text.index(after: index)
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                continue
            }
            if char == "`" {
                index = text.index(after: index)
                break
            }
            // 模板字符串中的 ${...} 表达式
            if char == "$" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "{" {
                // 跳过 ${...} 表达式（简单实现：找到匹配的 }）
                var depth = 1
                index = text.index(index, offsetBy: 2)
                while index < text.endIndex && depth > 0 {
                    if text[index] == "{" { depth += 1 }
                    if text[index] == "}" { depth -= 1 }
                    index = text.index(after: index)
                }
                continue
            }
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    private func readDecorator(_ text: String, index: inout String.Index) -> String {
        let start = index
        index = text.index(after: index)
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    private func isOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ",", ";", ".", "(", ")", "[", "]", "{", "}"]
        return operators.contains(char)
    }

    private func readOperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isOperator(text[index]) {
            if text[index] == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber {
                break
            }
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
