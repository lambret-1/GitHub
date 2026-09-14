import Foundation

// ==============================================================================
// MarkdownTokenizer Markdown语言词法分析器
// 功能：对Markdown文本进行词法分析，识别标题、列表、代码块、链接、粗体、斜体等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class MarkdownTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    override init() {
        super.init(language: .markdown)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        let lines = text.components(separatedBy: .newlines)
        var currentIndex = text.startIndex
        var inCodeBlock = false
        var codeBlockStart = text.startIndex

        for (lineIndex, line) in lines.enumerated() {
            let lineStart = currentIndex
            let lineEnd = line.isEmpty ? lineStart : text.index(lineStart, offsetBy: line.count)

            // 代码块开始/结束
            if line.hasPrefix("```") || line.hasPrefix("~~~") {
                if inCodeBlock {
                    // 代码块结束
                    tokens.append(makeToken(type: .codeBlock, text: text, start: codeBlockStart, end: lineEnd))
                    inCodeBlock = false
                } else {
                    // 代码块开始
                    codeBlockStart = lineStart
                    inCodeBlock = true
                }
                currentIndex = lineEnd
                if lineIndex < lines.count - 1 {
                    currentIndex = text.index(after: currentIndex) // 跳过换行符
                }
                continue
            }

            // 在代码块中，跳过语法分析
            if inCodeBlock {
                currentIndex = lineEnd
                if lineIndex < lines.count - 1 {
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }

            // 标题 # ## ### #### ##### ######
            if line.hasPrefix("#") {
                var level = 0
                var tempIndex = lineStart
                while tempIndex < lineEnd && text[tempIndex] == "#" {
                    level += 1
                    tempIndex = text.index(after: tempIndex)
                }
                if level <= 6 && (tempIndex == lineEnd || text[tempIndex] == " ") {
                    tokens.append(makeToken(type: .heading, text: text, start: lineStart, end: lineEnd))
                    currentIndex = lineEnd
                    if lineIndex < lines.count - 1 {
                        currentIndex = text.index(after: currentIndex)
                    }
                    continue
                }
            }

            // 水平线 --- *** ___
            if line == "---" || line == "***" || line == "___" || line == "- - -" || line == "* * *" {
                tokens.append(makeToken(type: .heading, text: text, start: lineStart, end: lineEnd))
                currentIndex = lineEnd
                if lineIndex < lines.count - 1 {
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }

            // 无序列表 - * +
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                tokens.append(makeToken(type: .listItem, text: text, start: lineStart, end: lineEnd))
                currentIndex = lineEnd
                if lineIndex < lines.count - 1 {
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }

            // 有序列表 1. 2. 3.
            if let firstChar = line.first, firstChar.isNumber {
                var tempIndex = lineStart
                while tempIndex < lineEnd && text[tempIndex].isNumber {
                    tempIndex = text.index(after: tempIndex)
                }
                if tempIndex < lineEnd && text[tempIndex] == "." {
                    let nextIndex = text.index(after: tempIndex)
                    if nextIndex == lineEnd || text[nextIndex] == " " {
                        tokens.append(makeToken(type: .listItem, text: text, start: lineStart, end: lineEnd))
                        currentIndex = lineEnd
                        if lineIndex < lines.count - 1 {
                            currentIndex = text.index(after: currentIndex)
                        }
                        continue
                    }
                }
            }

            // 引用 >
            if line.hasPrefix(">") {
                tokens.append(makeToken(type: .comment, text: text, start: lineStart, end: lineEnd))
                currentIndex = lineEnd
                if lineIndex < lines.count - 1 {
                    currentIndex = text.index(after: currentIndex)
                }
                continue
            }

            // 行内元素分析（粗体、斜体、链接、代码）
            analyzeInlineElements(text: text, lineStart: lineStart, lineEnd: lineEnd, tokens: &tokens)

            currentIndex = lineEnd
            if lineIndex < lines.count - 1 {
                currentIndex = text.index(after: currentIndex) // 跳过换行符
            }
        }

        // 如果代码块没有结束，将剩余部分标记为代码块
        if inCodeBlock {
            tokens.append(makeToken(type: .codeBlock, text: text, start: codeBlockStart, end: text.endIndex))
        }

        return tokens
    }

    // MARK: - 私有方法

    private func makeToken(type: SyntaxTokenType, text: String, start: String.Index, end: String.Index) -> SyntaxToken {
        let nsRange = NSRange(start..<end, in: text)
        let tokenText = String(text[start..<end])
        return SyntaxToken(type: type, range: nsRange, text: tokenText)
    }

    /// 分析行内元素（粗体、斜体、链接、行内代码）
    private func analyzeInlineElements(text: String, lineStart: String.Index, lineEnd: String.Index, tokens: inout [SyntaxToken]) {
        var index = lineStart

        while index < lineEnd {
            let char = text[index]
            let start = index

            // 行内代码 `code`
            if char == "`" {
                var tempIndex = text.index(after: index)
                while tempIndex < lineEnd && text[tempIndex] != "`" {
                    tempIndex = text.index(after: tempIndex)
                }
                if tempIndex < lineEnd {
                    tempIndex = text.index(after: tempIndex) // 跳过结束的 `
                    tokens.append(makeToken(type: .codeBlock, text: text, start: start, end: tempIndex))
                    index = tempIndex
                    continue
                }
            }

            // 粗体 **text** 或 __text__
            if (char == "*" || char == "_") && index < text.index(before: lineEnd) {
                let next = text[text.index(after: index)]
                if next == char {
                    var tempIndex = text.index(index, offsetBy: 2)
                    while tempIndex < text.index(before: lineEnd) {
                        if text[tempIndex] == char && text[text.index(after: tempIndex)] == char {
                            tempIndex = text.index(tempIndex, offsetBy: 2)
                            tokens.append(makeToken(type: .bold, text: text, start: start, end: tempIndex))
                            index = tempIndex
                            break
                        }
                        tempIndex = text.index(after: tempIndex)
                    }
                    if index != start { continue }
                }
            }

            // 斜体 *text* 或 _text_
            if char == "*" || char == "_" {
                var tempIndex = text.index(after: index)
                while tempIndex < lineEnd {
                    if text[tempIndex] == char {
                        tempIndex = text.index(after: tempIndex)
                        tokens.append(makeToken(type: .italic, text: text, start: start, end: tempIndex))
                        index = tempIndex
                        break
                    }
                    tempIndex = text.index(after: tempIndex)
                }
                if index != start { continue }
            }

            // 链接 [text](url)
            if char == "[" {
                var tempIndex = text.index(after: index)
                var foundClose = false
                while tempIndex < lineEnd {
                    if text[tempIndex] == "]" {
                        foundClose = true
                        break
                    }
                    tempIndex = text.index(after: tempIndex)
                }
                if foundClose && tempIndex < text.index(before: lineEnd) && text[text.index(after: tempIndex)] == "(" {
                    tempIndex = text.index(after: text.index(after: tempIndex))
                    while tempIndex < lineEnd && text[tempIndex] != ")" {
                        tempIndex = text.index(after: tempIndex)
                    }
                    if tempIndex < lineEnd {
                        tempIndex = text.index(after: tempIndex)
                        tokens.append(makeToken(type: .link, text: text, start: start, end: tempIndex))
                        index = tempIndex
                        continue
                    }
                }
            }

            // 图片 ![alt](url)
            if char == "!" && index < text.index(before: lineEnd) && text[text.index(after: index)] == "[" {
                var tempIndex = text.index(index, offsetBy: 2)
                var foundClose = false
                while tempIndex < lineEnd {
                    if text[tempIndex] == "]" {
                        foundClose = true
                        break
                    }
                    tempIndex = text.index(after: tempIndex)
                }
                if foundClose && tempIndex < text.index(before: lineEnd) && text[text.index(after: tempIndex)] == "(" {
                    tempIndex = text.index(after: text.index(after: tempIndex))
                    while tempIndex < lineEnd && text[tempIndex] != ")" {
                        tempIndex = text.index(after: tempIndex)
                    }
                    if tempIndex < lineEnd {
                        tempIndex = text.index(after: tempIndex)
                        tokens.append(makeToken(type: .link, text: text, start: start, end: tempIndex))
                        index = tempIndex
                        continue
                    }
                }
            }

            // URL自动识别
            if char == "h" && text[index...].hasPrefix("http") {
                var tempIndex = index
                while tempIndex < lineEnd && !text[tempIndex].isWhitespace && text[tempIndex] != ")" && text[tempIndex] != "]" {
                    tempIndex = text.index(after: tempIndex)
                }
                if tempIndex > index {
                    tokens.append(makeToken(type: .url, text: text, start: start, end: tempIndex))
                    index = tempIndex
                    continue
                }
            }

            index = text.index(after: index)
        }
    }
}
