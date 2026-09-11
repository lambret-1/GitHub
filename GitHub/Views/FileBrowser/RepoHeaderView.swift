import SwiftUI

// ==============================================================================
// RepoHeaderView 仓库头部组件
// 功能：复刻GitHub网页仓库页顶部布局，展示仓库信息、Watch/Fork/Star按钮
// 位置：仓库页面最顶部，分支栏上方
// ==============================================================================

struct RepoHeaderView: View {
    let repository: Repository
    let isStarred: Bool
    let isCheckingStar: Bool
    let isStarring: Bool
    let isForking: Bool
    let onToggleStar: () -> Void
    let onFork: () -> Void

    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 第一行：仓库名称 + 图标
            HStack(spacing: 8) {
                Image(systemName: "book.closed")
                    .font(.system(size: 18))
                    .foregroundColor(appState.isDarkMode ? .gray : .secondary)

                Text(repository.ownerName)
                    .font(.system(size: 17))
                    .foregroundColor(.blue)

                Text("/")
                    .font(.system(size: 17))
                    .foregroundColor(appState.isDarkMode ? .gray : .secondary)

                Text(repository.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.blue)

                Spacer()

                // 仓库可见性标签
                if repository.isPrivate {
                    Text("私有")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.isDarkMode ? Color.gray.opacity(0.4) : Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    Text("公开")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.isDarkMode ? Color.gray.opacity(0.4) : Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            // 第二行：仓库描述
            if let description = repository.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(appState.isDarkMode ? Color(red: 0.8, green: 0.8, blue: 0.8) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // 第三行：操作按钮组（Watch / Fork / Star）
            HStack(spacing: 8) {
                // 关注按钮
                Button(action: {
                    // Watch功能暂未实现，显示提示
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 13))
                        Text("关注")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(repository.watchersCount ?? 0)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                    )
                }

                // 复刻按钮
                Button(action: {
                    onFork()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 13))
                        Text("复刻")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(repository.forksCount ?? 0)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                    )
                }
                .disabled(isForking)

                // 标星按钮
                Button(action: {
                    onToggleStar()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 13))
                            .foregroundColor(isStarred ? .yellow : (appState.isDarkMode ? .white : .primary))
                        Text(isStarred ? "已标星" : "标星")
                            .font(.system(size: 13, weight: .medium))
                        Text("\(repository.stargazersCount ?? 0)")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                    )
                }
                .disabled(isStarring || isCheckingStar)

                Spacer()
            }

            // 第四行：仓库元信息
            HStack(spacing: 16) {
                // 语言
                if let language = repository.language, !language.isEmpty {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(languageColor(language))
                            .frame(width: 12, height: 12)
                        Text(language)
                            .font(.system(size: 12))
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    }
                }

                // 星标数
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    Text("\(repository.stargazersCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }

                // 复刻数
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 11))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    Text("\(repository.forksCount ?? 0)")
                        .font(.system(size: 12))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.98, green: 0.98, blue: 0.98))
    }

    // 根据语言名称返回对应颜色（GitHub官方语言颜色）
    private func languageColor(_ language: String) -> Color {
        let colorMap: [String: Color] = [
            "Swift": Color(red: 0.97, green: 0.36, blue: 0.20),
            "Python": Color(red: 0.22, green: 0.45, blue: 0.70),
            "JavaScript": Color(red: 0.72, green: 0.72, blue: 0.22),
            "TypeScript": Color(red: 0.16, green: 0.42, blue: 0.80),
            "Java": Color(red: 0.72, green: 0.22, blue: 0.22),
            "Kotlin": Color(red: 0.56, green: 0.36, blue: 0.80),
            "Go": Color(red: 0.00, green: 0.68, blue: 0.72),
            "Rust": Color(red: 0.68, green: 0.36, blue: 0.20),
            "C++": Color(red: 0.36, green: 0.42, blue: 0.80),
            "C": Color(red: 0.36, green: 0.42, blue: 0.80),
            "Objective-C": Color(red: 0.26, green: 0.42, blue: 0.68),
            "Dart": Color(red: 0.00, green: 0.68, blue: 0.84),
            "HTML": Color(red: 0.80, green: 0.30, blue: 0.20),
            "CSS": Color(red: 0.36, green: 0.42, blue: 0.80),
            "Shell": Color(red: 0.56, green: 0.62, blue: 0.42),
            "Ruby": Color(red: 0.70, green: 0.22, blue: 0.22),
            "PHP": Color(red: 0.36, green: 0.36, blue: 0.60),
            "Vue": Color(red: 0.26, green: 0.68, blue: 0.56),
            "React": Color(red: 0.22, green: 0.68, blue: 0.80)
        ]
        return colorMap[language] ?? Color.gray
    }
}
