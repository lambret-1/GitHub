import SwiftUI

// MARK: - iOS14兼容扩展
// 用于替代iOS15+/iOS16+的高版本API，确保iOS14系统兼容
// 设计原则：iOS14上降级不生效，iOS15+上使用原生API

extension View {
    // MARK: - 导航目标（替代iOS16+ navigationDestination）

    /// iOS14兼容的导航目标（基于isPresented状态）
    /// 替代iOS16+的.navigationDestination(isPresented:destination:)
    func ios14NavigationDestination<Destination: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder destination: @escaping () -> Destination
    ) -> some View {
        self.background(
            NavigationLink(
                destination: destination(),
                isActive: isPresented
            ) {
                EmptyView()
            }
            .hidden()
        )
    }

    // MARK: - 下拉刷新（替代iOS15+ refreshable）

    /// iOS14兼容的下拉刷新
    /// 替代iOS15+的.ios14Refreshable(action:)
    @ViewBuilder
    func ios14Refreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.ios14Refreshable(action: action)
        } else {
            self
        }
    }

    // MARK: - 角标（替代iOS15+ badge）

    /// iOS14兼容的角标（字符串版本）
    /// 替代iOS15+的.badge(_:)
    @ViewBuilder
    func ios14Badge(_ badge: String?) -> some View {
        if #available(iOS 15.0, *) {
            if let badge = badge {
                self.badge(badge)
            } else {
                self
            }
        } else {
            self
        }
    }

    // MARK: - 色调（替代iOS15+ tint）

    /// iOS14兼容的色调
    /// 替代iOS15+的.tint(_:)
    @ViewBuilder
    func ios14Tint(_ tint: Color?) -> some View {
        if #available(iOS 15.0, *) {
            if let tint = tint {
                self.tint(tint)
            } else {
                self
            }
        } else {
            self.accentColor(tint)
        }
    }

    // MARK: - 文本选择（替代iOS15+ textSelection）

    /// iOS14兼容的文本选择
    /// 替代iOS15+的.textSelection(.enabled)
    @ViewBuilder
    func ios14TextSelection() -> some View {
        if #available(iOS 15.0, *) {
            self.textSelection(.enabled)
        } else {
            self
        }
    }

    // MARK: - 滑动操作（替代iOS15+ swipeActions）

    /// iOS14兼容的滑动操作
    /// 替代iOS15+的.swipeActions(edge:allowsFullSwipe:content:)
    @ViewBuilder
    func ios14SwipeActions<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(iOS 15.0, *) {
            self.swipeActions(content: content)
        } else {
            self
        }
    }

    // MARK: - 焦点状态（替代iOS15+ focused）

    /// iOS14兼容的焦点状态绑定（Bool版本）
    /// 替代iOS15+的.focused(_:)
    @ViewBuilder
    func ios14Focused(_ binding: Binding<Bool>) -> some View {
        if #available(iOS 15.0, *) {
            self.focused(binding)
        } else {
            self
        }
    }

    // MARK: - 提交操作（替代iOS15+ onSubmit）

    /// iOS14兼容的提交操作
    /// 替代iOS15+的.onSubmit(_:)
    @ViewBuilder
    func ios14OnSubmit(_ action: @escaping () -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.onSubmit(action)
        } else {
            self
        }
    }

    // MARK: - 提交标签（替代iOS15+ submitLabel）

    /// iOS14兼容的提交标签
    /// 替代iOS15+的.submitLabel(_:)
    @ViewBuilder
    func ios14SubmitLabel(_ label: String) -> some View {
        if #available(iOS 15.0, *) {
            if let submitLabel = SubmitLabel(rawValue: label) {
                self.submitLabel(submitLabel)
            } else {
                self
            }
        } else {
            self
        }
    }

    // MARK: - 列表行分隔符（替代iOS15+ listRowSeparator）

    /// iOS14兼容的列表行分隔符隐藏
    /// 替代iOS15+的.ios14HideListRowSeparator()
    @ViewBuilder
    func ios14HideListRowSeparator() -> some View {
        if #available(iOS 15.0, *) {
            self.ios14HideListRowSeparator()
        } else {
            self
        }
    }
}
