import SwiftUI

// ==============================================================================
// ReadmeView 仓库README查看器
// 功能：显示仓库README.md的Markdown原文，支持滚动查看
// 位置：与GitHub相同，显示在仓库文件列表下方
// ==============================================================================

struct ReadmeView: View {
    let markdownContent: String
    let owner: String
    let repo: String

    @EnvironmentObject var appState: AppState
    @State private var isCopied: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // README标题栏
            HStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 16))
                    .foregroundColor(appState.isDarkMode ? .gray : .secondary)

                Text("README.md")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(appState.isDarkMode ? .white : .primary)

                Spacer()

                // 复制按钮
                Button(action: {
                    UIPasteboard.general.string = markdownContent
                    isCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isCopied = false
                    }
                }) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 14))
                        .foregroundColor(isCopied ? .green : .blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(appState.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.96))

            // 分割线
            Rectangle()
                .fill(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85))
                .frame(height: 1)

            // Markdown内容区域
            ScrollView {
                Text(markdownContent)
                    .font(.system(size: 13))
                    .foregroundColor(appState.isDarkMode ? Color(red: 0.85, green: 0.85, blue: 0.85) : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .textSelection(.enabled)
            }
            .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : .white)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(appState.isDarkMode ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 16)
    }
}
