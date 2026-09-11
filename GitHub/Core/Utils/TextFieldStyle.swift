import SwiftUI

// MARK: - 自适应输入框样式（统一处理暗黑模式）
/// 全局统一的输入框样式，自动适配明暗模式
/// 解决暗黑模式下输入框白字白底看不清的问题
struct 自适应输入框样式: TextFieldStyle {
    @EnvironmentObject private var appState: AppState

    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.95, green: 0.95, blue: 0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.8, green: 0.8, blue: 0.8), lineWidth: 1)
            )
            .foregroundColor(appState.isDarkMode ? .white : .black)
            .accentColor(appState.isDarkMode ? .white : .blue)
    }
}

// MARK: - 输入框暗黑模式适配修改器
/// 给现有RoundedBorderTextFieldStyle输入框添加暗黑模式文字颜色适配
struct 输入框暗黑模式适配: ViewModifier {
    @EnvironmentObject private var appState: AppState

    func body(content: Content) -> some View {
        content
            .foregroundColor(appState.isDarkMode ? .white : .primary)
            .colorScheme(appState.isDarkMode ? .dark : .light)
    }
}

extension View {
    /// 应用输入框暗黑模式适配
    func 适配输入框暗黑模式() -> some View {
        self.modifier(输入框暗黑模式适配())
    }
}
