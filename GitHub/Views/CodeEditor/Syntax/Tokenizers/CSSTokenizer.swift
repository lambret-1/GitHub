import Foundation

// ==============================================================================
// CSSTokenizer CSS语言词法分析器
// 功能：对CSS代码进行词法分析，识别选择器、属性、值、注释等
// 位置：语法高亮系统的语言词法分析层
// ==============================================================================

class CSSTokenizer: BaseLanguageTokenizer, LanguageTokenizer {
    // MARK: - CSS属性名

    private static let cssProperties: Set<String> = [
        "align-content", "align-items", "align-self", "all", "animation",
        "animation-delay", "animation-direction", "animation-duration",
        "animation-fill-mode", "animation-iteration-count", "animation-name",
        "animation-play-state", "animation-timing-function", "aspect-ratio",
        "backface-visibility", "background", "background-attachment",
        "background-blend-mode", "background-clip", "background-color",
        "background-image", "background-origin", "background-position",
        "background-repeat", "background-size", "border", "border-bottom",
        "border-bottom-color", "border-bottom-left-radius", "border-bottom-right-radius",
        "border-bottom-style", "border-bottom-width", "border-collapse",
        "border-color", "border-image", "border-image-outset", "border-image-repeat",
        "border-image-slice", "border-image-source", "border-image-width",
        "border-left", "border-left-color", "border-left-style", "border-left-width",
        "border-radius", "border-right", "border-right-color", "border-right-style",
        "border-right-width", "border-spacing", "border-style", "border-top",
        "border-top-color", "border-top-left-radius", "border-top-right-radius",
        "border-top-style", "border-top-width", "border-width", "bottom",
        "box-decoration-break", "box-shadow", "box-sizing", "break-after",
        "break-before", "break-inside", "caption-side", "caret-color",
        "clear", "clip", "clip-path", "color", "column-count", "column-fill",
        "column-gap", "column-rule", "column-rule-color", "column-rule-style",
        "column-rule-width", "column-span", "column-width", "columns", "content",
        "counter-increment", "counter-reset", "cursor", "direction", "display",
        "empty-cells", "filter", "flex", "flex-basis", "flex-direction", "flex-flow",
        "flex-grow", "flex-shrink", "flex-wrap", "float", "font", "font-family",
        "font-feature-settings", "font-kerning", "font-language-override",
        "font-size", "font-size-adjust", "font-stretch", "font-style",
        "font-synthesis", "font-variant", "font-variant-alternates",
        "font-variant-caps", "font-variant-east-asian", "font-variant-ligatures",
        "font-variant-numeric", "font-variant-position", "font-weight", "gap",
        "grid", "grid-area", "grid-auto-columns", "grid-auto-flow", "grid-auto-rows",
        "grid-column", "grid-column-end", "grid-column-gap", "grid-column-start",
        "grid-gap", "grid-row", "grid-row-end", "grid-row-gap", "grid-row-start",
        "grid-template", "grid-template-areas", "grid-template-columns",
        "grid-template-rows", "hanging-punctuation", "height", "hyphens",
        "image-orientation", "image-rendering", "image-resolution", "ime-mode",
        "initial-letter", "initial-letter-align", "inline-size", "inset",
        "inset-block", "inset-block-end", "inset-block-start", "inset-inline",
        "inset-inline-end", "inset-inline-start", "isolation", "justify-content",
        "justify-items", "justify-self", "left", "letter-spacing", "line-break",
        "line-height", "line-height-step", "list-style", "list-style-image",
        "list-style-position", "list-style-type", "margin", "margin-block",
        "margin-block-end", "margin-block-start", "margin-bottom", "margin-inline",
        "margin-inline-end", "margin-inline-start", "margin-left", "margin-right",
        "margin-top", "mask", "mask-border", "mask-border-mode", "mask-border-outset",
        "mask-border-repeat", "mask-border-slice", "mask-border-source", "mask-border-width",
        "mask-clip", "mask-composite", "mask-image", "mask-mode", "mask-origin",
        "mask-position", "mask-repeat", "mask-size", "mask-type", "max-block-size",
        "max-height", "max-inline-size", "max-width", "min-block-size", "min-height",
        "min-inline-size", "min-width", "mix-blend-mode", "object-fit", "object-position",
        "offset", "offset-anchor", "offset-distance", "offset-path", "offset-rotate",
        "opacity", "order", "orphans", "outline", "outline-color", "outline-offset",
        "outline-style", "outline-width", "overflow", "overflow-anchor", "overflow-block",
        "overflow-clip-margin", "overflow-inline", "overflow-wrap", "overflow-x",
        "overflow-y", "overscroll-behavior", "overscroll-behavior-block",
        "overscroll-behavior-inline", "overscroll-behavior-x", "overscroll-behavior-y",
        "padding", "padding-block", "padding-block-end", "padding-block-start",
        "padding-bottom", "padding-inline", "padding-inline-end", "padding-inline-start",
        "padding-left", "padding-right", "padding-top", "page-break-after",
        "page-break-before", "page-break-inside", "paint-order", "perspective",
        "perspective-origin", "place-content", "place-items", "place-self",
        "pointer-events", "position", "quotes", "resize", "right", "rotate",
        "row-gap", "ruby-align", "ruby-merge", "ruby-position", "scale",
        "scroll-behavior", "scroll-margin", "scroll-margin-block", "scroll-margin-block-end",
        "scroll-margin-block-start", "scroll-margin-bottom", "scroll-margin-inline",
        "scroll-margin-inline-end", "scroll-margin-inline-start", "scroll-margin-left",
        "scroll-margin-right", "scroll-margin-top", "scroll-padding", "scroll-padding-block",
        "scroll-padding-block-end", "scroll-padding-block-start", "scroll-padding-bottom",
        "scroll-padding-inline", "scroll-padding-inline-end", "scroll-padding-inline-start",
        "scroll-padding-left", "scroll-padding-right", "scroll-padding-top",
        "scroll-snap-align", "scroll-snap-coordinate", "scroll-snap-destination",
        "scroll-snap-points-x", "scroll-snap-points-y", "scroll-snap-stop",
        "scroll-snap-type", "scrollbar-color", "scrollbar-width", "shape-image-threshold",
        "shape-margin", "shape-outside", "tab-size", "table-layout", "text-align",
        "text-align-last", "text-combine-upright", "text-decoration", "text-decoration-color",
        "text-decoration-line", "text-decoration-skip", "text-decoration-skip-ink",
        "text-decoration-style", "text-emphasis", "text-emphasis-color", "text-emphasis-position",
        "text-emphasis-style", "text-indent", "text-justify", "text-orientation",
        "text-overflow", "text-rendering", "text-shadow", "text-size-adjust",
        "text-transform", "text-underline-offset", "text-underline-position", "top",
        "touch-action", "transform", "transform-box", "transform-origin", "transform-style",
        "transition", "transition-delay", "transition-duration", "transition-property",
        "transition-timing-function", "translate", "unicode-bidi", "user-select",
        "vertical-align", "visibility", "white-space", "widows", "width", "will-change",
        "word-break", "word-spacing", "word-wrap", "writing-mode", "z-index"
    ]

    // MARK: - 初始化

    init() {
        super.init(language: .css)
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

            // 注释 /* */
            if char == "/" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "*" {
                let commentStart = index
                index = text.index(index, offsetBy: 2)
                while index < text.endIndex && !(text[index] == "*" && index < text.index(before: text.endIndex) && text[text.index(after: index)] == "/") {
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(index, offsetBy: 2)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: commentStart), length: text.distance(from: commentStart, to: index))
                tokens.append(SyntaxToken(type: .comment, range: range, text: String(text[commentStart..<index])))
                continue
            }

            // 字符串（双引号）
            if char == "\"" {
                let stringStart = index
                index = text.index(after: index)
                while index < text.endIndex && text[index] != "\"" {
                    if text[index] == "\\" {
                        index = text.index(after: index)
                    }
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                tokens.append(SyntaxToken(type: .string, range: range, text: String(text[stringStart..<index])))
                continue
            }

            // 字符串（单引号）
            if char == "'" {
                let stringStart = index
                index = text.index(after: index)
                while index < text.endIndex && text[index] != "'" {
                    if text[index] == "\\" {
                        index = text.index(after: index)
                    }
                    index = text.index(after: index)
                }
                if index < text.endIndex {
                    index = text.index(after: index)
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: stringStart), length: text.distance(from: stringStart, to: index))
                tokens.append(SyntaxToken(type: .string, range: range, text: String(text[stringStart..<index])))
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
                // 单位
                let unitStart = index
                while index < text.endIndex && text[index].isLetter {
                    index = text.index(after: index)
                }
                if unitStart < index {
                    let range = NSRange(location: text.distance(from: text.startIndex, to: unitStart), length: text.distance(from: unitStart, to: index))
                    tokens.append(SyntaxToken(type: .type, range: range, text: String(text[unitStart..<index])))
                }
                let range = NSRange(location: text.distance(from: text.startIndex, to: numberStart), length: text.distance(from: numberStart, to: unitStart))
                tokens.append(SyntaxToken(type: .number, range: range, text: String(text[numberStart..<unitStart])))
                continue
            }

            // 标识符（属性名或选择器）
            if isIdentifierStart(char) || char == "." || char == "#" || char == "@" || char == ":" {
                let wordStart = index
                if char == "." || char == "#" || char == "@" || char == ":" {
                    index = text.index(after: index)
                }
                while index < text.endIndex && (isIdentifierPart(text[index]) || text[index] == "-" || text[index] == ".") {
                    index = text.index(after: index)
                }
                let word = String(text[wordStart..<index])

                // 判断是属性名还是选择器
                var tempIndex = index
                while tempIndex < text.endIndex && text[tempIndex].isWhitespace {
                    tempIndex = text.index(after: tempIndex)
                }

                if tempIndex < text.endIndex && text[tempIndex] == ":" {
                    // 属性名
                    let propName = word.lowercased()
                    let tokenType: SyntaxTokenType = CSSTokenizer.cssProperties.contains(propName) ? .variable : .plain
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: tokenType, range: range, text: word))
                } else if word.hasPrefix("@") {
                    // at规则
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: .keyword, range: range, text: word))
                } else if word.hasPrefix(".") || word.hasPrefix("#") {
                    // 类选择器或ID选择器
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: .function, range: range, text: word))
                } else {
                    // 标签选择器或属性值
                    let range = NSRange(location: text.distance(from: text.startIndex, to: wordStart), length: text.distance(from: wordStart, to: index))
                    tokens.append(SyntaxToken(type: .type, range: range, text: word))
                }
                continue
            }

            // 结构符号
            if char == "{" || char == "}" || char == ":" || char == ";" || char == "," || char == "(" || char == ")" || char == "[" || char == "]" {
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
