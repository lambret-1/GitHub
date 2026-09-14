import UIKit

// ==============================================================================
// HighlightEngine 高亮引擎
// 功能：根据Token列表应用语法高亮颜色到NSMutableAttributedString
// 位置：语法高亮系统的高亮引擎层
// ==============================================================================

class HighlightEngine {
    static let shared = HighlightEngine()

    private init() {}

    // MARK: - 应用高亮

    /// 根据Token列表应用语法高亮
    /// - Parameters:
    ///   - text: 原始文本
    ///   - tokens: 语法Token列表
    ///   - font: 基础字体
    ///   - theme: 语法主题
    /// - Returns: 带语法高亮的NSAttributedString
    func applyHighlight(text: String, tokens: [SyntaxToken], font: UIFont, theme: SyntaxTheme) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: text.utf16.count)

        // 设置基础字体和颜色
        attributedString.addAttribute(.font, value: font, range: fullRange)
        attributedString.addAttribute(.foregroundColor, value: theme.plainTextColor, range: fullRange)

        // 应用每个Token的颜色
        for token in tokens {
            // 确保Token范围有效
            guard token.range.location + token.range.length <= text.utf16.count else {
                continue
            }
            let color = theme.color(for: token.type)
            attributedString.addAttribute(.foregroundColor, value: color, range: token.range)

            // 特殊处理：粗体
            if token.type == .bold {
                let boldFont = UIFont.monospacedSystemFont(ofSize: font.pointSize, weight: .bold)
                attributedString.addAttribute(.font, value: boldFont, range: token.range)
            }

            // 特殊处理：斜体
            if token.type == .italic {
                // iOS系统字体不支持斜体等宽字体，使用倾斜变换模拟
                let obliqueFont = font
                attributedString.addAttribute(.font, value: obliqueFont, range: token.range)
                // 添加倾斜效果
                let obliqueTransform = CGAffineTransform(a: 1, b: 0, c: 0.2, d: 1, tx: 0, ty: 0)
                attributedString.addAttribute(.obliqueness, value: 0.2, range: token.range)
            }

            // 特殊处理：链接
            if token.type == .link || token.type == .url {
                attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: token.range)
            }

            // 特殊处理：标题（加粗+增大字号）
            if token.type == .heading {
                let headingFont = UIFont.monospacedSystemFont(ofSize: font.pointSize + 2, weight: .bold)
                attributedString.addAttribute(.font, value: headingFont, range: token.range)
            }

            // 特殊处理：代码块（背景色）
            if token.type == .codeBlock {
                let codeFont = UIFont.monospacedSystemFont(ofSize: font.pointSize - 1, weight: .regular)
                attributedString.addAttribute(.font, value: codeFont, range: token.range)
                attributedString.addAttribute(.backgroundColor, value: theme.backgroundColor.withAlphaComponent(0.3), range: token.range)
            }
        }

        return attributedString
    }

    // MARK: - 增量高亮（性能优化）

    /// 增量高亮：仅重新高亮修改区域附近的Token
    /// - Parameters:
    ///   - text: 新文本
    ///   - oldTokens: 旧Token列表
    ///   - changedRange: 修改范围
    ///   - font: 基础字体
    ///   - theme: 语法主题
    ///   - tokenizer: 词法分析器
    /// - Returns: 新的Token列表
    func incrementalHighlight(
        text: String,
        oldTokens: [SyntaxToken],
        changedRange: NSRange,
        font: UIFont,
        theme: SyntaxTheme,
        tokenizer: LanguageTokenizer
    ) -> [SyntaxToken] {
        // 简单实现：重新分析整个文本
        // 后续可以优化为仅分析修改区域附近的行
        return tokenizer.tokenize(text)
    }

    // MARK: - 性能监控

    /// 高亮性能监控回调
    var performanceCallback: ((TimeInterval, Int) -> Void)?

    /// 带性能监控的高亮
    func applyHighlightWithPerformance(
        text: String,
        tokens: [SyntaxToken],
        font: UIFont,
        theme: SyntaxTheme
    ) -> NSAttributedString {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = applyHighlight(text: text, tokens: tokens, font: font, theme: theme)
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        performanceCallback?(elapsed, tokens.count)
        return result
    }
}
