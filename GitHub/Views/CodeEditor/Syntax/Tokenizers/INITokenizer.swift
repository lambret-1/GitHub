import Foundation

// ==============================================================================
// INITokenizer INI配置文件词法分析器
// 功能：对INI配置文件进行词法分析，识别节名、键名、值、注释等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class INITokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    init() {
        super.init(language: .ini)
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

            // 注释 ; 或 #
            if char == ";" || char == "#" {
                let commentStart = index
                while index < text.endIndex && text[index] != "\n" {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 节名 [section]
            if char == "[" {
                let sectionStart = index
                index = text.index(after: index)
                while index < text.endIndex && text[index] != "]" {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: sectionStart), length: text.distance(from: sectionStart, to: index))
                tokens.append(SyntaxToken(type: .keyword, range: range, text: String(text[sectionStart..<index])))
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
                        index = text.index(after: index)
                    }
                    if index < text.endIndex {
                        index = text.index(after: index)
                    }
                } else {
                    while index < text.endIndex && !text[index].isWhitespace && text[index] != "=" && text[index] != ":" {
                        index = text.index(after: index)
                    }
                }

                let keyEnd = index

                // 跳过空白
                while index < text.endIndex && text[index].isWhitespace {
                    index = text.index(after: index)
                }

                // 检查是否是等号或冒号
                if index < text.endIndex && (text[index] == "=" || text[index] == ":") {
                    // 键名
                    let range = NSRange(location: text.distance(from: text.startIndex, to: keyStart), length: text.distance(from: keyStart, to: keyEnd))
                    tokens.append(SyntaxToken(type: .variable, range: range, text: String(text[keyStart..<keyEnd])))

                    // 等号或冒号
                    let eqRange = NSRange(location: text.distance(from: text.startIndex, to: index), length: 1)
                    tokens.append(SyntaxToken(type: .operatorSymbol, range: eqRange, text: String(text[index])))
                    index = text.index(after: index)

                    // 跳过空白
                    while index < text.endIndex && text[index].isWhitespace {
                        index = text.index(after: index)
                    }

                    // 值
                    let valueStart = index
                    while index < text.endIndex && text[index] != "\n" && text[index] != ";" && text[index] != "#" {
                        index = text.index(after: index)
                    }
                    // 去除末尾空白
                    var valueEnd = index
                    while valueEnd > valueStart && text[text.index(before: valueEnd)].isWhitespace {
                        valueEnd = text.index(before: valueEnd)
                    }
                    if valueStart < valueEnd {
                        let range = NSRange(location: text.distance(from: text.startIndex, to: valueStart), length: text.distance(from: valueStart, to: valueEnd))
                        tokens.append(SyntaxToken(type: .string, range: range, text: String(text[valueStart..<valueEnd])))
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
