import SwiftUI
import UIKit

// ==============================================================================
// CodeEditorTextView 自定义 UITextView 子类
// 功能：仅承载“查找选中文字”的回调；菜单逻辑交给 UITextViewDelegate（iOS16+）
// ==============================================================================

class CodeEditorTextView: UITextView {
    /// 查找选中文字的回调
    var onLookupSelectedText: ((String) -> Void)?
}

// ==============================================================================
// CodeTextView 高性能代码编辑器（带语法高亮）
// ==============================================================================

struct CodeTextView: UIViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    var showLineNumbers: Bool
    @Binding var fontSize: CGFloat
    var onTextChange: ((String) -> Void)?

    // 查找相关回调
    var onSearchResult: ((Int, Int) -> Void)?       // (当前匹配索引, 总匹配数)
    var onLookupSelectedText: ((String) -> Void)?   // 选中文字后点击“🔍查找”的回调

    // 查找配置
    var searchText: String = ""
    var currentMatchIndex: Int = 0
    var isSearchActive: Bool = false

    // 获取选中文字配置
    var getSelectedTextTrigger: Int = 0
    var onSelectedText: ((String) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        // 使用自定义 LayoutManager 绘制行号
        let layoutManager = LineNumberLayoutManager()
        let textStorage = NSTextStorage()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(size: CGSize(width: 0, height: 0))
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        layoutManager.addTextContainer(textContainer)

        // 创建 UITextView（使用自定义子类）
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
        textView.backgroundColor = .systemBackground
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive

        // 设置查找选中文字回调
        textView.onLookupSelectedText = onLookupSelectedText

        // 配置行号 LayoutManager
        let lineNumberFont = UIFont.monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
        layoutManager.lineNumberFont = lineNumberFont
        let calculatedLineNumberWidth = showLineNumbers
            ? LineNumberLayoutManager.calculateLineNumberWidth(for: text, font: lineNumberFont)
            : 0
        let clampedLineNumberWidth = min(max(calculatedLineNumberWidth, 30), 80)
        layoutManager.lineNumberWidth = clampedLineNumberWidth
        textView.textContainerInset = UIEdgeInsets(
            top: 8,
            left: showLineNumbers ? clampedLineNumberWidth + 8 : 8,
            bottom: 8,
            right: 8
        )
        layoutManager.containerInset = textView.textContainerInset

        // 设置初始文本（带语法高亮）
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let highlightedText = SyntaxHighlighter.highlight(text, font: font)
        textStorage.setAttributedString(highlightedText)

        // 保存 coordinator 引用
        context.coordinator.textView = textView
        context.coordinator.fontSize = fontSize
        context.coordinator.fontSizeBinding = _fontSize
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onSelectedText = onSelectedText
        context.coordinator.onLookupSelectedText = onLookupSelectedText

        // 双指缩放手势
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        textView.addGestureRecognizer(pinchGesture)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.isEditable = isEditable

        // 更新查找回调
        if let codeEditorTextView = textView as? CodeEditorTextView {
            codeEditorTextView.onLookupSelectedText = onLookupSelectedText
        }
        context.coordinator.onLookupSelectedText = onLookupSelectedText

        // 更新字体
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        context.coordinator.fontSize = fontSize

        // 更新行号显示
        if let layoutManager = textView.layoutManager as? LineNumberLayoutManager {
            let lineNumberFont = UIFont.monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
            layoutManager.lineNumberFont = lineNumberFont
            let calculatedLineNumberWidth = showLineNumbers
                ? LineNumberLayoutManager.calculateLineNumberWidth(for: textView.text, font: lineNumberFont)
                : 0
            let clampedLineNumberWidth = min(max(calculatedLineNumberWidth, 30), 80)
            layoutManager.lineNumberWidth = clampedLineNumberWidth
            textView.textContainerInset = UIEdgeInsets(
                top: 8,
                left: showLineNumbers ? clampedLineNumberWidth + 8 : 8,
                bottom: 8,
                right: 8
            )
            layoutManager.containerInset = textView.textContainerInset
            layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.text.count))
        }

        // 外部文本变化时更新
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
        var fontSizeBinding: Binding<CGFloat>?
        var isInternalUpdate = false
        var onSearchResult: ((Int, Int) -> Void)?
        var onSelectedText: ((String) -> Void)?
        var onLookupSelectedText: ((String) -> Void)?

        private var highlightWorkItem: DispatchWorkItem?
        private var searchWorkItem: DispatchWorkItem?
        private var searchMatches: [NSRange] = []
        private var currentSearchText: String = ""
        private var isSearching = false
        private var pendingSearchText: String = ""
        private var pendingSearchIndex: Int = 0
        private var lastSelectedTextTrigger: Int = 0

        // 双指缩放
        private var initialFontSize: CGFloat = 14
        private let minFontSize: CGFloat = 8
        private let maxFontSize: CGFloat = 24

        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            _text = text
            self.onTextChange = onTextChange
        }

        // MARK: - iOS 16+ 自定义编辑菜单
        //
        // 菜单顺序：🔍查找 / 复制 / 剪切 / 粘贴 / 全选
        // 手动创建所有菜单项，确保功能完整显示，不依赖系统建议
        @available(iOS 16.0, *)
        func textView(_ textView: UITextView,
                      editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard range.location >= 0,
                  range.location + range.length <= (textView.text as NSString).length
            else { return nil }

            let selectedText = range.length > 0 ? (textView.text as NSString).substring(with: range) : ""
            var actions: [UIMenuElement] = []

            // 🔍查找（仅在有选中文字时显示）
            if !selectedText.isEmpty {
                let lookupAction = UIAction(
                    title: "🔍查找",
                    image: UIImage(systemName: "magnifyingglass")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    self.onLookupSelectedText?(selectedText)
                }
                actions.append(lookupAction)
            }

            // 复制（仅在有选中文字时显示）
            if !selectedText.isEmpty {
                let copyAction = UIAction(
                    title: "复制",
                    image: UIImage(systemName: "doc.on.doc")
                ) { _ in
                    UIPasteboard.general.string = selectedText
                }
                actions.append(copyAction)
            }

            // 剪切（仅在有选中文字且可编辑时显示）
            if !selectedText.isEmpty && textView.isEditable {
                let cutAction = UIAction(
                    title: "剪切",
                    image: UIImage(systemName: "scissors")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    UIPasteboard.general.string = selectedText
                    let mutableText = NSMutableString(string: textView.text)
                    mutableText.deleteCharacters(in: range)
                    textView.text = mutableText as String
                    self.text = textView.text
                    self.onTextChange?(textView.text)
                }
                actions.append(cutAction)
            }

            // 粘贴（仅在剪贴板有文字且可编辑时显示）
            if textView.isEditable, let pasteboardText = UIPasteboard.general.string, !pasteboardText.isEmpty {
                let pasteAction = UIAction(
                    title: "粘贴",
                    image: UIImage(systemName: "doc.on.clipboard")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    let mutableText = NSMutableString(string: textView.text)
                    mutableText.insert(pasteboardText, at: range.location)
                    textView.text = mutableText as String
                    self.text = textView.text
                    self.onTextChange?(textView.text)
                }
                actions.append(pasteAction)
            }

            // 全选（始终显示）
            let selectAllAction = UIAction(
                title: "全选",
                image: UIImage(systemName: "checkmark.circle")
            ) { _ in
                textView.selectedRange = NSRange(location: 0, length: (textView.text as NSString).length)
            }
            actions.append(selectAllAction)

            return UIMenu(children: actions)
        }

        // MARK: - UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            guard !isSearching else { return }

            isInternalUpdate = true
            text = textView.text
            onTextChange?(textView.text)

            highlightWorkItem?.cancel()
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let textView = self.textView else { return }
                self.applySyntaxHighlight(textView: textView)
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)

            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }
        }

        /// 应用语法高亮
        private func applySyntaxHighlight(textView: UITextView) {
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

        func performSearch(text searchText: String, currentIndex: Int) {
            searchWorkItem?.cancel()

            pendingSearchText = searchText
            pendingSearchIndex = currentIndex

            let needsDebounce = (searchText != currentSearchText)

            if needsDebounce {
                let workItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    self.doPerformSearch(text: self.pendingSearchText, currentIndex: self.pendingSearchIndex)
                }
                searchWorkItem = workItem
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
            } else {
                doPerformSearch(text: searchText, currentIndex: currentIndex)
            }
        }

        private func doPerformSearch(text searchText: String, currentIndex: Int) {
            guard let textView = textView, let fullText = textView.text else { return }
            guard !isSearching else { return }

            isSearching = true
            defer { isSearching = false }

            if searchText != currentSearchText {
                currentSearchText = searchText
                searchMatches = []

                var searchRange = fullText.startIndex..<fullText.endIndex
                while let range = fullText.range(of: searchText, options: .caseInsensitive, range: searchRange) {
                    let nsRange = NSRange(range, in: fullText)
                    searchMatches.append(nsRange)
                    searchRange = range.upperBound..<fullText.endIndex
                }
            }

            guard !searchMatches.isEmpty else {
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

            let safeIndex = max(0, min(currentIndex, searchMatches.count - 1))

            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let highlightedText = SyntaxHighlighter.highlight(fullText, font: font)
            let mutableAttributedString = NSMutableAttributedString(attributedString: highlightedText)

            for (index, range) in searchMatches.enumerated() {
                if index == safeIndex {
                    mutableAttributedString.addAttribute(
                        .backgroundColor,
                        value: UIColor.orange.withAlphaComponent(0.5),
                        range: range
                    )
                } else {
                    mutableAttributedString.addAttribute(
                        .backgroundColor,
                        value: UIColor.yellow.withAlphaComponent(0.3),
                        range: range
                    )
                }
            }

            isInternalUpdate = true
            textView.textStorage.setAttributedString(mutableAttributedString)

            let currentRange = searchMatches[safeIndex]
            textView.selectedRange = currentRange
            textView.scrollRangeToVisible(currentRange)

            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }

            onSearchResult?(safeIndex + 1, searchMatches.count)
        }

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

        func resetSearch() {
            searchWorkItem?.cancel()
            currentSearchText = ""
            searchMatches = []
            clearSearchHighlight()
        }

        // MARK: - 选中文字

        func checkSelectedTextTrigger(trigger: Int) {
            guard trigger != lastSelectedTextTrigger else { return }
            lastSelectedTextTrigger = trigger

            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            guard selectedRange.length > 0 else { return }

            let fullText = textView.text as NSString
            let selectedText = fullText.substring(with: selectedRange)
            onSelectedText?(selectedText)
        }

        // MARK: - 双指缩放

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard let textView = textView else { return }

            switch gesture.state {
            case .began:
                initialFontSize = fontSize

            case .changed:
                let newFontSize = initialFontSize * gesture.scale
                let clampedFontSize = min(max(newFontSize, minFontSize), maxFontSize)
                guard abs(clampedFontSize - fontSize) > 0.1 else { return }

                fontSize = clampedFontSize
                fontSizeBinding?.wrappedValue = clampedFontSize

                let font = UIFont.monospacedSystemFont(ofSize: clampedFontSize, weight: .regular)
                textView.font = font

                if let layoutManager = textView.layoutManager as? LineNumberLayoutManager {
                    let lineNumberFont = UIFont.monospacedSystemFont(ofSize: clampedFontSize - 2, weight: .regular)
                    layoutManager.lineNumberFont = lineNumberFont
                    let calculatedWidth = LineNumberLayoutManager.calculateLineNumberWidth(
                        for: textView.text,
                        font: lineNumberFont
                    )
                    let clampedWidth = min(max(calculatedWidth, 30), 80)
                    layoutManager.lineNumberWidth = clampedWidth
                    textView.textContainerInset = UIEdgeInsets(
                        top: 8,
                        left: clampedWidth + 8,
                        bottom: 8,
                        right: 8
                    )
                    layoutManager.containerInset = textView.textContainerInset
                }

                applySyntaxHighlight(textView: textView)

            case .ended, .cancelled, .failed:
                break

            default:
                break
            }
        }
    }
}