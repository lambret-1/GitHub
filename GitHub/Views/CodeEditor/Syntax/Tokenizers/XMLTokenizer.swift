import Foundation

// ==============================================================================
// XMLTokenizer XML语言词法分析器
// 功能：对XML代码进行词法分析，识别标签、属性、字符串、注释等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class XMLTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - 初始化

    init() {
        super.init(language: .xml)
    }

    // MARK: - 词法分析

    func tokenize(_ text: String) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var index = text.startIndex

        while index < text.endIndex {
            let char = text[index]
            let start = index

            // 注释 <!-- -->
            if char == "<" && text[index...].hasPrefix("<!--") {
                let commentStart = index
                index = text.index(index, offsetBy: 4)
                while index < text.endIndex && !text[index...].hasPrefix("-->") {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(index, offsetBy: 3)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 处理指令 <?xml ... ?>
            if char == "<" && text[index...].hasPrefix("<?") {
                let tagStart = index
                while index < text.endIndex && !text[index...].hasPrefix("?>") {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(index, offsetBy: 2)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: tagStart), length: text.distance(from: tagStart, to: index))
                tokens.append(SyntaxToken(type: .preprocessor, range: range, text: String(text[tagStart..<index])))
                continue
            }

            // 开始标签 <tag ...>
            if char == "<" {
                let tagStart = index
                index = text.index(after: index)

                // 标签名
                let nameStart = index
                while index < text.endIndex && !text[index].isWhitespace && text[index] != ">" && text[index] != "/" {
                    index = text.index(after: index)
                }
                let nameEnd = index

                if nameStart < nameEnd {
                    let range = NSRange(location: text.distance(from: text.startIndex, to: nameStart), length: text.distance(from: nameStart, to: nameEnd))
                    tokens.append(SyntaxToken(type: .keyword, range: range, text: String(text[nameStart..<nameEnd])))
                }

                // 属性
                while index < text.endIndex && text[index] != ">" {
                    if text[index].isWhitespace {
                        index = text.index(after: index)
                        continue
                    }

                    // 属性名
                    let attrStart = index
                    while index < text.endIndex && !text[index].isWhitespace && text[index] != "=" && text[index] != ">" {
                        index = text.index(after: index)
                    }
                    let attrEnd = index

                    if attrStart < attrEnd {
                        let range = NSRange(location: text.distance(from: text.startIndex, to: attrStart), length: text.distance(from: attrStart, to: attrEnd))
                        tokens.append(SyntaxToken(type: .variable, range: range, text: String(text[attrStart..<attrEnd])))
                    }

                    // 等号
                    if index < text.endIndex && text[index] == "=" {
                        let range = NSRange(location: text.distance(from: text.startIndex, to: index), length: 1)
                        tokens.append(SyntaxToken(type: .operatorSymbol, range: range, text: "="))
                        index = text.index(after: index)
                    }

                    // 属性值
                    if index < text.endIndex && (text[index] == "\"" || text[index] == "'") {
                        let quote = text[index]
                        let valueStart = index
                        index = text.index(after: index)
                        while index < text.endIndex && text[index] != quote {
                            index = text.index(after: index)
                        }
                        if index < text.endIndex {
                            index = text.index(after: index)
                        }
                        let range = NSRange(location: text.distance(from: text.startIndex, to: valueStart), length: text.distance(from: valueStart, to: index))
                        tokens.append(SyntaxToken(type: .string, range: range, text: String(text[valueStart..<index])))
                    }
                }

                // 结束标签 > 或 />
                if index < text.endIndex {
                    let range = NSRange(location: text.distance(from: text.startIndex, to: index), length: text[index] == "/" ? 2 : 1)
                    tokens.append(SyntaxToken(type: .keyword, range: range, text: text[index] == "/" ? "/>" : ">"))
                    index = text.index(index, offsetBy: text[index] == "/" ? 2 : 1)
                }
                continue
            }

            // 结束标签 </tag>
            if char == "<" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "/" {
                let tagStart = index
                while index < text.endIndex && text[index] != ">" {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: tagStart), length: text.distance(from: tagStart, to: index))
                tokens.append(SyntaxToken(type: .keyword, range: range, text: String(text[tagStart..<index])))
                continue
            }

            // 文本内容
            let textStart = index
            while index < text.endIndex && text[index] != "<" {
                index = text.index(after: index)
            }
            if textStart < index {
                let range = NSRange(location: text.distance(from: text.startIndex, to: textStart), length: text.distance(from: textStart, to: index))
                tokens.append(SyntaxToken(type: .plain, range: range, text: String(text[textStart..<index])))
            }
        }

        return tokens
    }
}
