import Foundation

// ==============================================================================
// CLikeTokenizer C类语言词法分析器基类
// 功能：提供C类语言（Java、Go、C/C++、PHP、Rust、Kotlin等）的通用词法分析
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class CLikeTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 关键字集合（子类可覆盖）

    var keywords: Set<String> {
        return []
    }

    // MARK: - 常量集合（子类可覆盖）

    var constants: Set<String> {
        return ["true", "false", "null", "nil", "NULL", "None"]
    }

    // MARK: - 类型集合（子类可覆盖）

    var types: Set<String> {
        return []
    }

    // MARK: - 初始化

    override init(language: ProgrammingLanguage) {
        super.init(language: language)
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

            // 字符串（双引号）
            if char == "\"" {
                let _ = readString(text, index: &index, quote: "\"")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 字符串（单引号）
            if char == "'" {
                let _ = readString(text, index: &index, quote: "'")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 字符（反引号，Go/Rust等）
            if char == "`" {
                let _ = readString(text, index: &index, quote: "`")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let word = readIdentifier(text, index: &index)

                // 检查是否是关键字
                if keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是常量
                if constants.contains(word) {
                    tokens.append(makeToken(type: .constant, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是类型
                if types.contains(word) {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是类型名（大写开头）
                if let firstChar = word.first, firstChar.isUppercase {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 普通标识符
                tokens.append(makeToken(type: .plain, text: text, start: start, end: index))
                continue
            }

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

    // MARK: - 辅助方法

    /// 读取预处理指令
    func readPreprocessor(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && text[index] != "\n" {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 读取装饰器/注解
    func readDecorator(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过@
        index = text.index(after: index)
        // 读取标识符
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 检查是否是运算符
    func isOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ",", ";", ".", "(", ")", "{", "}", "[", "]"]
        return operators.contains(char)
    }

    /// 读取运算符
    func readOperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isOperator(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
