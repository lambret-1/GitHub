import Foundation

// ==============================================================================
// YAMLTokenizer YAML语言词法分析器
// 功能：对YAML代码进行词法分析，识别键名、值、字符串、注释、数字、布尔值等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class YAMLTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - YAML关键字

    private static let keywords: Set<String> = [
        "true", "false", "null", "yes", "no", "on", "off", "~",
        "True", "False", "Null", "Yes", "No", "On", "Off",
        "TRUE", "FALSE", "NULL", "YES", "NO", "ON", "OFF"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .yaml)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let lines = text.components(separatedBy: .newlines)
        var currentOffset = 0

        for (lineIndex, line) in lines.enumerated() {
            let lineStartOffset = currentOffset
            var index = line.startIndex

            // 跳过行首空白
            while index < line.endIndex && line[index].isWhitespace {
                index = line.index(after: index)
            }

            // 空行
            if index >= line.endIndex {
                currentOffset += line.utf16.count + 1
                continue
            }

            // 注释行
            if line[index] == "#" {
                let range = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: index), length: line.utf16.count - line.distance(from: line.startIndex, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(line[index...])))
                currentOffset += line.utf16.count + 1
                continue
            }

            // 文档分隔符 ---
            if line[index...].hasPrefix("---") {
                let range = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: index), length: 3)
                tokens.append(SyntaxToken(type: .keyword, range: range, text: "---"))
                currentOffset += line.utf16.count + 1
                continue
            }

            // 文档结束 ...
            if line[index...].hasPrefix("...") {
                let range = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: index), length: 3)
                tokens.append(SyntaxToken(type: .keyword, range: range, text: "..."))
                currentOffset += line.utf16.count + 1
                continue
            }

            // 列表项 -
            if line[index] == "-" && (index == line.endIndex || line[line.index(after: index)].isWhitespace) {
                let range = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: index), length: 1)
                tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: "-"))
                index = line.index(after: index)
                // 跳过空白
                while index < line.endIndex && line[index].isWhitespace {
                    index = line.index(after: index)
                }
            }

            // 键值对 key: value
            if let colonIndex = findColon(in: line, from: index) {
                // 键名
                let keyStart = lineStartOffset + line.distance(from: line.startIndex, to: index)
                let keyLength = line.distance(from: index, to: colonIndex)
                let keyRange = NSRange(location: keyStart, length: keyLength)
                let keyText = String(line[index..<colonIndex])
                tokens.append(SyntaxToken(type: .yamlKey, range: keyRange, text: keyText))

                // 冒号
                let colonRange = NSRange(location: keyStart + keyLength, length: 1)
                tokens.append(SyntaxToken(type: .operatorSymbol, range: colonRange, text: ":"))

                // 跳过冒号后的空白
                var valueIndex = line.index(after: colonIndex)
                while valueIndex < line.endIndex && line[valueIndex].isWhitespace {
                    valueIndex = line.index(after: valueIndex)
                }

                // 值
                if valueIndex < line.endIndex {
                    parseYAMLValue(line: line, valueIndex: &valueIndex, lineStartOffset: lineStartOffset, tokens: &tokens)
                }
            } else {
                // 纯文本行（可能是多行字符串的一部分）
                let range = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: index), length: line.utf16.count - line.distance(from: line.startIndex, to: index))
                tokens.append(SyntaxToken(type: .plain, range: range, text: String(line[index...])))
            }

            currentOffset += line.utf16.count + 1
        }

        return tokens
    }

    // MARK: - 辅助方法

    /// 查找键值对中的冒号（不在引号内）
    func findColon(in line: String, from start: String.Index) -> String.Index? {
        var index = start
        var inSingleQuote = false
        var inDoubleQuote = false

        while index < line.endIndex {
            let char = line[index]

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if char == ":" && !inSingleQuote && !inDoubleQuote {
                // 检查冒号后是否是空白或行尾
                let nextIndex = line.index(after: index)
                if nextIndex >= line.endIndex || line[nextIndex].isWhitespace {
                    return index
                }
            }

            index = line.index(after: index)
        }

        return nil
    }

    /// 解析YAML值
    func parseYAMLValue(line: String, valueIndex: inout String.Index, lineStartOffset: Int, tokens: inout [SyntaxToken]) {
        let valueStart = valueIndex

        // 检查是否是行内注释
        var commentIndex: String.Index?
        var index = valueIndex
        var inSingleQuote = false
        var inDoubleQuote = false

        while index < line.endIndex {
            let char = line[index]

            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
            } else if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
            } else if char == "#" && !inSingleQuote && !inDoubleQuote {
                // 检查#前是否是空白
                if index > valueIndex {
                    let prevIndex = line.index(before: index)
                    if line[prevIndex].isWhitespace {
                        commentIndex = index
                        break
                    }
                }
            }

            index = line.index(after: index)
        }

        // 值的结束位置
        let valueEnd = commentIndex ?? line.endIndex

        // 跳过值末尾的空白
        var trimmedEnd = valueEnd
        while trimmedEnd > valueStart && line[line.index(before: trimmedEnd)].isWhitespace {
            trimmedEnd = line.index(before: trimmedEnd)
        }

        if trimmedEnd > valueStart {
            let valueText = String(line[valueStart..<trimmedEnd])
            let valueRange = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: valueStart), length: line.distance(from: valueStart, to: trimmedEnd))

            // 判断值类型
            if valueText.hasPrefix("'") && valueText.hasSuffix("'") {
                tokens.append(SyntaxToken(type: .string, range: valueRange, text: valueText))
            } else if valueText.hasPrefix("\"") && valueText.hasSuffix("\"") {
                tokens.append(SyntaxToken(type: .string, range: valueRange, text: valueText))
            } else if YAMLTokenizer.keywords.contains(valueText) {
                if valueText == "true" || valueText == "false" || valueText == "True" || valueText == "False" || valueText == "TRUE" || valueText == "FALSE" || valueText == "yes" || valueText == "no" || valueText == "Yes" || valueText == "No" || valueText == "YES" || valueText == "NO" || valueText == "on" || valueText == "off" || valueText == "On" || valueText == "Off" || valueText == "ON" || valueText == "OFF" {
                    tokens.append(SyntaxToken(type: .constant, range: valueRange, text: valueText))
                } else {
                    tokens.append(SyntaxToken(type: .constant, range: valueRange, text: valueText))
                }
            } else if isNumber(valueText) {
                tokens.append(SyntaxToken(type: .number, range: valueRange, text: valueText))
            } else if valueText.hasPrefix("&") || valueText.hasPrefix("*") {
                // 锚点和别名
                tokens.append(SyntaxToken(type: .variable, range: valueRange, text: valueText))
            } else if valueText.hasPrefix("!") {
                // 标签
                tokens.append(SyntaxToken(type: .keyword, range: valueRange, text: valueText))
            } else {
                // 普通字符串值
                tokens.append(SyntaxToken(type: .yamlValue, range: valueRange, text: valueText))
            }
        }

        // 行内注释
        if let commentIndex = commentIndex {
            let commentRange = NSRange(location: lineStartOffset + line.distance(from: line.startIndex, to: commentIndex), length: line.utf16.count - line.distance(from: line.startIndex, to: commentIndex))
            tokens.append(SyntaxToken(type: .comment, range: commentRange, text: String(line[commentIndex...])))
        }
    }

    /// 检查是否是数字
    func isNumber(_ text: String) -> Bool {
        if text.isEmpty { return false }

        // 十六进制
        if text.hasPrefix("0x") || text.hasPrefix("0X") {
            return Int(text.dropFirst(2), radix: 16) != nil
        }

        // 八进制
        if text.hasPrefix("0o") || text.hasPrefix("0O") {
            return Int(text.dropFirst(2), radix: 8) != nil
        }

        // 二进制
        if text.hasPrefix("0b") || text.hasPrefix("0B") {
            return Int(text.dropFirst(2), radix: 2) != nil
        }

        // 普通整数或浮点数
        return Double(text) != nil
    }
}
