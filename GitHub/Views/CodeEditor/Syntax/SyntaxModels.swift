import UIKit

// ==============================================================================
// SyntaxModels 语法高亮数据模型
// 功能：定义语法Token类型、Token结构体、编程语言枚举
// 位置：语法高亮系统的基础数据层
// ==============================================================================

// MARK: - 语法Token类型枚举

/// 语法Token类型，用于标识代码中不同语法元素的分类
enum SyntaxTokenType: String, CaseIterable {
    case plain              // 普通文本
    case keyword            // 关键字（如 if、else、func）
    case string             // 字符串字面量
    case comment            // 注释
    case number             // 数字字面量
    case function           // 函数名/方法名
    case type               // 类型/类名/结构体名
    case operatorSymbol     // 运算符
    case preprocessor       // 预处理指令（如 #import、#define）
    case decorator          // 装饰器/注解（如 @objc、@Override）
    case property           // 属性访问（如 self.xxx）
    case variable           // 变量名
    case constant           // 常量（如 true、false、nil）
    case url                // URL链接
    case heading            // 标题（Markdown）
    case codeBlock          // 代码块（Markdown）
    case listItem           // 列表项（Markdown）
    case bold               // 粗体（Markdown）
    case italic             // 斜体（Markdown）
    case link               // 链接（Markdown）
    case tag                // HTML/XML标签
    case attribute          // HTML/XML属性
    case yamlKey            // YAML键名
    case yamlValue          // YAML值
}

// MARK: - 语法Token结构体

/// 语法Token，表示代码中一个语法元素及其位置
struct SyntaxToken {
    let type: SyntaxTokenType  // Token类型
    let range: NSRange         // 在文本中的范围（UTF-16编码）
    let text: String           // Token对应的文本内容

    /// 初始化方法
    /// - Parameters:
    ///   - type: Token类型
    ///   - range: 在文本中的范围
    ///   - text: Token对应的文本内容
    init(type: SyntaxTokenType, range: NSRange, text: String) {
        self.type = type
        self.range = range
        self.text = text
    }
}

// MARK: - 编程语言枚举

/// 支持的编程语言枚举
enum ProgrammingLanguage: String, CaseIterable {
    case swift              // Swift
    case python             // Python
    case javascript         // JavaScript
    case typescript         // TypeScript
    case markdown           // Markdown
    case json               // JSON
    case yaml               // YAML
    case xml                // XML
    case html               // HTML
    case css                // CSS
    case sql                // SQL
    case shell              // Shell/Bash
    case java               // Java
    case go                 // Go
    case c                  // C
    case cpp                // C++
    case objectiveC         // Objective-C
    case ruby               // Ruby
    case php                // PHP
    case rust               // Rust
    case kotlin             // Kotlin
    case csharp             // C#
    case scala              // Scala
    case dart               // Dart
    case lua                // Lua
    case r                  // R
    case ini                // INI配置文件
    case toml               // TOML配置文件
    case plainText          // 纯文本（兜底）

    /// 语言显示名称（中文）
    var displayName: String {
        switch self {
        case .swift: return "Swift"
        case .python: return "Python"
        case .javascript: return "JavaScript"
        case .typescript: return "TypeScript"
        case .markdown: return "Markdown"
        case .json: return "JSON"
        case .yaml: return "YAML"
        case .xml: return "XML"
        case .html: return "HTML"
        case .css: return "CSS"
        case .sql: return "SQL"
        case .shell: return "Shell"
        case .java: return "Java"
        case .go: return "Go"
        case .c: return "C"
        case .cpp: return "C++"
        case .objectiveC: return "Objective-C"
        case .ruby: return "Ruby"
        case .php: return "PHP"
        case .rust: return "Rust"
        case .kotlin: return "Kotlin"
        case .csharp: return "C#"
        case .scala: return "Scala"
        case .dart: return "Dart"
        case .lua: return "Lua"
        case .r: return "R"
        case .ini: return "INI"
        case .toml: return "TOML"
        case .plainText: return "纯文本"
        }
    }

    /// 文件扩展名列表
    var extensions: [String] {
        switch self {
        case .swift: return ["swift"]
        case .python: return ["py", "pyw", "pyi"]
        case .javascript: return ["js", "jsx", "mjs", "cjs"]
        case .typescript: return ["ts", "tsx"]
        case .markdown: return ["md", "markdown", "mdx"]
        case .json: return ["json", "jsonc", "json5"]
        case .yaml: return ["yml", "yaml"]
        case .xml: return ["xml", "xsl", "xslt", "svg"]
        case .html: return ["html", "htm", "xhtml"]
        case .css: return ["css", "scss", "sass", "less"]
        case .sql: return ["sql", "mysql", "pgsql"]
        case .shell: return ["sh", "bash", "zsh", "fish"]
        case .java: return ["java"]
        case .go: return ["go"]
        case .c: return ["c", "h"]
        case .cpp: return ["cpp", "cc", "cxx", "hpp", "hh", "hxx"]
        case .objectiveC: return ["m", "mm"]
        case .ruby: return ["rb", "ruby"]
        case .php: return ["php", "phtml"]
        case .rust: return ["rs", "rust"]
        case .kotlin: return ["kt", "kts"]
        case .csharp: return ["cs", "csx"]
        case .scala: return ["scala", "sc"]
        case .dart: return ["dart"]
        case .lua: return ["lua"]
        case .r: return ["r", "R", "Rmd"]
        case .ini: return ["ini", "cfg", "conf", "properties"]
        case .toml: return ["toml"]
        case .plainText: return ["txt", "text"]
        }
    }

    /// 单行注释符号
    var lineCommentSymbol: String? {
        switch self {
        case .swift, .javascript, .typescript, .java, .go, .c, .cpp, .objectiveC, .rust, .kotlin, .csharp, .scala, .dart, .css, .php:
            return "//"
        case .python, .ruby, .shell, .yaml, .r, .ini, .toml:
            return "#"
        case .sql, .lua:
            return "--"
        case .html, .xml, .markdown, .json:
            return nil
        case .plainText:
            return nil
        }
    }

    /// 多行注释开始符号
    var blockCommentStart: String? {
        switch self {
        case .swift, .javascript, .typescript, .java, .go, .c, .cpp, .objectiveC, .rust, .kotlin, .csharp, .scala, .dart, .css, .php, .sql:
            return "/*"
        case .python, .ruby, .shell, .yaml, .r, .lua, .html, .xml, .markdown, .json, .ini, .toml, .plainText:
            return nil
        }
    }

    /// 多行注释结束符号
    var blockCommentEnd: String? {
        switch self {
        case .swift, .javascript, .typescript, .java, .go, .c, .cpp, .objectiveC, .rust, .kotlin, .csharp, .scala, .dart, .css, .php, .sql:
            return "*/"
        case .python, .ruby, .shell, .yaml, .r, .lua, .html, .xml, .markdown, .json, .ini, .toml, .plainText:
            return nil
        }
    }
}
