import Foundation

// ==============================================================================
// LanguageTokenizer 语言词法分析器协议
// 功能：定义词法分析器的标准接口，所有语言的Tokenizer必须实现此协议
// 位置：语法高亮系统的词法分析层
// ==============================================================================

/// 语言词法分析器协议
protocol LanguageTokenizer {
    /// 对应的编程语言
    var language: ProgrammingLanguage { get }

    /// 对文本进行词法分析，生成语法Token列表
    /// - Parameter text: 要分析的文本
    /// - Returns: 语法Token列表，按位置排序
    func tokenize(_ text: String) -> [SyntaxToken]
}

// MARK: - 词法分析器基类

/// 词法分析器基类，提供通用的辅助方法
class BaseLanguageTokenizer {
    let language: ProgrammingLanguage

    init(language: ProgrammingLanguage) {
        self.language = language
    }

    // MARK: - 通用辅助方法

    /// 创建Token
    /// - Parameters:
    ///   - type: Token类型
    ///   - text: 原始文本
    ///   - start: 起始位置（String.Index）
    ///   - end: 结束位置（String.Index）
    /// - Returns: SyntaxToken
    func makeToken(type: SyntaxTokenType, text: String, start: String.Index, end: String.Index) -> SyntaxToken {
        let nsRange = NSRange(start..<end, in: text)
        let tokenText = String(text[start..<end])
        return SyntaxToken(type: type, range: nsRange, text: tokenText)
    }

    /// 创建Token（使用NSRange）
    /// - Parameters:
    ///   - type: Token类型
    ///   - text: Token对应的文本内容
    ///   - range: 在文本中的范围
    /// - Returns: SyntaxToken
    func makeToken(type: SyntaxTokenType, text: String, range: NSRange) -> SyntaxToken {
        return SyntaxToken(type: type, range: range, text: text)
    }

    /// 检查字符是否是标识符的起始字符（字母、下划线、$）
    /// - Parameter char: 要检查的字符
    /// - Returns: 是否是标识符起始字符
    func isIdentifierStart(_ char: Character) -> Bool {
        return char.isLetter || char == "_" || char == "$"
    }

    /// 检查字符是否是标识符的组成字符（字母、数字、下划线、$）
    /// - Parameter char: 要检查的字符
    /// - Returns: 是否是标识符组成字符
    func isIdentifierPart(_ char: Character) -> Bool {
        return char.isLetter || char.isNumber || char == "_" || char == "$"
    }

    /// 检查字符是否是数字
    /// - Parameter char: 要检查的字符
    /// - Returns: 是否是数字
    func isDigit(_ char: Character) -> Bool {
        return char.isNumber
    }

    /// 检查字符是否是空白字符
    /// - Parameter char: 要检查的字符
    /// - Returns: 是否是空白字符
    func isWhitespace(_ char: Character) -> Bool {
        return char.isWhitespace
    }

    /// 读取标识符
    /// - Parameters:
    ///   - text: 文本
    ///   - index: 当前位置（会被修改为标识符结束位置）
    /// - Returns: 标识符字符串
    func readIdentifier(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 读取数字（支持十六进制、八进制、二进制、浮点数）
    /// - Parameters:
    ///   - text: 文本
    ///   - index: 当前位置（会被修改为数字结束位置）
    /// - Returns: 数字字符串
    func readNumber(_ text: String, index: inout String.Index) -> String {
        let start = index

        // 检查十六进制 0x
        if text[index] == "0" && index < text.index(before: text.endIndex) {
            let next = text[text.index(after: index)]
            if next == "x" || next == "X" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (text[index].isHexDigit || text[index] == "_") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
            // 检查二进制 0b
            if next == "b" || next == "B" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (text[index] == "0" || text[index] == "1" || text[index] == "_") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
            // 检查八进制 0o
            if next == "o" || next == "O" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (("0"..."7").contains(text[index]) || text[index] == "_") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
        }

        // 普通数字
        while index < text.endIndex && (text[index].isNumber || text[index] == "_") {
            index = text.index(after: index)
        }

        // 检查小数点
        if index < text.endIndex && text[index] == "." {
            let nextIndex = text.index(after: index)
            if nextIndex < text.endIndex && text[nextIndex].isNumber {
                index = nextIndex
                while index < text.endIndex && (text[index].isNumber || text[index] == "_") {
                    index = text.index(after: index)
                }
            }
        }

        // 检查科学计数法
        if index < text.endIndex && (text[index] == "e" || text[index] == "E") {
            let nextIndex = text.index(after: index)
            if nextIndex < text.endIndex && (text[nextIndex] == "+" || text[nextIndex] == "-" || text[nextIndex].isNumber) {
                index = nextIndex
                if text[index] == "+" || text[index] == "-" {
                    index = text.index(after: index)
                }
                while index < text.endIndex && text[index].isNumber {
                    index = text.index(after: index)
                }
            }
        }

        // 检查大整数后缀 n
        if index < text.endIndex && text[index] == "n" {
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    /// 读取字符串（支持单引号、双引号、模板字符串）
    /// - Parameters:
    ///   - text: 文本
    ///   - index: 当前位置（会被修改为字符串结束位置）
    ///   - quote: 引号字符
    /// - Returns: 字符串（包含引号）
    func readString(_ text: String, index: inout String.Index, quote: Character) -> String {
        let start = index
        index = text.index(after: index) // 跳过开始引号

        while index < text.endIndex {
            let char = text[index]
            if char == "\\" {
                // 转义字符，跳过下一个字符
                index = text.index(after: index)
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                continue
            }
            if char == quote {
                index = text.index(after: index) // 跳过结束引号
                break
            }
            if char == "\n" {
                // 字符串不跨行（除非是模板字符串）
                break
            }
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    /// 读取单行注释
    /// - Parameters:
    ///   - text: 文本
    ///   - index: 当前位置（会被修改为注释结束位置）
    /// - Returns: 注释字符串
    func readLineComment(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && text[index] != "\n" {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 读取多行注释
    /// - Parameters:
    ///   - text: 文本
    ///   - index: 当前位置（会被修改为注释结束位置）
    ///   - endSymbol: 结束符号（如 */）
    /// - Returns: 注释字符串
    func readBlockComment(_ text: String, index: inout String.Index, endSymbol: String) -> String {
        let start = index
        while index < text.endIndex {
            if text[index...].hasPrefix(endSymbol) {
                index = text.index(index, offsetBy: endSymbol.count)
                break
            }
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
