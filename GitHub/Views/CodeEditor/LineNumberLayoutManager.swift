import UIKit

// ==============================================================================
// LineNumberLayoutManager 自定义行号绘制
// 功能：通过自定义NSLayoutManager在文本左侧绘制行号，性能远超SwiftUI的ForEach
// ==============================================================================

class LineNumberLayoutManager: NSLayoutManager {
    // 行号区域宽度
    var lineNumberWidth: CGFloat = 40
    // 行号字体
    var lineNumberFont: UIFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    // 行号颜色
    var lineNumberColor: UIColor = .secondaryLabel
    // 行号背景颜色
    var lineNumberBackgroundColor: UIColor = .systemGray6

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let textContainer = textContainers.first else { return }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        // 绘制行号背景
        let lineNumberRect = CGRect(
            x: origin.x,
            y: origin.y,
            width: lineNumberWidth,
            height: textContainer.size.height
        )
        lineNumberBackgroundColor.setFill()
        context?.fill(lineNumberRect)

        // 绘制分隔线
        let separatorRect = CGRect(
            x: origin.x + lineNumberWidth - 0.5,
            y: origin.y,
            width: 0.5,
            height: textContainer.size.height
        )
        UIColor.separator.setFill()
        context?.fill(separatorRect)

        // 绘制行号
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        var lineNumber = 1

        // 计算起始行号
        if charRange.location > 0 {
            let nsString = textStorage?.string as NSString?
            if let nsString = nsString {
                lineNumber = nsString.substring(to: charRange.location).components(separatedBy: .newlines).count
            }
        }

        // 遍历每一行绘制行号
        textStorage?.string.enumerateSubstrings(in: charRange, options: [.byLines, .substringNotRequired]) { _, _, _, stop in
            // 获取当前行的行矩形
            let lineRect = self.lineRect(forCharacterIndex: charRange.location, in: textContainer)

            // 绘制行号
            let lineNumberString = "\(lineNumber)" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: self.lineNumberFont,
                .foregroundColor: self.lineNumberColor
            ]
            let stringSize = lineNumberString.size(withAttributes: attributes)
            let stringRect = CGRect(
                x: origin.x + self.lineNumberWidth - stringSize.width - 6,
                y: lineRect.origin.y + (lineRect.height - stringSize.height) / 2,
                width: stringSize.width,
                height: stringSize.height
            )
            lineNumberString.draw(in: stringRect, withAttributes: attributes)

            lineNumber += 1
        }

        context?.restoreGState()
    }

    // 获取指定字符索引所在行的矩形
    private func lineRect(forCharacterIndex charIndex: Int, in textContainer: NSTextContainer) -> CGRect {
        let glyphRange = glyphRange(forCharacterRange: NSRange(location: charIndex, length: 1), actualCharacterRange: nil)
        let lineRect = lineFragmentRect(forGlyphAt: glyphRange.location, effectiveRange: nil)
        return lineRect
    }
}
