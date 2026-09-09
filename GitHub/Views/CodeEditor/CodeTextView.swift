import SwiftUI
import UIKit

// ==============================================================================
// CodeTextView 高性能代码编辑器（带语法高亮）
// 功能：基于UITextView+自定义LineNumberLayoutManager+SyntaxHighlighter
// 优势：原生UITextView内部使用按需加载，内存占用低，滚动流畅，语法高亮
// ==============================================================================

struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var showLineNumbers: Bool
    var fontSize: CGFloat
    var onTextChange: ((String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        // 使用自定义LayoutManager绘制行号
        let layoutManager = LineNumberLayoutManager()
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: 0, height: 0))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        // 创建UITextView
        let textView = UITextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        textView.textContainerInset = UIEdgeInsets(top: 8, left: showLineNumbers ? 48 : 8, bottom: 8, right: 8)
        textView.backgroundColor = .systemBackground
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive

        // 配置行号LayoutManager
        layoutManager.lineNumberFont = .monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
        layoutManager.lineNumberWidth = showLineNumbers ? 40 : 0
        // 设置containerInset，用于行号位置计算
        layoutManager.containerInset = textView.textContainerInset

        // 设置初始文本（带语法高亮）
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let highlightedText = SyntaxHighlighter.highlight(text, font: font)
        textStorage.setAttributedString(highlightedText)

        // 保存coordinator引用，用于后续更新
        context.coordinator.textView = textView
        context.coordinator.fontSize = fontSize

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 更新可编辑状态
        textView.isEditable = isEditable

        // 更新字体
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        context.coordinator.fontSize = fontSize

        // 更新行号显示
        if let layoutManager = textView.layoutManager as? LineNumberLayoutManager {
            layoutManager.lineNumberWidth = showLineNumbers ? 40 : 0
            layoutManager.lineNumberFont = .monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
            textView.textContainerInset = UIEdgeInsets(top: 8, left: showLineNumbers ? 48 : 8, bottom: 8, right: 8)
            // 更新containerInset，用于行号位置计算
            layoutManager.containerInset = textView.textContainerInset
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.text.count))
        }

        // 只在外部文本不同时更新（避免循环更新）
        if textView.text != text && !context.coordinator.isInternalUpdate {
            let selectedRange = textView.selectedRange
            let highlightedText = SyntaxHighlighter.highlight(text, font: font)
            textView.textStorage.setAttributedString(highlightedText)
            textView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onTextChange: ((String) -> Void)?
        weak var textView: UITextView?
        var fontSize: CGFloat = 14
        var isInternalUpdate = false
        private var highlightWorkItem: DispatchWorkItem?

        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            _text = text
            self.onTextChange = onTextChange
        }

        func textViewDidChange(_ textView: UITextView) {
            isInternalUpdate = true
            text = textView.text
            onTextChange?(textView.text)

            // 防抖处理：延迟300ms后重新应用语法高亮，避免每次按键都重新高亮
            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let textView = self.textView else { return }
                self.applySyntaxHighlight(textView: textView)
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)

            // 延迟重置isInternalUpdate
            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }
        }

        /// 应用语法高亮
        private func applySyntaxHighlight(textView: UITextView) {
            let selectedRange = textView.selectedRange
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            guard let currentText = textView.text else { return }
            let highlightedText = SyntaxHighlighter.highlight(currentText, font: font)

            isInternalUpdate = true
            textView.textStorage.setAttributedString(highlightedText)
            textView.selectedRange = selectedRange

            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }
        }
    }
}
