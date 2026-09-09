import UIKit

// ==============================================================================
// LineNumberLayoutManager 自定义行号绘制
// 功能：通过自定义NSLayoutManager在文本左侧绘制行号
// 关键：考虑textContainerInset，使用lineRect精确计算行号位置，正确处理自动换行
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
    // textView的textContainerInset，用于计算行号位置偏移
    var containerInset: UIEdgeInsets = .zero

    override func drawBackground(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
        super.drawBackground(forGlyphRange: glyphsToShow, at: origin)

        guard let textContainer = textContainers.first else { return }

        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()

        // 绘制行号背景（从x=0开始，覆盖整个textView左侧）
        // 高度需要包含containerInset.top和containerInset.bottom
        let totalHeight = textContainer.size.height + containerInset.top + containerInset.bottom + 100
        let lineNumberRect = CGRect(
            x: 0,
            y: 0,
            width: lineNumberWidth,
            height: totalHeight
        )
        lineNumberBackgroundColor.setFill()
        context?.fill(lineNumberRect)

        // 绘制分隔线
        let separatorRect = CGRect(
            x: lineNumberWidth - 0.5,
            y: 0,
            width: 0.5,
            height: totalHeight
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
        enumerateLineFragments(forGlyphRange: glyphsToShow) { lineRect, usedRect, textContainer, glyphRange, stop in
            let charRange = self.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

            // 检查这一行是否是新行的开始（不是自动换行的续行）
            // 关键：检查当前行第一个字符的前一个字符是否是换行符
            var isNewline = true
            if charRange.location > 0 {
                if let nsString = self.textStorage?.string as NSString? {
                    let prevChar = nsString.character(at: charRange.location - 1)
                    // 10是换行符\n，13是回车符\r
                    isNewline = (prevChar == 10 || prevChar == 13)
                }
            }

            if isNewline {
                // 绘制行号，使用lineRect精确计算位置
                // 关键：行号y坐标 = containerInset.top + lineRect.origin.y + (lineRect.height - stringSize.height) / 2
                // containerInset.top是textView的顶部内边距，lineRect是相对于textContainer的坐标
                let lineNumberString = "\(lineNumber)" as NSString
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: self.lineNumberFont,
                    .foregroundColor: self.lineNumberColor
                ]
                let stringSize = lineNumberString.size(withAttributes: attributes)

                // 行号x坐标：从行号区域右侧向左对齐
                let stringX = self.lineNumberWidth - stringSize.width - 6
                // 行号y坐标：containerInset.top + lineRect.origin.y + 垂直居中偏移
                let stringY = self.containerInset.top + lineRect.origin.y + (lineRect.height - stringSize.height) / 2

                let stringRect = CGRect(
                    x: stringX,
                    y: stringY,
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
