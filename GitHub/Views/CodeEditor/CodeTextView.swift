import SwiftUI
import UIKit

// ==============================================================================
// CodeEditorTextView 自定义UITextView子类
// 功能：自定义选中文字后的编辑菜单，将"搜索网页"替换为"🔍查找"
// 实现：通过canPerformAction移除不需要的系统菜单项，只保留复制/剪切/粘贴，
//       再通过UIMenuController添加"🔍查找"，确保显示在主菜单中不被折叠
// ==============================================================================

class CodeEditorTextView: UITextView {
    /// 查找选中文字的回调
    var onLookupSelectedText: ((String) -> Void)?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // 只移除"搜索网页"选项，保留其他所有系统菜单项
        // "搜索网页"的 selector 是私有 API _lookup:
        if action == Selector(("_lookup:")) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }

    /// 自定义查找方法
    @objc func lookupSelectedText(_ sender: Any?) {
        guard let selectedTextRange = selectedTextRange,
              let selectedText = text(in: selectedTextRange),
              !selectedText.isEmpty else {
            return
        }
        onLookupSelectedText?(selectedText)
    }
}

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

    // 查找相关回调
    var onSearchResult: ((Int, Int) -> Void)? // (当前匹配索引, 总匹配数)
    var onLookupSelectedText: ((String) -> Void)? // 选中文字后点击查找菜单的回调

    // 查找配置
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var isSearchActive: Bool = false

    // 获取选中文字配置
    var getSelectedTextTrigger: Int = 0
    var onSelectedText: ((String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        // 使用自定义LayoutManager绘制行号
        let layoutManager = LineNumberLayoutManager()
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: 0, height: 0))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        // 创建UITextView（使用自定义子类，支持自定义编辑菜单）
        let textView = CodeEditorTextView(frame: .zero, textContainer: textContainer)
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

        // 设置自定义编辑菜单：将"搜索网页"替换为"🔍查找"
        // 通过canPerformAction只保留复制/剪切/粘贴，减少菜单项数量
        // 确保"🔍查找"显示在主菜单中，不被折叠到"更多"选项
        let lookupMenuItem = UIMenuItem(title: "🔍查找", action: #selector(CodeEditorTextView.lookupSelectedText(_:)))
        UIMenuController.shared.menuItems = [lookupMenuItem]

        // 设置查找选中文字回调
        textView.onLookupSelectedText = onLookupSelectedText

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
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onSelectedText = onSelectedText

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // 更新可编辑状态
        textView.isEditable = isEditable

        // 更新查找选中文字回调
        if let codeEditorTextView = textView as? CodeEditorTextView {
            codeEditorTextView.onLookupSelectedText = onLookupSelectedText
        }

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

        // 处理查找
        if isSearchActive && !searchText.isEmpty {
            context.coordinator.performSearch(text: searchText, currentIndex: currentMatchIndex)
        } else if !isSearchActive {
            context.coordinator.resetSearch()
        }

        // 处理选中文字获取
        context.coordinator.checkSelectedTextTrigger(trigger: getSelectedTextTrigger)
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
        var onSearchResult: ((Int, Int) -> Void)?
        var onSelectedText: ((String) -> Void)?
        private var highlightWorkItem: DispatchWorkItem?
        private var searchWorkItem: DispatchWorkItem?
        private var searchMatches: [NSRange] = []
        private var currentSearchText: String = ""
        private var isSearching = false // 防重入标志，防止查找触发的textStorage修改导致无限循环
        private var pendingSearchText: String = ""
        private var pendingSearchIndex: Int = 0
        private var lastSelectedTextTrigger: Int = 0

        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            _text = text
            self.onTextChange = onTextChange
        }

        func textViewDidChange(_ textView: UITextView) {
            // 如果是查找高亮触发的修改，不更新text，避免无限循环
            guard !isSearching else { return }

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
            // 如果正在查找，不应用纯语法高亮，避免覆盖查找高亮
            guard !isSearching else { return }

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

        // MARK: - 查找功能

        /// 执行查找
        /// 智能判断：如果只是currentIndex变化（上下按钮点击），立即执行；
        /// 如果搜索文本变化（输入框输入），使用200ms防抖提高输入响应速度
        func performSearch(text searchText: String, currentIndex: Int) {
            // 取消之前的查找任务
            searchWorkItem?.cancel()

            // 保存待查找的参数
            pendingSearchText = searchText
            pendingSearchIndex = currentIndex

            // 判断是否需要防抖：搜索文本变化时使用防抖，只是索引变化时立即执行
            let needsDebounce = (searchText != currentSearchText)

            if needsDebounce {
                // 延迟200ms执行查找，提高输入框响应速度（用于输入框输入）
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.doPerformSearch(text: self.pendingSearchText, currentIndex: self.pendingSearchIndex)
                }
                searchWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
            } else {
                // 立即执行查找（用于上下按钮点击，只改变当前匹配索引）
                doPerformSearch(text: searchText, currentIndex: currentIndex)
            }
        }

        /// 实际执行查找
        private func doPerformSearch(text searchText: String, currentIndex: Int) {
            guard let textView = textView, let fullText = textView.text else { return }
            guard !isSearching else { return }

            // 设置防重入标志
            isSearching = true
            defer { isSearching = false }

            // 如果搜索文本变化，重新查找所有匹配
            if searchText != currentSearchText {
                currentSearchText = searchText
                searchMatches = []

                // 查找所有匹配项（不区分大小写）
                var searchRange = fullText.startIndex..<fullText.endIndex
                while let range = fullText.range(of: searchText, options: .caseInsensitive, range: searchRange) {
                    let nsRange = NSRange(range, in: fullText)
                    searchMatches.append(nsRange)
                    searchRange = range.upperBound..<fullText.endIndex
                }
            }

            guard !searchMatches.isEmpty else {
                // 无匹配结果，只应用语法高亮
                let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
                let highlightedText = SyntaxHighlighter.highlight(fullText, font: font)
                isInternalUpdate = true
                textView.textStorage.setAttributedString(highlightedText)
                DispatchQueue.main.async { [weak self] in
                    self?.isInternalUpdate = false
                }
                onSearchResult?(0, 0)
                return
            }

            // 确保当前索引在有效范围内
            let safeIndex = max(0, min(currentIndex, searchMatches.count - 1))

            // 创建带语法高亮和查找高亮的完整attributed string
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let highlightedText = SyntaxHighlighter.highlight(fullText, font: font)
            let mutableAttributedString = NSMutableAttributedString(attributedString: highlightedText)

            for (index, range) in searchMatches.enumerated() {
                if index == safeIndex {
                    // 当前匹配项：橙色背景
                    mutableAttributedString.addAttribute(.backgroundColor, value: UIColor.orange.withAlphaComponent(0.5), range: range)
                } else {
                    // 其他匹配项：黄色背景
                    mutableAttributedString.addAttribute(.backgroundColor, value: UIColor.yellow.withAlphaComponent(0.3), range: range)
                }
            }

            // 保存当前选中范围
            let selectedRange = textView.selectedRange

            isInternalUpdate = true
            textView.textStorage.setAttributedString(mutableAttributedString)

            // 恢复选中范围，并设置当前匹配项为选中范围
            let currentRange = searchMatches[safeIndex]
            textView.selectedRange = currentRange

            // 滚动到当前匹配项，确保光标跟随
            textView.scrollRangeToVisible(currentRange)

            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }

            // 回调查找结果
            onSearchResult?(safeIndex + 1, searchMatches.count)
        }

        /// 清除查找高亮（只清除高亮，不重置查找状态）
        func clearSearchHighlight() {
            guard let textView = textView, let fullText = textView.text else { return }
            guard !isSearching else { return }

            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let highlightedText = SyntaxHighlighter.highlight(fullText, font: font)

            isInternalUpdate = true
            textView.textStorage.setAttributedString(highlightedText)

            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }
        }

        /// 重置查找状态（退出查找模式时调用）
        func resetSearch() {
            // 取消待执行的查找任务
            searchWorkItem?.cancel()

            currentSearchText = ""
            searchMatches = []
            clearSearchHighlight()
        }

        // MARK: - 选中文字

        /// 检查选中文字触发器，当触发器变化时获取选中文字
        func checkSelectedTextTrigger(trigger: Int) {
            guard trigger != lastSelectedTextTrigger else { return }
            lastSelectedTextTrigger = trigger

            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            guard selectedRange.length > 0 else { return }

            // 使用NSString获取选中文字，更简单可靠
            let fullText = textView.text as NSString
            let selectedText = fullText.substring(with: selectedRange)
            onSelectedText?(selectedText)
        }
    }
}
