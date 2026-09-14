import UIKit

// ==============================================================================
// SyntaxTheme 语法高亮主题系统
// 功能：定义主题协议，实现GitHub浅色/深色主题
// 位置：语法高亮系统的主题层
// ==============================================================================

// MARK: - 语法主题协议

/// 语法高亮主题协议，所有主题必须实现此协议
protocol SyntaxTheme {
    var name: String { get }                          // 主题名称
    var backgroundColor: UIColor { get }              // 背景颜色
    var plainTextColor: UIColor { get }               // 普通文本颜色
    func color(for tokenType: SyntaxTokenType) -> UIColor  // 获取指定Token类型的颜色
}

// MARK: - GitHub浅色主题

/// GitHub浅色主题，参考GitHub网页浅色模式配色
struct GitHubLightTheme: SyntaxTheme {
    let name = "GitHub浅色"

    var backgroundColor: UIColor {
        return UIColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
    }

    var plainTextColor: UIColor {
        return UIColor(red: 0.15, green: 0.17, blue: 0.19, alpha: 1.0)
    }

    func color(for tokenType: SyntaxTokenType) -> UIColor {
        switch tokenType {
        case .plain:
            return plainTextColor
        case .keyword:
            // 关键字：深紫红色
            return UIColor(red: 0.67, green: 0.14, blue: 0.52, alpha: 1.0)
        case .string:
            // 字符串：深绿色
            return UIColor(red: 0.07, green: 0.45, blue: 0.18, alpha: 1.0)
        case .comment:
            // 注释：灰绿色
            return UIColor(red: 0.42, green: 0.48, blue: 0.42, alpha: 1.0)
        case .number:
            // 数字：深蓝色
            return UIColor(red: 0.05, green: 0.28, blue: 0.62, alpha: 1.0)
        case .function:
            // 函数名：蓝色
            return UIColor(red: 0.38, green: 0.24, blue: 0.64, alpha: 1.0)
        case .type:
            // 类型：深青色
            return UIColor(red: 0.10, green: 0.40, blue: 0.47, alpha: 1.0)
        case .operatorSymbol:
            // 运算符：深红色
            return UIColor(red: 0.73, green: 0.20, blue: 0.20, alpha: 1.0)
        case .preprocessor:
            // 预处理指令：紫色
            return UIColor(red: 0.55, green: 0.15, blue: 0.70, alpha: 1.0)
        case .decorator:
            // 装饰器/注解：橙色
            return UIColor(red: 0.75, green: 0.45, blue: 0.10, alpha: 1.0)
        case .property:
            // 属性：深青色
            return UIColor(red: 0.10, green: 0.40, blue: 0.47, alpha: 1.0)
        case .variable:
            // 变量：普通文本色
            return plainTextColor
        case .constant:
            // 常量：蓝色
            return UIColor(red: 0.05, green: 0.28, blue: 0.62, alpha: 1.0)
        case .url:
            // URL：蓝色
            return UIColor(red: 0.10, green: 0.35, blue: 0.75, alpha: 1.0)
        case .heading:
            // 标题：深蓝色
            return UIColor(red: 0.10, green: 0.25, blue: 0.55, alpha: 1.0)
        case .codeBlock:
            // 代码块：灰色背景
            return UIColor(red: 0.30, green: 0.35, blue: 0.40, alpha: 1.0)
        case .listItem:
            // 列表项：深灰色
            return UIColor(red: 0.30, green: 0.35, blue: 0.40, alpha: 1.0)
        case .bold:
            // 粗体：普通文本色
            return plainTextColor
        case .italic:
            // 斜体：普通文本色
            return plainTextColor
        case .link:
            // 链接：蓝色
            return UIColor(red: 0.10, green: 0.35, blue: 0.75, alpha: 1.0)
        case .tag:
            // HTML/XML标签：深红色
            return UIColor(red: 0.73, green: 0.20, blue: 0.20, alpha: 1.0)
        case .attribute:
            // HTML/XML属性：深青色
            return UIColor(red: 0.10, green: 0.40, blue: 0.47, alpha: 1.0)
        case .yamlKey:
            // YAML键名：深红色
            return UIColor(red: 0.73, green: 0.20, blue: 0.20, alpha: 1.0)
        case .yamlValue:
            // YAML值：深绿色
            return UIColor(red: 0.07, green: 0.45, blue: 0.18, alpha: 1.0)
        }
    }
}

// MARK: - GitHub深色主题

/// GitHub深色主题，参考GitHub网页深色模式配色
struct GitHubDarkTheme: SyntaxTheme {
    let name = "GitHub深色"

    var backgroundColor: UIColor {
        return UIColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)
    }

    var plainTextColor: UIColor {
        return UIColor(red: 0.85, green: 0.87, blue: 0.89, alpha: 1.0)
    }

    func color(for tokenType: SyntaxTokenType) -> UIColor {
        switch tokenType {
        case .plain:
            return plainTextColor
        case .keyword:
            // 关键字：粉紫色
            return UIColor(red: 0.89, green: 0.35, blue: 0.95, alpha: 1.0)
        case .string:
            // 字符串：浅绿色
            return UIColor(red: 0.45, green: 0.85, blue: 0.55, alpha: 1.0)
        case .comment:
            // 注释：灰绿色
            return UIColor(red: 0.45, green: 0.55, blue: 0.45, alpha: 1.0)
        case .number:
            // 数字：浅蓝色
            return UIColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        case .function:
            // 函数名：浅蓝色
            return UIColor(red: 0.65, green: 0.75, blue: 1.0, alpha: 1.0)
        case .type:
            // 类型：青色
            return UIColor(red: 0.40, green: 0.80, blue: 0.85, alpha: 1.0)
        case .operatorSymbol:
            // 运算符：浅红色
            return UIColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1.0)
        case .preprocessor:
            // 预处理指令：粉紫色
            return UIColor(red: 0.85, green: 0.45, blue: 0.95, alpha: 1.0)
        case .decorator:
            // 装饰器/注解：浅橙色
            return UIColor(red: 0.95, green: 0.65, blue: 0.30, alpha: 1.0)
        case .property:
            // 属性：青色
            return UIColor(red: 0.40, green: 0.80, blue: 0.85, alpha: 1.0)
        case .variable:
            // 变量：普通文本色
            return plainTextColor
        case .constant:
            // 常量：浅蓝色
            return UIColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0)
        case .url:
            // URL：浅蓝色
            return UIColor(red: 0.45, green: 0.65, blue: 0.95, alpha: 1.0)
        case .heading:
            // 标题：浅蓝色
            return UIColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 1.0)
        case .codeBlock:
            // 代码块：灰色
            return UIColor(red: 0.55, green: 0.60, blue: 0.65, alpha: 1.0)
        case .listItem:
            // 列表项：浅灰色
            return UIColor(red: 0.60, green: 0.65, blue: 0.70, alpha: 1.0)
        case .bold:
            // 粗体：普通文本色
            return plainTextColor
        case .italic:
            // 斜体：普通文本色
            return plainTextColor
        case .link:
            // 链接：浅蓝色
            return UIColor(red: 0.45, green: 0.65, blue: 0.95, alpha: 1.0)
        case .tag:
            // HTML/XML标签：浅红色
            return UIColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1.0)
        case .attribute:
            // HTML/XML属性：青色
            return UIColor(red: 0.40, green: 0.80, blue: 0.85, alpha: 1.0)
        case .yamlKey:
            // YAML键名：浅红色
            return UIColor(red: 0.95, green: 0.50, blue: 0.50, alpha: 1.0)
        case .yamlValue:
            // YAML值：浅绿色
            return UIColor(red: 0.45, green: 0.85, blue: 0.55, alpha: 1.0)
        }
    }
}

// MARK: - 主题管理器

/// 主题管理器，负责管理当前主题和主题切换
class ThemeManager {
    static let shared = ThemeManager()

    private init() {}

    /// 当前主题（根据系统外观自动切换）
    var currentTheme: SyntaxTheme {
        if UITraitCollection.current.userInterfaceStyle == .dark {
            return GitHubDarkTheme()
        } else {
            return GitHubLightTheme()
        }
    }

    /// 获取指定外观模式的主题
    /// - Parameter style: 外观模式（浅色/深色）
    /// - Returns: 对应的主题
    func theme(for style: UIUserInterfaceStyle) -> SyntaxTheme {
        switch style {
        case .dark:
            return GitHubDarkTheme()
        case .light, .unspecified:
            return GitHubLightTheme()
        @unknown default:
            return GitHubLightTheme()
        }
    }
}
