import SwiftUI

// MARK: - iOS14兼容扩展
// 用于替代iOS15+/iOS16+的高版本API，确保iOS14系统兼容

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
    /// 替代iOS15+的.refreshable(action:)
    @ViewBuilder
    func ios14Refreshable(action: @escaping () async -> Void) -> some View {
        if #available(iOS 15.0, *) {
            self.refreshable(action: action)
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
}

// MARK: - iOS15+专属API兼容（使用@available包裹，iOS14上不执行）

@available(iOS 15.0, *)
extension View {
    /// iOS15+文本选择
    func ios14TextSelection(_ selection: TextSelection) -> some View {
        self.textSelection(selection)
    }

    /// iOS15+滑动操作
    func ios14SwipeActions<Content: View>(
        edge: HorizontalEdge = .trailing,
        allowsFullSwipe: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self.swipeActions(edge: edge, allowsFullSwipe: allowsFullSwipe, content: content)
    }

    /// iOS15+焦点状态绑定（Bool版本）
    func ios14Focused(_ binding: Binding<Bool>) -> some View {
        self.focused(binding)
    }

    /// iOS15+焦点状态绑定（值版本）
    func ios14Focused<Value: Hashable>(_ binding: Binding<Value?>, equals value: Value) -> some View {
        self.focused(binding, equals: value)
    }

    /// iOS15+提交操作
    func ios14OnSubmit(_ action: @escaping () -> Void) -> some View {
        self.onSubmit(action)
    }

    /// iOS15+提交标签
    func ios14SubmitLabel(_ label: SubmitLabel) -> some View {
        self.submitLabel(label)
    }
}

// MARK: - iOS14降级版本（iOS14上使用，不做任何事情）

extension View {
    /// iOS14降级：文本选择（不生效）
    func ios14TextSelection(_ selection: Any?) -> some View {
        self
    }

    /// iOS14降级：滑动操作（不生效）
    func ios14SwipeActions<Content: View>(
        edge: Any? = nil,
        allowsFullSwipe: Bool = true,
        @ViewBuilder content: () -> Content
    ) -> some View {
        self
    }

    /// iOS14降级：焦点状态绑定（不生效）
    func ios14Focused(_ binding: Any?) -> some View {
        self
    }

    /// iOS14降级：提交操作（不生效）
    func ios14OnSubmit(_ action: @escaping () -> Void) -> some View {
        self
    }

    /// iOS14降级：提交标签（不生效）
    func ios14SubmitLabel(_ label: Any?) -> some View {
        self
    }
}
