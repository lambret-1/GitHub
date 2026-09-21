import Foundation

// ==============================================================================
// CodeFormatter 代码格式化工具
// 功能：对常见代码格式进行自动格式化（JSON、XML、Swift等）
// 位置：工具层，被代码编辑器调用
// 设计原则：单例模式，按文件类型分发格式化器，格式化失败返回原始内容
// ==============================================================================

class CodeFormatter {
    // MARK: - 共享实例

    static let shared = CodeFormatter()

    private init() {}

    // MARK: - 公共方法

    /// 根据文件扩展名格式化代码
    /// - Parameters:
    ///   - code: 原始代码内容
    ///   - fileName: 文件名（用于判断格式）
    /// - Returns: 格式化后的代码，如果格式化失败则返回原始内容
    func format(code: String, fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()

        switch ext {
        case "json":
            return formatJSON(code)
        case "xml", "plist", "storyboard", "xib":
            return formatXML(code)
        case "swift":
            return formatSwift(code)
        case "yml", "yaml":
            // YAML对缩进敏感，不自动格式化，直接返回
            return code
        default:
            // 未知格式，尝试通用格式化（仅处理多余空行）
            return formatGeneric(code)
        }
    }

    /// 判断文件是否支持格式化
    /// - Parameter fileName: 文件名
    /// - Returns: 是否支持格式化
    func isFormatSupported(fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        // 支持所有常见的文本/代码格式（YAML除外，因为对缩进敏感）
        let unsupportedExtensions = ["yml", "yaml"]
        return !unsupportedExtensions.contains(ext)
    }

    // MARK: - JSON格式化

    /// 格式化JSON代码
    /// - Parameter code: 原始JSON内容
    /// - Returns: 格式化后的JSON，如果解析失败则返回原始内容
    private func formatJSON(_ code: String) -> String {
        guard let data = code.data(using: .utf8) else {
            DebugLogger.format("❌ JSON格式化失败：无法转换为Data")
            return code
        }

        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
            let formattedData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
            guard let formattedString = String(data: formattedData, encoding: .utf8) else {
                DebugLogger.format("❌ JSON格式化失败：无法转换为String")
                return code
            }
            DebugLogger.format("✅ JSON格式化成功")
            return formattedString
        } catch {
            DebugLogger.format("❌ JSON格式化失败：\(error.localizedDescription)")
            return code
        }
    }

    // MARK: - XML格式化

    /// 格式化XML代码
    /// - Parameter code: 原始XML内容
    /// - Returns: 格式化后的XML
    private func formatXML(_ code: String) -> String {
        // iOS上XMLDocument不可用，直接使用简单的缩进格式化
        DebugLogger.format("✅ XML简单格式化成功")
        return simpleXMLFormat(code)
    }

    /// 简单的XML缩进格式化（作为XMLDocument失败时的备选）
    /// - Parameter code: 原始XML内容
    /// - Returns: 简单格式化后的XML
    private func simpleXMLFormat(_ code: String) -> String {
        var result = ""
        var indentLevel = 0
        let indent = "    " // 4个空格缩进

        // 按行处理
        let lines = code.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            // 如果是闭合标签，减少缩进
            if trimmed.hasPrefix("</") {
                indentLevel = max(0, indentLevel - 1)
            }

            // 添加当前缩进
            result += String(repeating: indent, count: indentLevel) + trimmed + "\n"

            // 如果是开始标签（不是自闭合），增加缩进
            if trimmed.hasPrefix("<") && !trimmed.hasPrefix("</") && !trimmed.hasSuffix("/>") && !trimmed.contains("</") {
                indentLevel += 1
            }
        }

        return result.trimmingCharacters(in: .newlines)
    }

    // MARK: - Swift格式化（简单版）

    /// 简单的Swift格式化（仅处理缩进和多余空行，不做完整的语法格式化）
    /// - Parameter code: 原始Swift代码
    /// - Returns: 简单格式化后的Swift代码
    private func formatSwift(_ code: String) -> String {
        var result = ""
        var indentLevel = 0
        let indent = "    " // 4个空格缩进
        var previousLineEmpty = false

        let lines = code.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // 处理连续空行（只保留一个空行）
            if trimmed.isEmpty {
                if !previousLineEmpty {
                    result += "\n"
                    previousLineEmpty = true
                }
                continue
            }
            previousLineEmpty = false

            // 计算当前行的缩进变化
            var currentIndent = indentLevel

            // 如果行以闭合括号开头，减少缩进
            if trimmed.hasPrefix("}") || trimmed.hasPrefix("]") || trimmed.hasPrefix(")") {
                currentIndent = max(0, currentIndent - 1)
            }

            // 添加当前缩进
            result += String(repeating: indent, count: currentIndent) + trimmed + "\n"

            // 更新下一行的缩进级别
            // 统计开始括号和结束括号的数量
            let openBraces = trimmed.filter { $0 == "{" || $0 == "[" || $0 == "(" }.count
            let closeBraces = trimmed.filter { $0 == "}" || $0 == "]" || $0 == ")" }.count
            indentLevel += openBraces - closeBraces
            indentLevel = max(0, indentLevel)
        }

        DebugLogger.format("✅ Swift简单格式化成功")
        return result.trimmingCharacters(in: .newlines) + "\n"
    }

    // MARK: - 通用格式化

    /// 通用格式化（仅处理多余空行和行尾空格）
    /// - Parameter code: 原始代码
    /// - Returns: 格式化后的代码
    private func formatGeneric(_ code: String) -> String {
        var result = ""
        var previousLineEmpty = false

        let lines = code.components(separatedBy: .newlines)

        for line in lines {
            // 去除行尾空格
            let trimmedEnd = line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)

            if trimmedEnd.trimmingCharacters(in: .whitespaces).isEmpty {
                if !previousLineEmpty {
                    result += "\n"
                    previousLineEmpty = true
                }
            } else {
                result += trimmedEnd + "\n"
                previousLineEmpty = false
            }
        }

        return result.trimmingCharacters(in: .newlines) + "\n"
    }
}
