import Foundation

// ==============================================================================
// TOMLTokenizer TOML配置文件词法分析器
// 功能：对TOML配置文件进行词法分析，识别表名、键名、值、注释等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class TOMLTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    init() {
        super.init(language: .toml)
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
                let commentStart = index
                while index < text.endIndex && text[index] != "\n" {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 表名 [table] 或 [[array_of_tables]]
            if char == "[" {
                let tableStart = index
                index = text.index(after: index)

                // 检查是否是数组表 [[...]]
                var isArrayTable = false
                if index < text.endIndex && text[index] == "[" {
                    isArrayTable = true
                    index = text.index(after: index)
                }

                // 表名内容
                while index < text.endIndex && text[index] != "]" {
                    index = text.index(after: index)
                }

                // 跳过结束括号
                if index < text.endIndex && text[index] == "]" {
                    index = text.index(after: index)
                    if isArrayTable && index < text.endIndex && text[index] == "]" {
                        index = text.index(after: index)
                    }
                }

                let range = NSRange(location: text.distance(from: text.startIndex, to: tableStart), length: text.distance(from: tableStart, to: index))
                tokens.append(SyntaxToken(type: .keyword, range: range, text: String(text[tableStart..<index])))
                continue
            }

            // 键名 key = value
            if isIdentifierStart(char) || char == "\"" || char == "'" {
                let keyStart = index

                // 处理带引号的键名
                if char == "\"" || char == "'" {
                    let quote = char
                    index = text.index(after: index)
                    while index < text.endIndex && text[index] != quote {
                        if text[index] == "\\" {
                            index = text.index(after: index)
                        }
                        index = text.index(after: index)
                    }
                    if index < text.endIndex {
                        index = text.index(after: index)
                    }
                } else {
                    while index < text.endIndex && !text[index].isWhitespace && text[index] != "=" && text[index] != "." {
                        index = text.index(after: index)
                    }
                    // 处理点分隔的键名 a.b.c
                    while index < text.endIndex && text[index] == "." {
                        index = text.index(after: index)
                        while index < text.endIndex && !text[index].isWhitespace && text[index] != "=" && text[index] != "." {
                            index = text.index(after: index)
                        }
                    }
                }

                let keyEnd = index

                // 跳过空白
                while index < text.endIndex && text[index].isWhitespace {
                    index = text.index(after: index)
                }

                // 检查是否是等号
                if index < text.endIndex && text[index] == "=" {
                    // 键名
                    let range = NSRange(location: text.distance(from: text.startIndex, to: keyStart), length: text.distance(from: keyStart, to: keyEnd))
                    tokens.append(SyntaxToken(type: .variable, range: range, text: String(text[keyStart..<keyEnd])))

                    // 等号
                    let eqRange = NSRange(location: text.distance(from: text.startIndex, to: index), length: 1)
                    tokens.append(SyntaxToken(type: .operatorSymbol, range: eqRange, text: "="))
                    index = text.index(after: index)

                    // 跳过空白
                    while index < text.endIndex && text[index].isWhitespace {
                        index = text.index(after: index)
                    }

                    // 值
                    let valueStart = index
                    if index < text.endIndex {
                        let valueChar = text[index]

                        // 字符串
                        if valueChar == "\"" || valueChar == "'" {
                            let quote = valueChar
                            index = text.index(after: index)
                            // 检查是否是三引号字符串
                            if index < text.endIndex && text[index] == quote && index < text.index(before: text.endIndex) && text[text.index(after: index)] == quote {
                                index = text.index(index, offsetBy: 2)
                                while index < text.endIndex && !(text[index] == quote && index < text.index(before: text.endIndex) && text[text.index(after: index)] == quote && index < text.index(text.endIndex, offsetBy: -2) && text[text.index(index, offsetBy: 2)] == quote) {
                                    index = text.index(after: index)
                                }
                                if index < text.endIndex {
                                    index = text.index(index, offsetBy: 3)
                                }
                            } else {
                                while index < text.endIndex && text[index] != quote {
                                    if text[index] == "\\" {
                                        index = text.index(after: index)
                                    }
                                    index = text.index(after: index)
                                }
                                if index < text.endIndex {
                                    index = text.index(after: index)
                                }
                            }
                            let range = NSRange(location: text.distance(from: text.startIndex, to: valueStart), length: text.distance(from: valueStart, to: index))
                            tokens.append(SyntaxToken(type: .string, range: range, text: String(text[valueStart..<index])))
                            continue
                        }

                        // 布尔值
                        if valueChar == "t" || valueChar == "f" {
                            let boolStart = index
                            while index < text.endIndex && text[index].isLetter {
                                index = text.index(after: index)
                            }
                            let word = String(text[boolStart..<index])
                            if word == "true" || word == "false" {
                                let range = NSRange(location: text.distance(from: text.startIndex, to: boolStart), length: text.distance(from: boolStart, to: index))
                                tokens.append(SyntaxToken(type: .constant, range: range, text: word))
                                continue
                            }
                        }

                        // 数字
                        if valueChar.isNumber || valueChar == "-" || valueChar == "+" {
                            let numStart = index
                            if valueChar == "-" || valueChar == "+" {
                                index = text.index(after: index)
                            }
                            while index < text.endIndex && (text[index].isNumber || text[index] == "." || text[index] == "e" || text[index] == "E" || text[index] == "+" || text[index] == "-" || text[index] == "_") {
                                index = text.index(after: index)
                            }
                            // 检查是否是日期时间
                            let numText = String(text[numStart..<index])
                            if numText.contains("T") || numText.contains(":") || numText.contains("Z") {
                                let range = NSRange(location: text.distance(from: text.startIndex, to: numStart), length: text.distance(from: numStart, to: index))
                                tokens.append(SyntaxToken(type: .type, range: range, text: numText))
                            } else {
                                let range = NSRange(location: text.distance(from: text.startIndex, to: numStart), length: text.distance(from: numStart, to: index))
                                tokens.append(SyntaxToken(type: .number, range: range, text: numText))
                            }
                            continue
                        }

                        // 数组 [ ... ]
                        if valueChar == "[" {
                            let arrayStart = index
                            var depth = 0
                            while index < text.endIndex {
                                if text[index] == "[" {
                                    depth += 1
                                } else if text[index] == "]" {
                                    depth -= 1
                                    if depth == 0 {
                                        index = text.index(after: index)
                                        break
                                    }
                                }
                                index = text.index(after: index)
                            }
                            let range = NSRange(location: text.distance(from: text.startIndex, to: arrayStart), length: text.distance(from: arrayStart, to: index))
                            tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: String(text[arrayStart..<index])))
                            continue
                        }

                        // 内联表 { ... }
                        if valueChar == "{" {
                            let tableStart = index
                            var depth = 0
                            while index < text.endIndex {
                                if text[index] == "{" {
                                    depth += 1
                                } else if text[index] == "}" {
                                    depth -= 1
                                    if depth == 0 {
                                        index = text.index(after: index)
                                        break
                                    }
                                }
                                index = text.index(after: index)
                            }
                            let range = NSRange(location: text.distance(from: text.startIndex, to: tableStart), length: text.distance(from: tableStart, to: index))
                            tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: String(text[tableStart..<index])))
                            continue
                        }

                        // 其他值（直到行尾或注释）
                        while index < text.endIndex && text[index] != "\n" && text[index] != "#" {
                            index = text.index(after: index)
                        }
                        // 去除末尾空白
                        var valueEnd = index
                        while valueEnd > valueStart && text[text.index(before: valueEnd)].isWhitespace {
                            valueEnd = text.index(before: valueEnd)
                        }
                        if valueStart < valueEnd {
                            let range = NSRange(location: text.distance(from: text.startIndex, to: valueStart), length: text.distance(from: valueStart, to: valueEnd))
                            tokens.append(SyntaxToken(type: .plain, range: range, text: String(text[valueStart..<valueEnd])))
                        }
                    }
                    continue
                } else {
                    // 不是键值对，作为普通文本
                    index = keyEnd
                }
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }
}
