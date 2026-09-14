import Foundation

// ==============================================================================
// SwiftTokenizer Swift语言词法分析器
// 功能：对Swift代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class SwiftTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - Swift关键字

    private static let keywords: Set<String> = [
        // 声明关键字
        "class", "struct", "enum", "protocol", "extension", "func", "var", "let",
        "typealias", "associatedtype", "subscript", "operator", "precedencegroup",
        "import", "init", "deinit", "defer",
        // 控制流关键字
        "if", "else", "guard", "switch", "case", "default", "for", "in", "while",
        "repeat", "break", "continue", "fallthrough", "return", "throw", "throws",
        "rethrows", "try", "catch", "do",
        // 表达式和类型关键字
        "as", "is", "super", "self", "Self", "Type", "Protocol", "nil", "true",
        "false", "Any", "AnyObject", "some", "any", "inout", "mutating", "nonmutating",
        "static", "final", "dynamic", "lazy", "weak", "unowned", "get", "set",
        "willSet", "didSet", "required", "convenience", "override",
        "indirect", "fileprivate", "private", "internal", "public", "open",
        "where", "infix", "prefix", "postfix", "left", "right", "none",
        "associativity", "higherThan", "lowerThan"
    ]

    // MARK: - 初始化

    override init() {
        super.init(language: .swift)
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

            // 字符串（双引号）
            if char == "\"" {
                // 检查是否是多行字符串 """
                if text[index...].hasPrefix("\"\"\"") {
                    let _ = readMultilineString(text, index: &index)
                    tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                    continue
                }
                let _ = readString(text, index: &index, quote: "\"")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 字符（单引号）
            if char == "'" {
                let _ = readString(text, index: &index, quote: "'")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 预处理指令 #
            if char == "#" {
                let _ = readPreprocessor(text, index: &index)
                tokens.append(makeToken(type: .preprocessor, text: text, start: start, end: index))
                continue
            }

            // 装饰器/注解 @
            if char == "@" {
                let _ = readDecorator(text, index: &index)
                tokens.append(makeToken(type: .decorator, text: text, start: start, end: index))
                continue
            }

            // 标识符（关键字、函数名、类型名、变量名）
            if isIdentifierStart(char) {
                let identifier = readIdentifier(text, index: &index)

                // 检查是否是关键字
                if SwiftTokenizer.keywords.contains(identifier) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是类型名（大写开头）
                if let firstChar = identifier.first, firstChar.isUppercase {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 普通变量名
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 运算符
            if isOperator(char) {
                let _ = readOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符（普通文本）
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 私有方法

    /// 创建Token（使用String.Index范围）
    private func makeToken(type: SyntaxTokenType, text: String, start: String.Index, end: String.Index) -> SyntaxToken {
        let nsRange = NSRange(start..<end, in: text)
        let tokenText = String(text[start..<end])
        return SyntaxToken(type: type, range: nsRange, text: tokenText)
    }

    /// 读取多行字符串 """
    private func readMultilineString(_ text: String, index: inout String.Index) -> String {
        let start = index
        index = text.index(index, offsetBy: 3) // 跳过 """

        while index < text.endIndex {
            if text[index...].hasPrefix("\"\"\"") {
                index = text.index(index, offsetBy: 3)
                break
            }
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    /// 读取预处理指令
    private func readPreprocessor(_ text: String, index: inout String.Index) -> String {
        let start = index
        index = text.index(after: index) // 跳过 #

        // 读取指令名
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    /// 读取装饰器/注解
    private func readDecorator(_ text: String, index: inout String.Index) -> String {
        let start = index
        index = text.index(after: index) // 跳过 @

        // 读取装饰器名
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    /// 检查是否是运算符
    private func isOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ",", ";", ".", "(", ")", "[", "]", "{", "}"]
        return operators.contains(char)
    }

    /// 读取运算符
    private func readOperator(_ text: String, index: inout String.Index) -> String {
        let start = index

        // 读取连续的运算符字符
        while index < text.endIndex && isOperator(text[index]) {
            // 特殊处理：. 后面如果是数字，不继续读取
            if text[index] == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber {
                break
            }
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }
}
