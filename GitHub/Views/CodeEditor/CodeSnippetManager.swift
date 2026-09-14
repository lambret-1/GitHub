import Foundation
import SwiftUI

// ==============================================================================
// CodeSnippetManager 代码片段管理器
// 功能：管理内置和用户自定义代码片段，支持触发词展开、占位符跳转
// 位置：文件编辑器的代码片段核心层
// 设计原则：按语言分类，支持用户自定义，本地持久化存储
// ==============================================================================

class CodeSnippetManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = CodeSnippetManager()

    private init() {
        loadUserSnippets()
    }

    // MARK: - 代码片段数据模型

    struct Snippet: Codable, Identifiable {
        let id: String
        var trigger: String          // 触发词
        var name: String             // 片段名称
        var description: String      // 简短描述
        var code: String             // 代码模板（$1, $2 为占位符，$0 为最终光标位置）
        var language: String         // 适用语言（文件扩展名，如 "swift", "js"）
        var isBuiltIn: Bool          // 是否内置片段

        enum CodingKeys: String, CodingKey {
            case id, trigger, name, description, code, language, isBuiltIn
        }
    }

    // MARK: - 发布属性

    /// 所有代码片段
    @Published private(set) var allSnippets: [Snippet] = []

    /// 用户自定义片段
    @Published private(set) var userSnippets: [Snippet] = []

    /// 内置片段
    @Published private(set) var builtInSnippets: [Snippet] = []

    // MARK: - 私有属性

    /// 用户片段存储路径
    private let userSnippetsURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("CodeSnippets.json")
    }()

    // MARK: - 内置代码片段定义

    /// 获取所有内置代码片段
    private func builtInSnippetsList() -> [Snippet] {
        return [
            // MARK: - Swift 片段
            Snippet(
                id: "swift-if-else",
                trigger: "if",
                name: "if-else 语句",
                description: "条件判断语句",
                code: "if $1 {\n    $0\n} else {\n    \n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-for-in",
                trigger: "for",
                name: "for-in 循环",
                description: "快速枚举循环",
                code: "for $1 in $2 {\n    $0\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-func",
                trigger: "func",
                name: "函数定义",
                description: "定义一个函数",
                code: "func $1($2) -> $3 {\n    $0\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-class",
                trigger: "class",
                name: "类定义",
                description: "定义一个类",
                code: "class $1: $2 {\n    $0\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-struct",
                trigger: "struct",
                name: "结构体定义",
                description: "定义一个结构体",
                code: "struct $1: $2 {\n    $0\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-guard",
                trigger: "guard",
                name: "guard 语句",
                description: "提前退出条件判断",
                code: "guard $1 else {\n    $0\n    return\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-dispatch-async",
                trigger: "async",
                name: "异步派发",
                description: "GCD 异步执行",
                code: "DispatchQueue.$1.async {\n    $0\n}",
                language: "swift",
                isBuiltIn: true
            ),
            Snippet(
                id: "swift-mark",
                trigger: "mark",
                name: "MARK 标记",
                description: "代码分区标记",
                code: "// MARK: - $0",
                language: "swift",
                isBuiltIn: true
            ),

            // MARK: - JavaScript/TypeScript 片段
            Snippet(
                id: "js-arrow-func",
                trigger: "arrow",
                name: "箭头函数",
                description: "ES6 箭头函数",
                code: "const $1 = ($2) => {\n    $0\n}",
                language: "js",
                isBuiltIn: true
            ),
            Snippet(
                id: "js-console-log",
                trigger: "log",
                name: "控制台输出",
                description: "console.log 输出",
                code: "console.log($0)",
                language: "js",
                isBuiltIn: true
            ),
            Snippet(
                id: "js-try-catch",
                trigger: "try",
                name: "try-catch",
                description: "异常捕获",
                code: "try {\n    $0\n} catch (error) {\n    console.error(error)\n}",
                language: "js",
                isBuiltIn: true
            ),

            // MARK: - Python 片段
            Snippet(
                id: "py-def",
                trigger: "def",
                name: "函数定义",
                description: "定义 Python 函数",
                code: "def $1($2):\n    $0",
                language: "py",
                isBuiltIn: true
            ),
            Snippet(
                id: "py-class",
                trigger: "class",
                name: "类定义",
                description: "定义 Python 类",
                code: "class $1:\n    def __init__(self$2):\n        $0",
                language: "py",
                isBuiltIn: true
            ),
            Snippet(
                id: "py-if-name",
                trigger: "main",
                name: "主函数入口",
                description: "Python 主函数入口",
                code: "if __name__ == \"__main__\":\n    $0",
                language: "py",
                isBuiltIn: true
            ),

            // MARK: - Java 片段
            Snippet(
                id: "java-main",
                trigger: "main",
                name: "主方法",
                description: "Java 主方法",
                code: "public static void main(String[] args) {\n    $0\n}",
                language: "java",
                isBuiltIn: true
            ),
            Snippet(
                id: "java-sysout",
                trigger: "sout",
                name: "系统输出",
                description: "System.out.println",
                code: "System.out.println($0);",
                language: "java",
                isBuiltIn: true
            ),

            // MARK: - C/C++ 片段
            Snippet(
                id: "c-include",
                trigger: "inc",
                name: "头文件包含",
                description: "#include 头文件",
                code: "#include <$0>",
                language: "c",
                isBuiltIn: true
            ),
            Snippet(
                id: "c-main",
                trigger: "main",
                name: "主函数",
                description: "C 语言主函数",
                code: "int main(int argc, char *argv[]) {\n    $0\n    return 0;\n}",
                language: "c",
                isBuiltIn: true
            ),

            // MARK: - HTML 片段
            Snippet(
                id: "html-doctype",
                trigger: "html",
                name: "HTML5 文档",
                description: "HTML5 基础文档结构",
                code: "<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n    <meta charset=\"UTF-8\">\n    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n    <title>$1</title>\n</head>\n<body>\n    $0\n</body>\n</html>",
                language: "html",
                isBuiltIn: true
            ),

            // MARK: - CSS 片段
            Snippet(
                id: "css-flex",
                trigger: "flex",
                name: "Flexbox 布局",
                description: "Flex 布局基础",
                code: "display: flex;\njustify-content: $1;\nalign-items: $2;",
                language: "css",
                isBuiltIn: true
            ),

            // MARK: - SQL 片段
            Snippet(
                id: "sql-select",
                trigger: "select",
                name: "查询语句",
                description: "SELECT 查询",
                code: "SELECT $1 FROM $2 WHERE $3;",
                language: "sql",
                isBuiltIn: true
            ),
            Snippet(
                id: "sql-insert",
                trigger: "insert",
                name: "插入语句",
                description: "INSERT 插入数据",
                code: "INSERT INTO $1 ($2) VALUES ($3);",
                language: "sql",
                isBuiltIn: true
            ),

            // MARK: - Shell 片段
            Snippet(
                id: "sh-if",
                trigger: "if",
                name: "if 语句",
                description: "Shell 条件判断",
                code: "if [ $1 ]; then\n    $0\nfi",
                language: "sh",
                isBuiltIn: true
            ),
            Snippet(
                id: "sh-for",
                trigger: "for",
                name: "for 循环",
                description: "Shell for 循环",
                code: "for $1 in $2; do\n    $0\ndone",
                language: "sh",
                isBuiltIn: true
            ),

            // MARK: - Markdown 片段
            Snippet(
                id: "md-code",
                trigger: "code",
                name: "代码块",
                description: "Markdown 代码块",
                code: "```$1\n$0\n```",
                language: "md",
                isBuiltIn: true
            ),
            Snippet(
                id: "md-table",
                trigger: "table",
                name: "表格",
                description: "Markdown 表格",
                code: "| $1 | $2 |\n| --- | --- |\n| $3 | $4 |",
                language: "md",
                isBuiltIn: true
            ),

            // MARK: - YAML 片段
            Snippet(
                id: "yml-key-value",
                trigger: "kv",
                name: "键值对",
                description: "YAML 键值对",
                code: "$1: $0",
                language: "yml",
                isBuiltIn: true
            ),

            // MARK: - JSON 片段
            Snippet(
                id: "json-object",
                trigger: "obj",
                name: "JSON 对象",
                description: "JSON 对象模板",
                code: "{\n    \"$1\": $0\n}",
                language: "json",
                isBuiltIn: true
            )
        ]
    }

    // MARK: - 公开方法

    /// 获取指定语言的代码片段
    /// - Parameter language: 文件扩展名
    /// - Returns: 匹配的代码片段列表
    func getSnippets(for language: String) -> [Snippet] {
        let lowerLanguage = language.lowercased()
        return allSnippets.filter { snippet in
            snippet.language.lowercased() == lowerLanguage || snippet.language == "all"
        }
    }

    /// 根据触发词查找代码片段
    /// - Parameters:
    ///   - trigger: 触发词
    ///   - language: 文件扩展名
    /// - Returns: 匹配的代码片段
    func findSnippet(trigger: String, language: String) -> Snippet? {
        let lowerTrigger = trigger.lowercased()
        let lowerLanguage = language.lowercased()
        return allSnippets.first { snippet in
            snippet.trigger.lowercased() == lowerTrigger &&
            (snippet.language.lowercased() == lowerLanguage || snippet.language == "all")
        }
    }

    /// 展开代码片段，替换占位符
    /// - Parameter snippet: 代码片段
    /// - Returns: 展开后的代码和占位符位置列表
    func expandSnippet(_ snippet: Snippet) -> (code: String, placeholderRanges: [Range<String.Index>], finalCursorPosition: String.Index?) {
        var code = snippet.code
        var placeholderRanges: [Range<String.Index>] = []
        var finalCursorPosition: String.Index?

        // 替换 $0 为最终光标位置标记
        if let range = code.range(of: "$0") {
            finalCursorPosition = range.lowerBound
            code.replaceSubrange(range, with: "")
        }

        // 查找所有 $1, $2, ... 占位符
        var placeholderIndex = 1
        while let range = code.range(of: "$\(placeholderIndex)") {
            placeholderRanges.append(range)
            code.replaceSubrange(range, with: "")
            placeholderIndex += 1
        }

        return (code, placeholderRanges, finalCursorPosition)
    }

    /// 添加用户自定义代码片段
    /// - Parameter snippet: 代码片段
    func addUserSnippet(_ snippet: Snippet) {
        userSnippets.append(snippet)
        saveUserSnippets()
        reloadAllSnippets()
    }

    /// 更新用户自定义代码片段
    /// - Parameter snippet: 代码片段
    func updateUserSnippet(_ snippet: Snippet) {
        if let index = userSnippets.firstIndex(where: { $0.id == snippet.id }) {
            userSnippets[index] = snippet
            saveUserSnippets()
            reloadAllSnippets()
        }
    }

    /// 删除用户自定义代码片段
    /// - Parameter id: 片段ID
    func deleteUserSnippet(id: String) {
        userSnippets.removeAll { $0.id == id }
        saveUserSnippets()
        reloadAllSnippets()
    }

    /// 重置为内置片段（删除所有用户自定义片段）
    func resetToBuiltIn() {
        userSnippets.removeAll()
        saveUserSnippets()
        reloadAllSnippets()
    }

    // MARK: - 私有方法

    /// 重新加载所有片段
    private func reloadAllSnippets() {
        builtInSnippets = builtInSnippetsList()
        allSnippets = builtInSnippets + userSnippets
    }

    /// 加载用户自定义片段
    private func loadUserSnippets() {
        do {
            if FileManager.default.fileExists(atPath: userSnippetsURL.path) {
                let data = try Data(contentsOf: userSnippetsURL)
                userSnippets = try JSONDecoder().decode([Snippet].self, from: data)
            }
        } catch {
            print("加载用户代码片段失败: \(error)")
            userSnippets = []
        }
        reloadAllSnippets()
    }

    /// 保存用户自定义片段
    private func saveUserSnippets() {
        do {
            let data = try JSONEncoder().encode(userSnippets)
            try data.write(to: userSnippetsURL)
        } catch {
            print("保存用户代码片段失败: \(error)")
        }
    }
}

// ==============================================================================
// SnippetTriggerViewModifier 代码片段触发修饰符
// 功能：在编辑时检测触发词，自动展开代码片段
// ==============================================================================

struct SnippetTriggerModifier: ViewModifier {
    @ObservedObject var snippetManager = CodeSnippetManager.shared
    var language: String
    @Binding var text: String
    var onSnippetExpanded: ((String, [Range<String.Index>]) -> Void)?

    func body(content: Content) -> some View {
        content
            .onChange(of: text) { newValue in
                // 检测是否输入了触发词（简单实现：检测最后输入的单词）
                checkForSnippetTrigger(in: newValue)
            }
    }

    /// 检测触发词
    private func checkForSnippetTrigger(in text: String) {
        // 简单实现：获取最后一个单词
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        guard let lastWord = words.last?.trimmingCharacters(in: .punctuationCharacters),
              !lastWord.isEmpty else { return }

        // 查找匹配的代码片段
        if let snippet = snippetManager.findSnippet(trigger: lastWord, language: language) {
            // 展开代码片段
            let result = snippetManager.expandSnippet(snippet)

            // 替换触发词为展开后的代码
            if let range = text.range(of: lastWord, options: .backwards) {
                var newText = text
                newText.replaceSubrange(range, with: result.code)
                self.text = newText
                onSnippetExpanded?(result.code, result.placeholderRanges)
            }
        }
    }
}

extension View {
    /// 添加代码片段触发支持
    /// - Parameters:
    ///   - language: 文件扩展名
    ///   - text: 文本绑定
    ///   - onSnippetExpanded: 片段展开回调
    /// - Returns: 修饰后的视图
    func snippetTrigger(language: String, text: Binding<String>, onSnippetExpanded: ((String, [Range<String.Index>]) -> Void)? = nil) -> some View {
        modifier(SnippetTriggerModifier(language: language, text: text, onSnippetExpanded: onSnippetExpanded))
    }
}
