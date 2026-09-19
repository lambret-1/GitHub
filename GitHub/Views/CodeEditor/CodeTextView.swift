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
    // 文件名（用于语法高亮语言检测）
    var fileName: String = ""

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

    // 滚动到指定行（用于从代码搜索结果跳转时快速定位）
    var scrollToLine: Int? = nil

    // 撤销/重做状态更新回调
    var onUndoRedoStateChange: ((Bool, Bool) -> Void)?

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
        // 大文件性能优化：超过1MB的文件不遍历计算行号宽度，直接使用最大宽度80pt
        let fileSizeForLineNumber = text.utf8.count
        let calculatedLineNumberWidth: CGFloat
        if showLineNumbers {
            if fileSizeForLineNumber > 1024 * 1024 {
                // 大文件：直接使用最大宽度，避免遍历整个文件计算行数
                calculatedLineNumberWidth = 80
            } else {
                // 小文件：精确计算行号宽度
                calculatedLineNumberWidth = LineNumberLayoutManager.calculateLineNumberWidth(for: text, font: lineNumberFont)
            }
        } else {
            calculatedLineNumberWidth = 0
        }
        let clampedLineNumberWidth = min(max(calculatedLineNumberWidth, 30), 80)
        layoutManager.lineNumberWidth = clampedLineNumberWidth
        textView.textContainerInset = UIEdgeInsets(
            top: 8,
            left: showLineNumbers ? clampedLineNumberWidth + 8 : 8,
            bottom: 8,
            right: 8
        )
        layoutManager.containerInset = textView.textContainerInset

        // 设置初始文本
        // 编辑模式下使用纯文本，避免语法高亮导致光标乱跳换行问题
        // 查看模式下使用带语法高亮的属性字符串
        // 大文件性能优化：超过1MB的文件自动禁用语法高亮，保证流畅浏览
        // TXT文件特殊处理：纯文本文件无需语法高亮，直接打开
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let fileSize = text.utf8.count
        let isLargeFile = fileSize > 1024 * 1024  // 1MB阈值，超过此大小自动禁用语法高亮
        let isTxtFile = fileName.lowercased().hasSuffix(".txt")  // TXT纯文本文件，无需语法高亮
        if isEditable || isLargeFile || isTxtFile {
            // 编辑模式、大文件或TXT文件：使用纯文本，保证性能和光标稳定性
            textStorage.setAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.label]))
        } else {
            // 小文件查看模式：使用语法高亮
            let highlightedText = SyntaxHighlighter.highlight(text, font: font, fileName: fileName)
            textStorage.setAttributedString(highlightedText)
        }

        // 预计算换行符位置（大文件性能优化，行号计算使用二分查找）
        layoutManager.precomputeNewlinePositions()

        // 保存 coordinator 引用
        context.coordinator.textView = textView
        context.coordinator.fontSize = fontSize
        context.coordinator.fontSizeBinding = _fontSize
        context.coordinator.onSearchResult = onSearchResult
        context.coordinator.onSelectedText = onSelectedText
        context.coordinator.onLookupSelectedText = onLookupSelectedText
        context.coordinator.isEditable = isEditable
        context.coordinator.fileName = fileName
        context.coordinator.onUndoRedoStateChange = onUndoRedoStateChange

        // 设置textView并添加撤销/重做状态观察
        context.coordinator.setupTextView(textView)

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
        context.coordinator.isEditable = isEditable
        context.coordinator.fileName = fileName

        // 更新查找回调
        if let codeEditorTextView = textView as? CodeEditorTextView {
            codeEditorTextView.onLookupSelectedText = onLookupSelectedText
        }
        context.coordinator.onLookupSelectedText = onLookupSelectedText
        context.coordinator.onUndoRedoStateChange = onUndoRedoStateChange

        // 更新字体（仅当字体大小真的变化时才更新，避免每次updateUIView都触发重新布局导致光标乱跳）
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if context.coordinator.fontSize != fontSize {
            textView.font = font
            context.coordinator.fontSize = fontSize
        }

        // 更新行号显示（仅当行号宽度或显示状态真的变化时才更新，避免每次updateUIView都触发重新布局导致光标乱跳）
        if let layoutManager = textView.layoutManager as? LineNumberLayoutManager {
            let lineNumberFont = UIFont.monospacedSystemFont(ofSize: fontSize - 2, weight: .regular)
            // 大文件性能优化：超过1MB的文件不遍历计算行号宽度，直接使用最大宽度80pt
            let fileSizeForUpdate = textView.text.utf8.count
            let calculatedLineNumberWidth: CGFloat
            if showLineNumbers {
                if fileSizeForUpdate > 1024 * 1024 {
                    // 大文件：直接使用最大宽度，避免遍历整个文件计算行数
                    calculatedLineNumberWidth = 80
                } else {
                    // 小文件：精确计算行号宽度
                    calculatedLineNumberWidth = LineNumberLayoutManager.calculateLineNumberWidth(for: textView.text, font: lineNumberFont)
                }
            } else {
                calculatedLineNumberWidth = 0
            }
            let clampedLineNumberWidth = min(max(calculatedLineNumberWidth, 30), 80)

            // 仅当行号宽度、字体或显示状态真的变化时才更新，避免不必要的重新布局
            let needsUpdate = layoutManager.lineNumberWidth != clampedLineNumberWidth ||
                              layoutManager.lineNumberFont != lineNumberFont ||
                              context.coordinator.lastShowLineNumbers != showLineNumbers

            if needsUpdate {
                layoutManager.lineNumberFont = lineNumberFont
                layoutManager.lineNumberWidth = clampedLineNumberWidth
                textView.textContainerInset = UIEdgeInsets(
                    top: 8,
                    left: showLineNumbers ? clampedLineNumberWidth + 8 : 8,
                    bottom: 8,
                    right: 8
                )
                layoutManager.containerInset = textView.textContainerInset
                layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.text.count))
                context.coordinator.lastShowLineNumbers = showLineNumbers
            }
        }

        // 外部文本变化时更新（编辑模式下完全禁用外部文本回写，避免状态更新导致视图重绘进而触发文本回写循环）
        if !isEditable && textView.text != text && !context.coordinator.isInternalUpdate {
            let selectedRange = textView.selectedRange
            // 编辑模式下使用纯文本，避免语法高亮导致光标乱跳换行问题
            if isEditable {
                textView.textStorage.setAttributedString(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: UIColor.label]))
            } else {
                let highlightedText = SyntaxHighlighter.highlight(text, font: font, fileName: fileName)
                textView.textStorage.setAttributedString(highlightedText)
            }
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

        // 滚动到指定行（用于从代码搜索结果跳转时快速定位）
        if let line = scrollToLine, line > 0 {
            DispatchQueue.main.async {
                let nsText = textView.text as NSString
                var lineNumber = 1
                var charIndex = 0
                // 遍历找到指定行的起始位置
                while charIndex < nsText.length && lineNumber < line {
                    let char = nsText.character(at: charIndex)
                    if char == 10 { // 换行符
                        lineNumber += 1
                    }
                    charIndex += 1
                }
                // 滚动到指定行
                if charIndex < nsText.length {
                    let range = NSRange(location: charIndex, length: 1)
                    textView.scrollRangeToVisible(range)
                    // 选中指定行，高亮显示
                    textView.selectedRange = range
                }
            }
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
        var fontSizeBinding: Binding<CGFloat>?
        var isInternalUpdate = false
        var onSearchResult: ((Int, Int) -> Void)?
        var onSelectedText: ((String) -> Void)?
        var onLookupSelectedText: ((String) -> Void)?
        // 记录上一次的行号显示状态，用于判断是否需要更新行号布局（避免不必要的重新布局导致光标乱跳）
        var lastShowLineNumbers: Bool = true
        // 撤销/重做状态更新回调
        var onUndoRedoStateChange: ((Bool, Bool) -> Void)?
        // 上一次的撤销/重做状态（用于状态变化检测）
        private var lastCanUndo: Bool = false
        private var lastCanRedo: Bool = false
        // 是否可编辑（用于判断是否禁用语法高亮，避免光标乱跳换行问题）
        var isEditable: Bool = false
        // 文件名（用于语法高亮语言检测）
        var fileName: String = ""

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

        // MARK: - 编辑体验增强配置（第二期）
        /// 是否启用括号自动闭合
        var autoCloseBrackets: Bool = true
        /// 是否启用自动缩进
        var autoIndent: Bool = true
        /// 缩进宽度（空格数）
        var indentWidth: Int = 4
        /// 是否使用Tab缩进
        var useTabIndent: Bool = false
        /// 括号匹配对（开括号:闭括号）
        private let bracketPairs: [Character: Character] = [
            "(": ")",
            "[": "]",
            "{": "}",
            "\"": "\"",
            "'": "'",
            "`": "`"
        ]

        init(text: Binding<String>, onTextChange: ((String) -> Void)?) {
            _text = text
            self.onTextChange = onTextChange
            super.init()
            // 监听撤销/重做通知（由外部按钮发送）
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleUndoNotification),
                name: NSNotification.Name("CodeEditorUndo"),
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleRedoNotification),
                name: NSNotification.Name("CodeEditorRedo"),
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        /// 设置textView并初始化撤销/重做状态
        /// - Parameter textView: UITextView实例
        func setupTextView(_ textView: UITextView) {
            self.textView = textView
            // 初始化撤销/重做状态
            updateUndoRedoState()
        }

        /// 更新撤销/重做状态并通知外部（延迟到下一个runloop周期，避免在textViewDidChange中同步触发视图重绘导致文本回写循环）
        private func updateUndoRedoState() {
            guard let textView = textView else { return }
            let canUndo = textView.undoManager?.canUndo ?? false
            let canRedo = textView.undoManager?.canRedo ?? false
            if lastCanUndo != canUndo || lastCanRedo != canRedo {
                lastCanUndo = canUndo
                lastCanRedo = canRedo
                // 延迟到下一个runloop周期，确保text绑定已同步，避免updateUIView中文本回写循环
                DispatchQueue.main.async { [weak self] in
                    self?.onUndoRedoStateChange?(canUndo, canRedo)
                }
            }
        }

        /// 处理撤销通知
        @objc private func handleUndoNotification() {
            guard let textView = textView, textView.undoManager?.canUndo == true else { return }
            // 标记内部更新，避免撤销操作触发的textViewDidChange导致文本回写循环
            isInternalUpdate = true
            // 执行撤销操作
            textView.undoManager?.undo()
            // 强制刷新textView确保UI同步更新
            textView.setNeedsDisplay()
            // 手动获取撤销后的文本，确保@Binding正确同步
            let newText = textView.text ?? ""
            // 延迟重置内部更新标志并同步文本
            DispatchQueue.main.async { [weak self] in
                self?.text = newText
                self?.onTextChange?(newText)
                self?.isInternalUpdate = false
                self?.updateUndoRedoState()
            }
        }

        /// 处理重做通知
        @objc private func handleRedoNotification() {
            guard let textView = textView, textView.undoManager?.canRedo == true else { return }
            // 标记内部更新，避免重做操作触发的textViewDidChange导致文本回写循环
            isInternalUpdate = true
            // 执行重做操作
            textView.undoManager?.redo()
            // 强制刷新textView确保UI同步更新
            textView.setNeedsDisplay()
            // 手动获取重做后的文本，确保@Binding正确同步
            let newText = textView.text ?? ""
            // 延迟重置内部更新标志并同步文本
            DispatchQueue.main.async { [weak self] in
                self?.text = newText
                self?.onTextChange?(newText)
                self?.isInternalUpdate = false
                self?.updateUndoRedoState()
            }
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

            // 粘贴（仅在可编辑且剪贴板有文字时显示）
            if textView.isEditable && UIPasteboard.general.hasStrings {
                let pasteAction = UIAction(
                    title: "粘贴",
                    image: UIImage(systemName: "doc.on.clipboard")
                ) { [weak self] _ in
                    guard let self = self else { return }
                    guard let pasteboardText = UIPasteboard.general.string, !pasteboardText.isEmpty else { return }
                    let mutableText = NSMutableString(string: textView.text)
                    mutableText.insert(pasteboardText, at: range.location)
                    textView.text = mutableText as String
                    textView.selectedRange = NSRange(location: range.location + pasteboardText.count, length: 0)
                    // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
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

        /// 处理文本变更前的拦截（括号自动闭合、自动缩进）
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard isEditable else { return true }

            // 括号自动闭合（先检查text.count == 1，避免Character(text)在多字符时崩溃）
            if autoCloseBrackets, text.count == 1, let char = text.first, let openBracket = bracketPairs[char] {
                return handleBracketAutoClose(textView: textView, range: range, openBracket: openBracket, closeBracket: bracketPairs[char]!)
            }

            // 自动缩进（换行时）
            if autoIndent, text == "\n" {
                return handleAutoIndent(textView: textView, range: range)
            }

            // 退格键处理：如果光标在括号对中间，同时删除左右括号
            if text == "", range.length == 1, range.location > 0 {
                let nsText = textView.text as NSString
                // 安全检查：确保range.location不越界
                guard range.location <= nsText.length else { return true }
                let charBefore = nsText.substring(with: NSRange(location: range.location - 1, length: 1))
                let openBracket = Character(charBefore)
                if let closeBracket = bracketPairs[openBracket], openBracket != closeBracket {
                    // 检查光标后是否是对应的闭括号
                    if range.location < nsText.length {
                        let charAfter = nsText.substring(with: NSRange(location: range.location, length: 1))
                        if Character(charAfter) == closeBracket {
                            // 同时删除左右括号
                            let newRange = NSRange(location: range.location - 1, length: 2)
                            textView.text = nsText.replacingCharacters(in: newRange, with: "")
                            textView.selectedRange = NSRange(location: range.location - 1, length: 0)
                            // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
                            return false
                        }
                    }
                }
            }

            return true
        }

        /// 处理括号自动闭合
        private func handleBracketAutoClose(textView: UITextView, range: NSRange, openBracket: Character, closeBracket: Character) -> Bool {
            let nsText = textView.text as NSString

            // 如果有选中文字，用括号包裹选中文字
            if range.length > 0 {
                let selectedText = nsText.substring(with: range)
                let newText = "\(openBracket)\(selectedText)\(closeBracket)"
                textView.text = nsText.replacingCharacters(in: range, with: newText)
                // 光标定位到闭括号前
                textView.selectedRange = NSRange(location: range.location + newText.count - 1, length: 0)
                // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
                return false
            }

            // 检查光标后是否已经是闭括号（避免重复闭合）
            if range.location < nsText.length {
                let charAfter = nsText.substring(with: NSRange(location: range.location, length: 1))
                if Character(charAfter) == closeBracket && openBracket != closeBracket {
                    // 光标跳过已有的闭括号
                    textView.selectedRange = NSRange(location: range.location + 1, length: 0)
                    return false
                }
            }

            // 引号特殊处理：如果光标前已经是引号，不自动闭合
            if openBracket == closeBracket && range.location > 0 {
                let charBefore = nsText.substring(with: NSRange(location: range.location - 1, length: 1))
                if Character(charBefore) == openBracket {
                    // 检查是否是字符串中的引号（简单判断：前面是否有反斜杠）
                    if range.location >= 2 {
                        let charBefore2 = nsText.substring(with: NSRange(location: range.location - 2, length: 1))
                        if charBefore2 != "\\" {
                            // 不是转义引号，正常输入
                            return true
                        }
                    }
                }
            }

            // 正常自动闭合：插入开括号+闭括号，光标定位到中间
            let newText = "\(openBracket)\(closeBracket)"
            textView.text = nsText.replacingCharacters(in: range, with: newText)
            textView.selectedRange = NSRange(location: range.location + 1, length: 0)
            // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
            return false
        }

        /// 处理自动缩进
        private func handleAutoIndent(textView: UITextView, range: NSRange) -> Bool {
            let nsText = textView.text as NSString

            // 获取当前行的内容
            let currentLineRange = (textView.text as NSString).lineRange(for: range)
            let currentLineText = nsText.substring(with: currentLineRange)

            // 提取当前行的前导空白（缩进）
            var indent = ""
            for char in currentLineText {
                if char == " " || char == "\t" {
                    indent.append(char)
                } else {
                    break
                }
            }

            // 检查当前行是否以开括号结尾（需要增加缩进）
            let trimmedLine = currentLineText.trimmingCharacters(in: .whitespaces)
            var shouldIncreaseIndent = false
            if let lastChar = trimmedLine.last {
                if lastChar == "{" || lastChar == "(" || lastChar == "[" {
                    shouldIncreaseIndent = true
                }
            }

            // 检查下一行是否以闭括号开头（需要减少缩进，用于闭括号自动对齐）
            var nextLineStartsWithCloseBracket = false
            if range.location < nsText.length {
                let afterCursor = nsText.substring(from: range.location)
                if let firstNewline = afterCursor.firstIndex(of: "\n") {
                    let nextLineStart = afterCursor.index(after: firstNewline)
                    if nextLineStart < afterCursor.endIndex {
                        let nextLine = String(afterCursor[nextLineStart...])
                        let trimmedNextLine = nextLine.trimmingCharacters(in: .whitespaces)
                        if let firstChar = trimmedNextLine.first {
                            if firstChar == "}" || firstChar == ")" || firstChar == "]" {
                                nextLineStartsWithCloseBracket = true
                            }
                        }
                    }
                }
            }

            // 构建缩进字符串
            var finalIndent = indent
            if shouldIncreaseIndent {
                if useTabIndent {
                    finalIndent += "\t"
                } else {
                    finalIndent += String(repeating: " ", count: indentWidth)
                }
            }

            // 如果下一行以闭括号开头，在当前行后插入一个减少缩进的空行（用于闭括号对齐）
            if nextLineStartsWithCloseBracket && shouldIncreaseIndent {
                // 插入换行+增加缩进+换行+原缩进（闭括号会自动对齐）
                let insertText = "\n\(finalIndent)\n\(indent)"
                textView.text = nsText.replacingCharacters(in: range, with: insertText)
                // 光标定位到中间的空行
                textView.selectedRange = NSRange(location: range.location + 1 + finalIndent.count, length: 0)
                // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
                return false
            }

            // 正常换行+缩进
            let insertText = "\n\(finalIndent)"
            textView.text = nsText.replacingCharacters(in: range, with: insertText)
            textView.selectedRange = NSRange(location: range.location + insertText.count, length: 0)
            // 不立即回写@Binding，让textViewDidChange统一处理，避免光标乱跳
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            guard !isSearching else { return }

            // 标记内部更新，防止SwiftUI的updateUIView在文本更新时重置光标位置
            isInternalUpdate = true

            // 编辑模式下延迟更新@Binding，切断同步循环（避免父视图重绘触发updateUIView中行号更新导致重新布局，进而再次触发textViewDidChange形成无限循环）
            if isEditable {
                let currentText = textView.text ?? ""
                DispatchQueue.main.async { [weak self] in
                    self?.text = currentText
                    self?.onTextChange?(currentText)
                    self?.isInternalUpdate = false
                }
                // 更新撤销/重做按钮状态（文本变更后canUndo/canRedo可能变化）
                updateUndoRedoState()
                return
            }

            // 查看模式下同步更新@Binding
            text = textView.text
            onTextChange?(textView.text)

            // 更新撤销/重做按钮状态（文本变更后canUndo/canRedo可能变化）
            updateUndoRedoState()

            // 编辑模式下完全禁用语法高亮，避免光标乱跳换行问题
            // 查看模式下才应用语法高亮
            guard !isEditable else {
                // 确保在下一个runloop周期后才允许updateUIView更新文本
                DispatchQueue.main.async { [weak self] in
                    self?.isInternalUpdate = false
                }
                return
            }

            // 取消之前的语法高亮任务
            highlightWorkItem?.cancel()

            // 延迟应用语法高亮，避免在用户连续输入时频繁重绘导致光标乱跳
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self, let textView = self.textView else { return }
                self.applySyntaxHighlight(textView: textView)
            }
            highlightWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)

            // 确保在下一个runloop周期后才允许updateUIView更新文本
            // 这样可以保证用户输入的文本不会被SwiftUI的状态更新覆盖，同时避免光标位置丢失
            DispatchQueue.main.async { [weak self] in
                self?.isInternalUpdate = false
            }
        }

        /// 应用语法高亮（修复光标乱跳问题：使用beginEditing/endEditing，避免替换整个textStorage）
        private func applySyntaxHighlight(textView: UITextView) {
            guard !isSearching else { return }

            // 保存当前光标位置和选中范围
            let selectedRange = textView.selectedRange
            let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            guard let currentText = textView.text else { return }

            // 生成带语法高亮的属性字符串
            let highlightedText = SyntaxHighlighter.highlight(currentText, font: font, fileName: fileName)

            // 标记内部更新，防止SwiftUI的updateUIView在语法高亮更新时重置光标位置
            isInternalUpdate = true

            // 使用beginEditing/endEditing包裹，避免替换整个textStorage导致光标重置
            textView.textStorage.beginEditing()
            // 替换整个内容，但保留selectedRange
            textView.textStorage.setAttributedString(highlightedText)
            textView.textStorage.endEditing()

            // 恢复光标位置和选中范围（关键：确保光标不会乱跳）
            textView.selectedRange = selectedRange
            // 确保光标可见
            textView.scrollRangeToVisible(selectedRange)

            // 在下一个runloop周期后允许updateUIView更新文本
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
                let highlightedText = SyntaxHighlighter.highlight(fullText, font: font, fileName: fileName)
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
            let highlightedText = SyntaxHighlighter.highlight(fullText, font: font, fileName: fileName)
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
            let highlightedText = SyntaxHighlighter.highlight(fullText, font: font, fileName: fileName)

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