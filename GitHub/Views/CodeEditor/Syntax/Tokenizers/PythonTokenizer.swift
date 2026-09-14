import Foundation

// ==============================================================================
// PythonTokenizer Python语言词法分析器
// 功能：对Python代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class PythonTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - Python关键字

    private static let keywords: Set<String> = [
        "False", "None", "True", "and", "as", "assert", "async", "await",
        "break", "class", "continue", "def", "del", "elif", "else", "except",
        "finally", "for", "from", "global", "if", "import", "in", "is",
        "lambda", "nonlocal", "not", "or", "pass", "raise", "return", "try",
        "while", "with", "yield", "match", "case", "type", "self", "cls"
    ]

    // MARK: - 内置函数和类型

    private static let builtins: Set<String> = [
        "print", "len", "range", "str", "int", "float", "bool", "list", "dict",
        "tuple", "set", "frozenset", "type", "isinstance", "issubclass", "hasattr",
        "getattr", "setattr", "delattr", "vars", "dir", "id", "hash", "repr",
        "ascii", "chr", "ord", "hex", "oct", "bin", "abs", "max", "min", "sum",
        "pow", "round", "divmod", "modf", "floor", "ceil", "sqrt", "exp", "log",
        "sin", "cos", "tan", "input", "open", "file", "compile", "eval", "exec",
        "help", "callable", "iter", "next", "enumerate", "zip", "map", "filter",
        "reduce", "sorted", "reversed", "any", "all", "object", "super", "property",
        "staticmethod", "classmethod", "Exception", "ValueError", "TypeError",
        "KeyError", "IndexError", "AttributeError", "IOError", "OSError",
        "FileNotFoundError", "PermissionError", "RuntimeError", "NotImplementedError",
        "ImportError", "ModuleNotFoundError", "SyntaxError", "IndentationError",
        "NameError", "UnboundLocalError", "ZeroDivisionError", "OverflowError",
        "RecursionError", "MemoryError", "SystemError", "KeyboardInterrupt",
        "GeneratorExit", "SystemExit", "StopIteration", "StopAsyncIteration",
        "ArithmeticError", "BufferError", "LookupError", "EnvironmentError",
        "EOFError", "BlockingIOError", "ChildProcessError", "ConnectionError",
        "BrokenPipeError", "ConnectionAbortedError", "ConnectionRefusedError",
        "ConnectionResetError", "FileExistsError", "InterruptedError", "IsADirectoryError",
        "NotADirectoryError", "ProcessLookupError", "TimeoutError", "Warning",
        "DeprecationWarning", "PendingDeprecationWarning", "RuntimeWarning",
        "SyntaxWarning", "UserWarning", "FutureWarning", "ImportWarning",
        "UnicodeWarning", "BytesWarning", "ResourceWarning"
    ]

    // MARK: - 初始化

    override init() {
        super.init(language: .python)
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

            // 单行注释 #
            if char == "#" {
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 字符串
            if char == "\"" || char == "'" {
                // 检查是否是三引号字符串
                if text[index...].hasPrefix("\"\"\"") || text[index...].hasPrefix("'''") {
                    let quote = String(text[index...index]).padding(toLength: 3, withPad: String(char), startingAt: 0)
                    let _ = readTripleQuotedString(text, index: &index, quote: String(char))
                    tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                    continue
                }
                let _ = readString(text, index: &index, quote: char)
                tokens.append(makeToken(type: .string, text: text, start: start, end: index))
                continue
            }

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readPythonNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 装饰器 @
            if char == "@" {
                let _ = readDecorator(text, index: &index)
                tokens.append(makeToken(type: .decorator, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let identifier = readIdentifier(text, index: &index)

                // 关键字
                if PythonTokenizer.keywords.contains(identifier) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                // 内置函数/类型
                if PythonTokenizer.builtins.contains(identifier) {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                // 函数定义（def后面的标识符）
                // 函数调用（后面跟着括号）
                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                // 类名（大写开头）
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

    private func readTripleQuotedString(_ text: String, index: inout String.Index, quote: String) -> String {
        let start = index
        let tripleQuote = String(repeating: quote, count: 3)
        index = text.index(index, offsetBy: 3)

        while index < text.endIndex {
            if text[index...].hasPrefix(tripleQuote) {
                index = text.index(index, offsetBy: 3)
                break
            }
            index = text.index(after: index)
        }

        return String(text[start..<index])
    }

    private func readPythonNumber(_ text: String, index: inout String.Index) -> String {
        let start = index

        // 检查十六进制 0x
        if text[index] == "0" && index < text.index(before: text.endIndex) {
            let next = text[text.index(after: index)]
            if next == "x" || next == "X" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (text[index].isHexDigit || text[index] == "_") {
                    index = text.index(after: index)
                }
                // 复数后缀 j
                if index < text.endIndex && (text[index] == "j" || text[index] == "J") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
            // 八进制 0o
            if next == "o" || next == "O" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (("0"..."7").contains(text[index]) || text[index] == "_") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
            // 二进制 0b
            if next == "b" || next == "B" {
                index = text.index(after: text.index(after: index))
                while index < text.endIndex && (text[index] == "0" || text[index] == "1" || text[index] == "_") {
                    index = text.index(after: index)
                }
                return String(text[start..<index])
            }
        }

        // 普通数字
        while index < text.endIndex && (text[index].isNumber || text[index] == "_") {
            index = text.index(after: index)
        }

        // 小数点
        if index < text.endIndex && text[index] == "." {
            let nextIndex = text.index(after: index)
            if nextIndex < text.endIndex && text[nextIndex].isNumber {
                index = nextIndex
                while index < text.endIndex && (text[index].isNumber || text[index] == "_") {
                    index = text.index(after: index)
                }
            }
        }

        // 科学计数法
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

        // 复数后缀 j
        if index < text.endIndex && (text[index] == "j" || text[index] == "J") {
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
