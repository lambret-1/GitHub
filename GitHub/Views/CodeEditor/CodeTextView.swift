import SwiftUI
import UIKit

// ==============================================================================
// CodeTextView 高性能代码编辑器
// 功能：基于UITextView+自定义LineNumberLayoutManager，顺畅打开1MB+大文件
// 优势：原生UITextView内部使用按需加载，内存占用低，滚动流畅
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

        // 设置初始文本
        textView.text = text

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 只在文本不同时更新，避免循环更新
        if textView.text != text {
            let selectedRange = textView.selectedRange
            textView.text = text
            textView.selectedRange = selectedRange
        }

        // 更新可编辑状态
        textView.isEditable = isEditable

        // 更新字体
        textView.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)

        // 更新行号显示
        if let layoutManager = textView.layoutManager as? LineNumberLayoutManager {
            layoutManager.lineNumberWidth = showLineNumbers ? 40 : 0
            layoutManager.lineNumberFont = .monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
            textView.textContainerInset = UIEdgeInsets(top: 8, left: showLineNumbers ? 48 : 8, bottom: 8, right: 8)
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.text.count))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onTextChange: onTextChange)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        var onTextChange: ((String) -> Void)?

        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            _text = text
            self.onTextChange = onTextChange
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
            onTextChange?(textView.text)
        }
    }
}
