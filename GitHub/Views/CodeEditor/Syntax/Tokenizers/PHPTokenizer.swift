import Foundation

// ==============================================================================
// PHPTokenizer PHP语言词法分析器
// 功能：对PHP代码进行词法分析，识别关键字、字符串、注释、数字、函数、类型等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class PHPTokenizer: CLikeTokenizer {
    // MARK: - PHP关键字

    override var keywords: Set<String> {
        return [
            "abstract", "and", "array", "as", "break", "callable", "case", "catch",
            "class", "clone", "const", "continue", "declare", "default", "die", "do",
            "echo", "else", "elseif", "empty", "enddeclare", "endfor", "endforeach",
            "endif", "endswitch", "endwhile", "eval", "exit", "extends", "final",
            "finally", "fn", "for", "foreach", "function", "global", "goto", "if",
            "implements", "include", "include_once", "instanceof", "insteadof", "interface",
            "isset", "list", "match", "namespace", "new", "or", "print", "private",
            "protected", "public", "readonly", "require", "require_once", "return",
            "static", "switch", "throw", "trait", "try", "unset", "use", "var",
            "while", "xor", "yield", "yield from", "enum", "never", "void", "mixed",
            "self", "parent", "static", "true", "false", "null"
        ]
    }

    // MARK: - PHP类型

    override var types: Set<String> {
        return [
            "int", "integer", "float", "double", "string", "bool", "boolean", "array",
            "object", "callable", "iterable", "resource", "null", "void", "mixed",
            "never", "self", "parent", "static", "stdClass", "Exception", "ErrorException",
            "Error", "TypeError", "ValueError", "ArgumentCountError", "ArithmeticError",
            "DivisionByZeroError", "ParseError", "Throwable", "Stringable", "Countable",
            "ArrayAccess", "Iterator", "IteratorAggregate", "Traversable", "Serializable",
            "JsonSerializable", "Closure", "Generator", "WeakReference", "WeakMap",
            "DateTime", "DateTimeImmutable", "DateTimeInterface", "DateTimeZone",
            "DateInterval", "DatePeriod", "SplFileInfo", "SplFileObject", "SplTempFileObject",
            "SplDirectory", "FilesystemIterator", "RecursiveDirectoryIterator",
            "GlobIterator", "SplStack", "SplQueue", "SplPriorityQueue", "SplHeap",
            "SplMinHeap", "SplMaxHeap", "SplFixedArray", "SplObjectStorage",
            "PDO", "PDOStatement", "PDOException", "mysqli", "mysqli_stmt", "mysqli_result",
            "Redis", "Memcached", "CurlHandle", "SimpleXMLElement", "DOMDocument",
            "DOMElement", "DOMNode", "DOMNodeList", "DOMXPath", "ZipArchive",
            " Phar", "PharData", "PharFileInfo", "ReflectionClass", "ReflectionMethod",
            "ReflectionProperty", "ReflectionFunction", "ReflectionParameter", "ReflectionType",
            "ReflectionAttribute", "ReflectionEnum", "ReflectionEnumUnitCase",
            "ReflectionEnumBackedCase", "Generator", "Fiber", "FiberError", "SensitiveParameterValue"
        ]
    }

    // MARK: - 初始化

    init() {
        super.init(language: .php)
    }

    // MARK: - 词法分析（覆盖：PHP变量以$开头）

    override func tokenize(_ text: String) -> [SyntaxToken] {
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

            // PHP变量 $
            if char == "$" {
                let _ = readPHPVariable(text, index: &index)
                tokens.append(makeToken(type: .variable, text: text, start: start, end: index))
                continue
            }

            // 单行注释 //
            if char == "/" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "/" {
                let _ = readLineComment(text, index: &index)
                tokens.append(makeToken(type: .comment, text: text, start: start, end: index))
                continue
            }

            // 单行注释 #
            if char == "#" {
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

            // 数字
            if char.isNumber || (char == "." && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let _ = readNumber(text, index: &index)
                tokens.append(makeToken(type: .number, text: text, start: start, end: index))
                continue
            }

            // 标识符
            if isIdentifierStart(char) {
                let word = readIdentifier(text, index: &index)

                if keywords.contains(word) {
                    tokens.append(makeToken(type: .keyword, text: text, start: start, end: index))
                    continue
                }

                if constants.contains(word) {
                    tokens.append(makeToken(type: .constant, text: text, start: start, end: index))
                    continue
                }

                if types.contains(word) {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                if index < text.endIndex && text[index] == "(" {
                    tokens.append(makeToken(type: .function, text: text, start: start, end: index))
                    continue
                }

                if let firstChar = word.first, firstChar.isUppercase {
                    tokens.append(makeToken(type: .type, text: text, start: start, end: index))
                    continue
                }

                tokens.append(makeToken(type: .plain, text: text, start: start, end: index))
                continue
            }

            // 运算符
            if isOperator(char) {
                let _ = readOperator(text, index: &index)
                tokens.append(makeToken(type: .operatorSymbol, text: text, start: start, end: index))
                continue
            }

            index = text.index(after: index)
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 读取PHP变量
    func readPHPVariable(_ text: String, index: inout String.Index) -> String {
        let start = index
        // 跳过$
        index = text.index(after: index)
        // 读取标识符
        while index < text.endIndex && isIdentifierPart(text[index]) {
            index = text.index(after: index)
        }
        return String(text[start..<index])
    }
}
