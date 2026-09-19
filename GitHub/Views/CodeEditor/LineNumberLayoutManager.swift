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

    // MARK: - 换行符位置缓存（大文件性能优化）
    // 预计算所有换行符的位置，使用二分查找计算行号，避免每次滚动都遍历整个文件
    private var newlinePositions: [Int]?
    private var cachedTextHash: Int?

    /// 预计算换行符位置（在文本加载后调用一次）
    func precomputeNewlinePositions() {
        guard let text = textStorage?.string else { return }
        let hash = text.hashValue
        if hash == cachedTextHash && newlinePositions != nil {
            return // 缓存有效，无需重新计算
        }

        var positions: [Int] = []
        let nsString = text as NSString
        let length = nsString.length
        for i in 0..<length {
            let char = nsString.character(at: i)
            if char == 10 || char == 13 { // 10是\n，13是\r
                positions.append(i)
            }
        }
        newlinePositions = positions
        cachedTextHash = hash
    }

    /// 使用二分查找计算指定位置的行号
    private func lineNumber(for position: Int) -> Int {
        guard let positions = newlinePositions else {
            // 缓存未就绪，回退到原始方法
            if position == 0 { return 1 }
            if let nsString = textStorage?.string as NSString? {
                var count = 1
                for i in 0..<position {
                    let char = nsString.character(at: i)
                    if char == 10 || char == 13 {
                        count += 1
                    }
                }
                return count
            }
            return 1
        }

        // 二分查找：找到最后一个小于position的换行符的索引
        var left = 0
        var right = positions.count
        while left < right {
            let mid = (left + right) / 2
            if positions[mid] < position {
                left = mid + 1
            } else {
                right = mid
            }
        }
        return left + 1 // 行号从1开始
    }

    // MARK: - 计算自适应行号列宽

    /// 根据文本内容和字体计算自适应的行号列宽
    /// - Parameters:
    ///   - text: 文本内容
    ///   - font: 行号字体
    /// - Returns: 自适应的行号列宽
    static func calculateLineNumberWidth(for text: String, font: UIFont) -> CGFloat {
        // 计算行数
        let lineCount = text.components(separatedBy: .newlines).count
        // 最大行号字符串
        let maxLineNumber = "\(lineCount)" as NSString
        // 计算行号字符串宽度
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let stringWidth = maxLineNumber.size(withAttributes: attributes).width
        // 行号列宽 = 字符串宽度 + 左右边距（各6pt）+ 分隔线（0.5pt）
        return stringWidth + 12 + 0.5
    }

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

        // 预计算换行符位置（大文件性能优化，只在第一次或文本变化时计算）
        precomputeNewlinePositions()

        // 计算起始行号（使用二分查找，O(log n)复杂度）
        let charRange = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
        var lineNumber = lineNumber(for: charRange.location)

        // 使用enumerateLineFragments精确遍历每一行
        enumerateLineFragments(forGlyphRange: glyphsToShow) { lineRect, _, _, glyphRange, _ in
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
