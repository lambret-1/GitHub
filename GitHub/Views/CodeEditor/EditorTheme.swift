import Foundation
import SwiftUI
import UIKit

// ==============================================================================
// EditorTheme 编辑器主题管理器
// 功能：管理编辑器的配色主题，支持内置主题和自定义主题，支持深色/浅色模式
// 位置：文件编辑器的主题核心层
// 设计原则：主题数据与UI分离，支持主题切换动画，本地持久化存储
// ==============================================================================

class EditorThemeManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = EditorThemeManager()

    private init() {
        // 先初始化内置主题列表
        builtInThemes = builtInThemesList()
        customThemes = []
        // 给currentTheme一个默认值
        currentTheme = builtInThemes[0]
        // 然后加载用户选中的主题和自定义主题
        loadSelectedTheme()
        loadCustomThemes()
    }

    // MARK: - 主题数据模型

    struct EditorTheme: Codable, Identifiable, Equatable {
        var id: String
        var name: String
        var description: String
        var isBuiltIn: Bool

        // 编辑器背景色
        var backgroundColor: String
        // 代码文字颜色
        var textColor: String
        // 行号背景色
        var lineNumberBackgroundColor: String
        // 行号文字颜色
        var lineNumberTextColor: String
        // 当前行高亮色
        var currentLineHighlightColor: String
        // 选中文本背景色
        var selectionColor: String
        // 光标颜色
        var cursorColor: String

        // 语法高亮颜色
        var keywordColor: String
        var stringColor: String
        var numberColor: String
        var commentColor: String
        var functionColor: String
        var typeColor: String
        var variableColor: String
        var operatorColor: String
        var attributeColor: String
        var regexColor: String

        // 搜索匹配高亮色
        var searchMatchColor: String
        var searchMatchActiveColor: String

        // 括号匹配高亮色
        var bracketMatchColor: String

        enum CodingKeys: String, CodingKey {
            case id, name, description, isBuiltIn
            case backgroundColor, textColor, lineNumberBackgroundColor, lineNumberTextColor
            case currentLineHighlightColor, selectionColor, cursorColor
            case keywordColor, stringColor, numberColor, commentColor, functionColor
            case typeColor, variableColor, operatorColor, attributeColor, regexColor
            case searchMatchColor, searchMatchActiveColor, bracketMatchColor
        }

        static func == (lhs: EditorTheme, rhs: EditorTheme) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // MARK: - 发布属性

    /// 当前选中的主题
    @Published private(set) var currentTheme: EditorTheme

    /// 所有内置主题
    @Published private(set) var builtInThemes: [EditorTheme]

    /// 所有自定义主题
    @Published private(set) var customThemes: [EditorTheme]

    /// 所有主题（内置 + 自定义）
    var allThemes: [EditorTheme] {
        return builtInThemes + customThemes
    }

    // MARK: - 私有属性

    /// 自定义主题存储路径
    private let customThemesURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("EditorThemes.json")
    }()

    /// 选中主题存储键
    private let selectedThemeKey = "SelectedEditorTheme"

    // MARK: - 内置主题定义

    /// 获取所有内置主题
    private func builtInThemesList() -> [EditorTheme] {
        return [
            // GitHub 浅色主题
            EditorTheme(
                id: "github-light",
                name: "GitHub 浅色",
                description: "GitHub 官方浅色主题",
                isBuiltIn: true,
                backgroundColor: "#FFFFFF",
                textColor: "#24292F",
                lineNumberBackgroundColor: "#F6F8FA",
                lineNumberTextColor: "#8C959F",
                currentLineHighlightColor: "#F6F8FA",
                selectionColor: "#BBDFFF",
                cursorColor: "#0969DA",
                keywordColor: "#CF222E",
                stringColor: "#0A3069",
                numberColor: "#0550AE",
                commentColor: "#6E7781",
                functionColor: "#8250DF",
                typeColor: "#953800",
                variableColor: "#953800",
                operatorColor: "#CF222E",
                attributeColor: "#0550AE",
                regexColor: "#0A3069",
                searchMatchColor: "#FFF8C5",
                searchMatchActiveColor: "#FFE58F",
                bracketMatchColor: "#BBDFFF"
            ),

            // GitHub 深色主题
            EditorTheme(
                id: "github-dark",
                name: "GitHub 深色",
                description: "GitHub 官方深色主题",
                isBuiltIn: true,
                backgroundColor: "#0D1117",
                textColor: "#C9D1D9",
                lineNumberBackgroundColor: "#161B22",
                lineNumberTextColor: "#484F58",
                currentLineHighlightColor: "#161B22",
                selectionColor: "#264F78",
                cursorColor: "#58A6FF",
                keywordColor: "#FF7B72",
                stringColor: "#A5D6FF",
                numberColor: "#79C0FF",
                commentColor: "#8B949E",
                functionColor: "#D2A8FF",
                typeColor: "#FFA657",
                variableColor: "#FFA657",
                operatorColor: "#FF7B72",
                attributeColor: "#79C0FF",
                regexColor: "#A5D6FF",
                searchMatchColor: "#F2CC60",
                searchMatchActiveColor: "#E3B341",
                bracketMatchColor: "#264F78"
            ),

            // Monokai 主题
            EditorTheme(
                id: "monokai",
                name: "Monokai",
                description: "经典 Monokai 主题",
                isBuiltIn: true,
                backgroundColor: "#272822",
                textColor: "#F8F8F2",
                lineNumberBackgroundColor: "#1E1F1C",
                lineNumberTextColor: "#75715E",
                currentLineHighlightColor: "#3E3D32",
                selectionColor: "#49483E",
                cursorColor: "#F8F8F0",
                keywordColor: "#F92672",
                stringColor: "#E6DB74",
                numberColor: "#AE81FF",
                commentColor: "#75715E",
                functionColor: "#A6E22E",
                typeColor: "#66D9EF",
                variableColor: "#FD971F",
                operatorColor: "#F92672",
                attributeColor: "#A6E22E",
                regexColor: "#E6DB74",
                searchMatchColor: "#49483E",
                searchMatchActiveColor: "#75715E",
                bracketMatchColor: "#49483E"
            ),

            // Dracula 主题
            EditorTheme(
                id: "dracula",
                name: "Dracula",
                description: "流行的 Dracula 主题",
                isBuiltIn: true,
                backgroundColor: "#282A36",
                textColor: "#F8F8F2",
                lineNumberBackgroundColor: "#21222C",
                lineNumberTextColor: "#6272A4",
                currentLineHighlightColor: "#44475A",
                selectionColor: "#44475A",
                cursorColor: "#F8F8F2",
                keywordColor: "#FF79C6",
                stringColor: "#F1FA8C",
                numberColor: "#BD93F9",
                commentColor: "#6272A4",
                functionColor: "#50FA7B",
                typeColor: "#8BE9FD",
                variableColor: "#FFB86C",
                operatorColor: "#FF79C6",
                attributeColor: "#50FA7B",
                regexColor: "#F1FA8C",
                searchMatchColor: "#44475A",
                searchMatchActiveColor: "#6272A4",
                bracketMatchColor: "#44475A"
            ),

            // Solarized Light 主题
            EditorTheme(
                id: "solarized-light",
                name: "Solarized 浅色",
                description: "Solarized 浅色主题",
                isBuiltIn: true,
                backgroundColor: "#FDF6E3",
                textColor: "#657B83",
                lineNumberBackgroundColor: "#EEE8D5",
                lineNumberTextColor: "#93A1A1",
                currentLineHighlightColor: "#EEE8D5",
                selectionColor: "#EEE8D5",
                cursorColor: "#657B83",
                keywordColor: "#859900",
                stringColor: "#2AA198",
                numberColor: "#D33682",
                commentColor: "#93A1A1",
                functionColor: "#268BD2",
                typeColor: "#B58900",
                variableColor: "#CB4B16",
                operatorColor: "#859900",
                attributeColor: "#268BD2",
                regexColor: "#2AA198",
                searchMatchColor: "#EEE8D5",
                searchMatchActiveColor: "#93A1A1",
                bracketMatchColor: "#EEE8D5"
            ),

            // Solarized Dark 主题
            EditorTheme(
                id: "solarized-dark",
                name: "Solarized 深色",
                description: "Solarized 深色主题",
                isBuiltIn: true,
                backgroundColor: "#002B36",
                textColor: "#93A1A1",
                lineNumberBackgroundColor: "#073642",
                lineNumberTextColor: "#586E75",
                currentLineHighlightColor: "#073642",
                selectionColor: "#073642",
                cursorColor: "#93A1A1",
                keywordColor: "#859900",
                stringColor: "#2AA198",
                numberColor: "#D33682",
                commentColor: "#586E75",
                functionColor: "#268BD2",
                typeColor: "#B58900",
                variableColor: "#CB4B16",
                operatorColor: "#859900",
                attributeColor: "#268BD2",
                regexColor: "#2AA198",
                searchMatchColor: "#073642",
                searchMatchActiveColor: "#586E75",
                bracketMatchColor: "#073642"
            ),

            // Xcode 主题
            EditorTheme(
                id: "xcode",
                name: "Xcode",
                description: "Xcode 默认主题",
                isBuiltIn: true,
                backgroundColor: "#FFFFFF",
                textColor: "#000000",
                lineNumberBackgroundColor: "#F5F5F5",
                lineNumberTextColor: "#A0A0A0",
                currentLineHighlightColor: "#ECF5FF",
                selectionColor: "#BBDFFF",
                cursorColor: "#000000",
                keywordColor: "#9B2393",
                stringColor: "#C41A16",
                numberColor: "#1C00CF",
                commentColor: "#5D6C79",
                functionColor: "#3900A0",
                typeColor: "#3900A0",
                variableColor: "#000000",
                operatorColor: "#000000",
                attributeColor: "#1C00CF",
                regexColor: "#C41A16",
                searchMatchColor: "#FFF8C5",
                searchMatchActiveColor: "#FFE58F",
                bracketMatchColor: "#BBDFFF"
            ),

            // One Dark 主题
            EditorTheme(
                id: "one-dark",
                name: "One Dark",
                description: "Atom One Dark 主题",
                isBuiltIn: true,
                backgroundColor: "#282C34",
                textColor: "#ABB2BF",
                lineNumberBackgroundColor: "#21252B",
                lineNumberTextColor: "#4B5263",
                currentLineHighlightColor: "#2C313A",
                selectionColor: "#3E4451",
                cursorColor: "#528BFF",
                keywordColor: "#C678DD",
                stringColor: "#98C379",
                numberColor: "#D19A66",
                commentColor: "#5C6370",
                functionColor: "#61AFEF",
                typeColor: "#E5C07B",
                variableColor: "#E06C75",
                operatorColor: "#56B6C2",
                attributeColor: "#D19A66",
                regexColor: "#98C379",
                searchMatchColor: "#3E4451",
                searchMatchActiveColor: "#4B5263",
                bracketMatchColor: "#3E4451"
            )
        ]
    }

    // MARK: - 公开方法

    /// 切换主题
    /// - Parameter theme: 新主题
    func switchTheme(_ theme: EditorTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
            saveSelectedTheme(theme)
        }
    }

    /// 根据ID切换主题
    /// - Parameter themeId: 主题ID
    func switchTheme(withId themeId: String) {
        if let theme = allThemes.first(where: { $0.id == themeId }) {
            switchTheme(theme)
        }
    }

    /// 添加自定义主题
    /// - Parameter theme: 自定义主题
    func addCustomTheme(_ theme: EditorTheme) {
        customThemes.append(theme)
        saveCustomThemes()
    }

    /// 更新自定义主题
    /// - Parameter theme: 自定义主题
    func updateCustomTheme(_ theme: EditorTheme) {
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
            saveCustomThemes()
            // 如果更新的是当前主题，同步更新当前主题
            if currentTheme.id == theme.id {
                currentTheme = theme
            }
        }
    }

    /// 删除自定义主题
    /// - Parameter id: 主题ID
    func deleteCustomTheme(id: String) {
        customThemes.removeAll { $0.id == id }
        saveCustomThemes()
        // 如果删除的是当前主题，切换到第一个内置主题
        if currentTheme.id == id, let firstTheme = builtInThemes.first {
            switchTheme(firstTheme)
        }
    }

    /// 重置为默认主题
    func resetToDefault() {
        if let defaultTheme = builtInThemes.first {
            switchTheme(defaultTheme)
        }
    }

    /// 复制主题（基于现有主题创建自定义主题）
    /// - Parameters:
    ///   - theme: 源主题
    ///   - name: 新主题名称
    /// - Returns: 新主题
    func duplicateTheme(_ theme: EditorTheme, name: String) -> EditorTheme {
        var newTheme = theme
        newTheme.id = UUID().uuidString
        newTheme.name = name
        newTheme.isBuiltIn = false
        return newTheme
    }

    // MARK: - 颜色转换工具

    /// 将十六进制颜色字符串转换为UIColor
    /// - Parameter hex: 十六进制颜色字符串（如 "#FFFFFF"）
    /// - Returns: UIColor
    static func color(from hex: String) -> UIColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let length = hexSanitized.count
        let r, g, b, a: CGFloat

        switch length {
        case 6:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        case 8:
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        default:
            r = 1.0
            g = 1.0
            b = 1.0
            a = 1.0
        }

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    /// 将UIColor转换为十六进制颜色字符串
    /// - Parameter color: UIColor
    /// - Returns: 十六进制颜色字符串
    static func hex(from color: UIColor) -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        color.getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = (Int)(r * 255) << 16 | (Int)(g * 255) << 8 | (Int)(b * 255)

        return String(format: "#%06X", rgb)
    }

    // MARK: - 私有方法

    /// 加载选中的主题
    private func loadSelectedTheme() {
        // builtInThemes和customThemes已在init方法中初始化
        if let themeId = UserDefaults.standard.string(forKey: selectedThemeKey),
           let theme = allThemes.first(where: { $0.id == themeId }) {
            currentTheme = theme
        } else {
            // 默认使用系统主题（浅色/深色）
            let isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
            currentTheme = isDarkMode ? (builtInThemes.first(where: { $0.id == "github-dark" }) ?? builtInThemes[0]) : builtInThemes[0]
        }
    }

    /// 保存选中的主题
    private func saveSelectedTheme(_ theme: EditorTheme) {
        UserDefaults.standard.set(theme.id, forKey: selectedThemeKey)
    }

    /// 加载自定义主题
    private func loadCustomThemes() {
        do {
            if FileManager.default.fileExists(atPath: customThemesURL.path) {
                let data = try Data(contentsOf: customThemesURL)
                customThemes = try JSONDecoder().decode([EditorTheme].self, from: data)
            }
        } catch {
            print("加载自定义主题失败: \(error)")
            customThemes = []
        }
    }

    /// 保存自定义主题
    private func saveCustomThemes() {
        do {
            let data = try JSONEncoder().encode(customThemes)
            try data.write(to: customThemesURL)
        } catch {
            print("保存自定义主题失败: \(error)")
        }
    }
}

// ==============================================================================
// ThemeColor 主题颜色便捷访问
// ==============================================================================

extension EditorThemeManager.EditorTheme {
    /// 背景色UIColor
    var bgColor: UIColor { EditorThemeManager.color(from: backgroundColor) }
    /// 文字色UIColor
    var textUIColor: UIColor { EditorThemeManager.color(from: textColor) }
    /// 行号背景色UIColor
    var lineNumberBgColor: UIColor { EditorThemeManager.color(from: lineNumberBackgroundColor) }
    /// 行号文字色UIColor
    var lineNumberTextUIColor: UIColor { EditorThemeManager.color(from: lineNumberTextColor) }
    /// 当前行高亮色UIColor
    var currentLineHighlightUIColor: UIColor { EditorThemeManager.color(from: currentLineHighlightColor) }
    /// 选中色UIColor
    var selectionUIColor: UIColor { EditorThemeManager.color(from: selectionColor) }
    /// 光标色UIColor
    var cursorUIColor: UIColor { EditorThemeManager.color(from: cursorColor) }
    /// 关键字色UIColor
    var keywordUIColor: UIColor { EditorThemeManager.color(from: keywordColor) }
    /// 字符串色UIColor
    var stringUIColor: UIColor { EditorThemeManager.color(from: stringColor) }
    /// 数字色UIColor
    var numberUIColor: UIColor { EditorThemeManager.color(from: numberColor) }
    /// 注释色UIColor
    var commentUIColor: UIColor { EditorThemeManager.color(from: commentColor) }
    /// 函数色UIColor
    var functionUIColor: UIColor { EditorThemeManager.color(from: functionColor) }
    /// 类型色UIColor
    var typeUIColor: UIColor { EditorThemeManager.color(from: typeColor) }
    /// 变量色UIColor
    var variableUIColor: UIColor { EditorThemeManager.color(from: variableColor) }
    /// 操作符色UIColor
    var operatorUIColor: UIColor { EditorThemeManager.color(from: operatorColor) }
    /// 属性色UIColor
    var attributeUIColor: UIColor { EditorThemeManager.color(from: attributeColor) }
    /// 正则色UIColor
    var regexUIColor: UIColor { EditorThemeManager.color(from: regexColor) }
    /// 搜索匹配色UIColor
    var searchMatchUIColor: UIColor { EditorThemeManager.color(from: searchMatchColor) }
    /// 搜索匹配激活色UIColor
    var searchMatchActiveUIColor: UIColor { EditorThemeManager.color(from: searchMatchActiveColor) }
    /// 括号匹配色UIColor
    var bracketMatchUIColor: UIColor { EditorThemeManager.color(from: bracketMatchColor) }
}

// ==============================================================================
// ThemePickerView 主题选择器视图
// ==============================================================================

struct ThemePickerView: View {
    @ObservedObject var themeManager = EditorThemeManager.shared
    var onSelect: (EditorThemeManager.EditorTheme) -> Void

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("内置主题")) {
                    ForEach(themeManager.builtInThemes) { theme in
                        themeRow(theme)
                    }
                }

                if !themeManager.customThemes.isEmpty {
                    Section(header: Text("自定义主题")) {
                        ForEach(themeManager.customThemes) { theme in
                            themeRow(theme)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("编辑器主题")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func themeRow(_ theme: EditorThemeManager.EditorTheme) -> some View {
        Button(action: {
            onSelect(theme)
        }) {
            HStack(spacing: 12) {
                // 主题预览
                HStack(spacing: 2) {
                    Circle()
                        .fill(Color(theme.bgColor))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    Circle()
                        .fill(Color(theme.keywordUIColor))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color(theme.stringUIColor))
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(Color(theme.commentUIColor))
                        .frame(width: 20, height: 20)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    Text(theme.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if themeManager.currentTheme.id == theme.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 4)
        }
    }
}
