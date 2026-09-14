import Foundation

// ==============================================================================
// RubyTokenizer Ruby语言词法分析器
// 功能：对Ruby代码进行词法分析，识别关键字、字符串、注释、数字、函数、变量等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class RubyTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - Ruby关键字

    private static let keywords: Set<String> = [
        "BEGIN", "END", "alias", "and", "begin", "break", "case", "class",
        "def", "defined?", "do", "else", "elsif", "end", "ensure", "false",
        "for", "if", "in", "module", "next", "nil", "not", "or", "redo",
        "rescue", "retry", "return", "self", "super", "then", "true", "undef",
        "unless", "until", "when", "while", "yield", "__FILE__", "__LINE__",
        "__ENCODING__", "require", "require_relative", "load", "include",
        "extend", "prepend", "attr_accessor", "attr_reader", "attr_writer",
        "private", "public", "protected", "module_function", "raise", "throw",
        "catch", "lambda", "proc", "binding", "eval", "exec", "system",
        "sprintf", "format", "puts", "print", "p", "pp", "gets", "readline",
        "readlines", "open", "URI", "JSON", "YAML", "File", "Dir", "IO",
        "ENV", "ARGV", "ARGF", "STDIN", "STDOUT", "STDERR", "RUBY_VERSION",
        "RUBY_PLATFORM", "RUBY_RELEASE_DATE", "RUBY_PATCHLEVEL", "RUBY_REVISION",
        "RUBY_ENGINE", "RUBY_ENGINE_VERSION", "RUBY_COPYRIGHT", "RUBY_DESCRIPTION"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .ruby)
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

            // 注释 #
            if char == "#" {
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 实例变量 @
            if char == "@" {
                let _ = readRubyVariable(text, index: &index, prefix: "@")
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 类变量 @@
            if char == "@" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "@" {
                let _ = readRubyVariable(text, index: &index, prefix: "@@")
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 全局变量 $
            if char == "$" {
                let _ = readRubyVariable(text, index: &index, prefix: "$")
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 符号 :
            if char == ":" && index < text.index(before: text.endIndex) && (isIdentifierStart(text[text.index(after: index)]) || text[text.index(after: index)] == "\"" || text[text.index(after: index)] == "'") {
                let _ = readRubySymbol(text, index: &index)
                tokens.append(makeToken(type: .constant, text: text, start: start, end: index))
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

            // 反引号命令替换
            if char == "`" {
                let _ = readString(text, index: &index, quote: "`")
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let word = readIdentifier(text, index: &index)

                // 检查是否是关键字
                if RubyTokenizer.keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是常量（大写开头）
                if let firstChar = word.first, firstChar.isUppercase {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 检查是否是方法调用（后面跟着括号或点）
                if index < text.endIndex && (text[index] == "(" || text[index] == ".") {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 普通标识符
                tokens.append(makeToken(type: .plain, text: text, start: start, end: index))
                continue
            }

            // 运算符
            if isRubyOperator(char) {
                let _ = readRubyOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 读取Ruby变量
    func readRubyVariable(_ text: String, index: inout String.Index, prefix: String) -> String {
        let start = index
        // 跳过前缀
        for _ in 0..<prefix.count {
            if index < text.endIndex {
                index = text.index(after: index)
            }
        }
        // 读取标识符
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 读取Ruby符号
    func readRubySymbol(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过:
        index = text.index(after: index)

        // 检查是否是字符串符号 :"..." 或 :'...'
        if index < text.endIndex && (text[index] == "\"" || text[index] == "'") {
            let quote = text[index]
            index = text.index(after: index)
            while index < text.endIndex && text[index] != quote {
                if text[index] == "\\" && index < text.index(before: text.endIndex) {
                    index = text.index(after: index)
                }
                index = text.index(after: index)
            }
            if index < text.endIndex {
                index = text.index(after: index)
            }
            return String(text[start..<index])
        }

        // 普通符号 :identifier
        while index < text.endIndex && (isIdentifierPart(text[index]) || text[index] == "?" || text[index] == "!") {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }

    /// 检查是否是Ruby运算符
    func isRubyOperator(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "%", "=", "<", ">", "!", "&", "|", "^", "~", "?", ":", ",", ";", ".", "(", ")", "{", "}", "[", "]"]
        return operators.contains(char)
    }

    /// 读取Ruby运算符
    func readRubyOperator(_ text: String, index: inout String.Index) -> String {
        let start = index
        while index < text.endIndex && isRubyOperator(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
