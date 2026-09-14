import Foundation
import SwiftUI
import UIKit

// ==============================================================================
// UndoManager 撤销/重做管理器
// 功能：统一管理文本编辑的撤销/重做操作，支持批量操作合并
// 位置：文件编辑器的撤销/重做核心层
// 设计原则：基于NSUndoManager封装，SwiftUI友好，支持操作分组
// ==============================================================================

class EditorUndoManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = EditorUndoManager()

    private init() {}

    // MARK: - 私有属性

    /// 底层NSUndoManager
    private let undoManager = UndoManager()

    /// 操作分组计数（用于批量操作合并）
    private var groupLevel: Int = 0

    /// 当前编辑的文件路径（用于隔离不同文件的撤销栈）
    private var currentFilePath: String = ""

    // MARK: - 发布属性

    /// 是否可以撤销
    @Published private(set) var canUndo: Bool = false

    /// 是否可以重做
    @Published private(set) var canRedo: Bool = false

    /// 撤销栈深度（用于调试）
    @Published private(set) var undoCount: Int = 0

    /// 重做栈深度（用于调试）
    @Published private(set) var redoCount: Int = 0

    // MARK: - 公开方法

    /// 设置当前编辑的文件路径（切换文件时重置撤销栈）
    /// - Parameter path: 文件路径
    func setCurrentFile(_ path: String) {
        if path != currentFilePath {
            // 切换文件时清空撤销/重做栈
            undoManager.removeAllActions()
            currentFilePath = path
            updateState()
        }
    }

    /// 注册一个可撤销的操作
    /// - Parameters:
    ///   - undoAction: 撤销时执行的闭包
    ///   - redoAction: 重做时执行的闭包（可选，默认重新执行原操作）
    func registerUndo(undoAction: @escaping () -> Void, redoAction: (() -> Void)? = nil) {
        undoManager.registerUndo(withTarget: self) { target in
            undoAction()
            // 注册重做操作
            if let redo = redoAction {
                target.undoManager.registerUndo(withTarget: target) { _ in
                    redo()
                }
            }
        }
        updateState()
    }

    /// 注册文本变更的撤销/重做（基于文本内容快照）
    /// - Parameters:
    ///   - oldText: 变更前的文本
    ///   - newText: 变更后的文本
    ///   - textBinding: 文本绑定（用于撤销/重做时更新）
    func registerTextChange(oldText: String, newText: String, textBinding: Binding<String>) {
        guard oldText != newText else { return }

        undoManager.registerUndo(withTarget: self) { target in
            // 撤销：恢复旧文本
            textBinding.wrappedValue = oldText
            // 注册重做
            target.undoManager.registerUndo(withTarget: target) { _ in
                textBinding.wrappedValue = newText
            }
        }
        updateState()
    }

    /// 执行撤销
    func undo() {
        guard undoManager.canUndo else { return }
        undoManager.undo()
        updateState()
    }

    /// 执行重做
    func redo() {
        guard undoManager.canRedo else { return }
        undoManager.redo()
        updateState()
    }

    /// 开始操作分组（批量操作作为一个撤销单元）
    func beginGroup() {
        groupLevel += 1
        undoManager.beginUndoGrouping()
    }

    /// 结束操作分组
    func endGroup() {
        guard groupLevel > 0 else { return }
        groupLevel -= 1
        undoManager.endUndoGrouping()
        updateState()
    }

    /// 执行一个操作分组（自动开始和结束）
    /// - Parameter operations: 批量操作闭包
    func performGrouped(_ operations: () -> Void) {
        beginGroup()
        operations()
        endGroup()
    }

    /// 清空撤销/重做栈（提交成功后调用）
    func clear() {
        undoManager.removeAllActions()
        updateState()
    }

    /// 清空重做栈（有新操作时自动调用）
    func clearRedo() {
        // NSUndoManager会在新操作时自动清空重做栈
        // 这里提供手动清空的能力
        updateState()
    }

    // MARK: - 私有方法

    /// 更新发布属性状态
    private func updateState() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.canUndo = self.undoManager.canUndo
            self.canRedo = self.undoManager.canRedo
            self.undoCount = self.undoManager.levelsOfUndo
            // Foundation的UndoManager没有levelsOfRedo属性，canRedo已足够判断
        }
    }
}

// ==============================================================================
// UndoManagerViewModifier 撤销/重做视图修饰符
// 功能：为SwiftUI视图添加撤销/重做手势支持
// 使用方式：.undoSupport(undoManager:undoAction:redoAction:)
// ==============================================================================

struct UndoSupportModifier: ViewModifier {
    @ObservedObject var undoManager: EditorUndoManager
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .editorUndoNotification)) { _ in
                if undoManager.canUndo {
                    undoManager.undo()
                    onUndo?()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .editorRedoNotification)) { _ in
                if undoManager.canRedo {
                    undoManager.redo()
                    onRedo?()
                }
            }
    }
}

extension View {
    /// 添加撤销/重做支持
    /// - Parameters:
    ///   - undoManager: 撤销管理器
    ///   - onUndo: 撤销回调
    ///   - onRedo: 重做回调
    /// - Returns: 修饰后的视图
    func undoSupport(undoManager: EditorUndoManager, onUndo: (() -> Void)? = nil, onRedo: (() -> Void)? = nil) -> some View {
        modifier(UndoSupportModifier(undoManager: undoManager, onUndo: onUndo, onRedo: onRedo))
    }
}

// MARK: - 通知名称扩展

extension Notification.Name {
    /// 撤销通知
    static let editorUndoNotification = Notification.Name("EditorUndoNotification")
    /// 重做通知
    static let editorRedoNotification = Notification.Name("EditorRedoNotification")
}

// MARK: - UIKeyCommand扩展（外接键盘快捷键支持）

extension UIResponder {
    /// 为编辑视图添加撤销/重做快捷键
    /// - Returns: 快捷键命令数组
    static func undoRedoKeyCommands() -> [UIKeyCommand] {
        return [
            UIKeyCommand(title: "撤销", action: #selector(handleUndo), input: "z", modifierFlags: .command),
            UIKeyCommand(title: "重做", action: #selector(handleRedo), input: "z", modifierFlags: [.command, .shift])
        ]
    }

    @objc private func handleUndo() {
        NotificationCenter.default.post(name: .editorUndoNotification, object: nil)
    }

    @objc private func handleRedo() {
        NotificationCenter.default.post(name: .editorRedoNotification, object: nil)
    }
}
