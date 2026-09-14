import Foundation

// ==============================================================================
// JSONTokenizer JSON语言词法分析器
// 功能：对JSON代码进行词法分析，识别键名、字符串、数字、布尔值、null等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class JSONTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    init() {
        super.init(language: .json)
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

            // 字符串（双引号）
            if char == "\"" {
                let stringStart = index
                index = text.index(after: index)

                // 查找字符串结束
                while index < text.endIndex {
                    if text[index] == "\\" {
                        // 跳过转义字符
                        index = text.index(after: index)
                        if index < text.endIndex {
                            index = text.index(after: index)
                        }
                    } else if text[index] == "\"" {
                        index = text.index(after: index)
                        break
                    } else {
                        index = text.index(after: index)
                    }
                }

                // 判断是键名还是值
                var tempIndex = index
                while tempIndex < text.endIndex && text[tempIndex].isWhitespace {
                    tempIndex = text.index(after: tempIndex)
                }

                if tempIndex < text.endIndex && text[tempIndex] == ":" {
                    // 键名
                    let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                    tokens.append(SyntaxToken(type: .yamlKey, range: range, text: String(text[stringStart..<index])))
                } else {
                    // 字符串值
                    let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                    tokens.append(SyntaxToken(type: .string, range: range, text: String(text[stringStart..<index])))
                }
                continue
            }

            // 数字
            if char.isNumber || (char == "-" && index < text.index(before: text.endIndex) && text[text.index(after: index)].isNumber) {
                let numberStart = index
                if char == "-" {
                    index = text.index(after: index)
                }
                while index < text.endIndex && (text[index].isNumber || text[index] == "." || text[index] == "e" || text[index] == "E" || text[index] == "+" || text[index] == "-") {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: numberStart), length: text.distance(from: numberStart, to: index))
                tokens.append(SyntaxToken(type: .number, range: range, text: String(text[numberStart..<index])))
                continue
            }

            // 布尔值和null
            if char == "t" || char == "f" || char == "n" {
                let wordStart = index
                while index < text.endIndex && text[index].isLetter {
                    index = text.index(after: index)
                }
                let word = String(text[wordStart..<index])
                if word == "true" || word == "false" || word == "null" {
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: .constant, range: range, text: word))
                    continue
                }
            }

            // 结构符号
            if char == "{" || char == "}" || char == "[" || char == "]" || char == ":" || char == "," {
                let range = NSRange(location: text.distance(from: text.startIndex, to: start), length: 1)
                tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: String(char)))
                index = text.index(after: index)
                continue
            }

            // 其他字符
            index = text.index(after: index)
        }

        return tokens
    }
}
