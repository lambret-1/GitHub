import UIKit

// ==============================================================================
// LineNumberLayoutManager 自定义行号绘制
// 功能：通过自定义NSLayoutManager在文本左侧绘制行号，使用enumerateLineFragments精确对齐
// 关键：使用usedRect（实际使用区域）而非lineRect（包含行间距）来计算行号位置
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

        // 绘制行号背景（从x=0开始，覆盖整个textView宽度的左侧）
        let lineNumberRect = CGRect(
            x: 0,
            y: 0,
            width: lineNumberWidth,
            height: textContainer.size.height + 100 // 额外高度确保滚动时背景覆盖
        )
        lineNumberBackgroundColor.setFill()
        context?.fill(lineNumberRect)

        // 绘制分隔线
        let separatorRect = CGRect(
            x: lineNumberWidth - 0.5,
            y: 0,
            width: 0.5,
            height: textContainer.size.height + 100
        )
        UIColor.separator.setFill()
        context?.fill(separatorRect)

        // 计算起始行号
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        var lineNumber = 1
        if charRange.location > 0 {
            if let nsString = textStorage?.string as NSString? {
                lineNumber = nsString.substring(to: charRange.location).components(separatedBy: .newlines).count
            }
        }

        // 使用enumerateLineFragments精确遍历每一行
        // 关键：使用usedRect（实际使用区域）而非lineRect（包含行间距）来计算行号位置
        enumerateLineFragments(forGlyphRange: glyphsToShow) { lineRect, usedRect, textContainer, glyphRange, stop in
            let charRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            // 检查这一行是否是新行的开始（不是自动换行的续行）
            var isNewline = true
            if charRange.location > 0 {
                if let nsString = self.textStorage?.string as NSString? {
                    let prevChar = nsString.character(at: charRange.location - 1)
                    isNewline = (prevChar == 10) // 10 is newline
                }
            }

            if isNewline {
                // 绘制行号，使用usedRect精确对齐文本行
                // usedRect是文本实际使用的区域，不包含行间距，行号与文本精确对齐
                let lineNumberString = "\(lineNumber)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: self.lineNumberFont,
                    .foregroundColor: self.lineNumberColor
                ]
                let stringSize = lineNumberString.size(withAttributes: attributes)

                // 关键：使用usedRect.origin.y而非lineRect.origin.y
                // usedRect是文本实际绘制区域，行号与文本基线精确对齐
                let stringRect = CGRect(
                    x: self.lineNumberWidth - stringSize.width - 6,
                    y: usedRect.origin.y + (usedRect.height - stringSize.height) / 2,
                    width: stringSize.width,
                    height: stringSize.height
                )
                lineNumberString.draw(in: stringRect, withAttributes: attributes)

                lineNumber += 1
            }
        }

        context?.restoreGState()
    }
}
