import Foundation

// ==============================================================================
// PlainTextTokenizer 纯文本词法分析器（兜底）
// 功能：对纯文本进行词法分析，仅识别URL链接，其他均为普通文本
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class PlainTextTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    init() {
        super.init(language: .plainText)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            let start = index

            // URL自动识别（http/https）
            if char == "h" && text[index...].hasPrefix("http") {
                var tempIndex = index
                while tempIndex < text.endIndex && !text[tempIndex].isWhitespace && text[tempIndex] != ")" && text[tempIndex] != "]" && text[tempIndex] != ">" {
                    tempIndex = text.index(after: tempIndex)
                }
                if tempIndex > index {
                    tokens.append(makeToken(type: .url, text: text, start: start, end: tempIndex))
                    index = tempIndex
                    continue
                }
            }

            // 邮箱地址识别
            if char.isLetter || char.isNumber {
                var tempIndex = index
                var hasAt = false
                var hasDot = false
                while tempIndex < text.endIndex && (text[tempIndex].isLetter || text[tempIndex].isNumber || text[tempIndex] == "@" || text[tempIndex] == "." || text[tempIndex] == "_" || text[tempIndex] == "-") {
                    if text[tempIndex] == "@" { hasAt = true }
                    if text[tempIndex] == "." && hasAt { hasDot = true }
                    tempIndex = text.index(after: tempIndex)
                }
                if hasAt && hasDot && tempIndex > index {
                    tokens.append(makeToken(type: .url, text: text, start: start, end: tempIndex))
                    index = tempIndex
                    continue
                }
            }

            // 其他字符均为普通文本，不生成Token（使用默认颜色）
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
}
