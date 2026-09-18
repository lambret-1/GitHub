import Foundation
import SwiftUI

// ==============================================================================
// SymbolNavigator 符号导航器
// 功能：扫描源代码文件，提取函数、类、结构体、协议等符号，支持快速跳转
// 位置：文件编辑器的符号导航核心层
// 设计原则：基于正则表达式的轻量级符号提取，支持多种编程语言
// ==============================================================================

class SymbolNavigator: ObservableObject {
    // MARK: - 符号数据模型

    enum SymbolType: String, Codable, CaseIterable {
        case function = "函数"
        case method = "方法"
        case `class` = "类"
        case structType = "结构体"
        case `protocol` = "协议"
        case enumType = "枚举"
        case extensionType = "扩展"
        case `typealias` = "类型别名"
        case variable = "变量"
        case constant = "常量"
        case initMethod = "初始化方法"
        case deinitMethod = "销毁方法"
        case subscriptMethod = "下标方法"
        case importStatement = "导入"
        case mark = "标记"
        case unknown = "未知"

        /// 符号对应的系统图标
        var systemImage: String {
            switch self {
            case .function, .method: return "function"
            case .class: return "c.square"
            case .structType: return "s.square"
            case .protocol: return "p.square"
            case .enumType: return "e.square"
            case .extensionType: return "x.square"
            case .typealias: return "t.square"
            case .variable: return "var"
            case .constant: return "let"
            case .initMethod: return "i.circle"
            case .deinitMethod: return "d.circle"
            case .subscriptMethod: return "square.grid.3x3"
            case .importStatement: return "arrow.down.doc"
            case .mark: return "number"
            case .unknown: return "questionmark.square"
            }
        }

        /// 符号对应的颜色
        var color: Color {
            switch self {
            case .function, .method, .initMethod, .deinitMethod, .subscriptMethod: return .purple
            case .class, .structType, .protocol, .enumType, .extensionType, .typealias: return .blue
            case .variable, .constant: return .orange
            case .importStatement: return .gray
            case .mark: return .green
            case .unknown: return .gray
            }
        }
    }

    struct Symbol: Identifiable, Codable {
        let id: UUID
        let name: String
        let type: SymbolType
        let lineNumber: Int
        let column: Int
        let range: NSRange
        let parent: String?
        let parameters: String?
        let returnType: String?
        let accessLevel: String?

        enum CodingKeys: String, CodingKey {
            case id, name, type, lineNumber, column, range, parent, parameters, returnType, accessLevel
        }

        init(id: UUID = UUID(), name: String, type: SymbolType, lineNumber: Int, column: Int, range: NSRange, parent: String? = nil, parameters: String? = nil, returnType: String? = nil, accessLevel: String? = nil) {
            self.id = id
            self.name = name
            self.type = type
            self.lineNumber = lineNumber
            self.column = column
            self.range = range
            self.parent = parent
            self.parameters = parameters
            self.returnType = returnType
            self.accessLevel = accessLevel
        }
    }

    // MARK: - 发布属性

    /// 当前文件的所有符号
    @Published private(set) var symbols: [Symbol] = []

    /// 当前光标所在的符号
    @Published private(set) var currentSymbol: Symbol?

    /// 是否正在解析
    @Published private(set) var isParsing: Bool = false

    // MARK: - 私有属性

    /// 解析任务
    private var parseWorkItem: DispatchWorkItem?

    // MARK: - 公开方法

    /// 解析文件内容，提取所有符号
    /// - Parameters:
    ///   - content: 文件内容
    ///   - language: 文件扩展名
    func parseSymbols(in content: String, language: String) {
        isParsing = true

        // 取消之前的解析任务
        parseWorkItem?.cancel()

        // 延迟解析，避免在用户连续输入时频繁解析
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            let symbols = self.extractSymbols(from: content, language: language)

            DispatchQueue.main.async {
                self.symbols = symbols
                self.isParsing = false
            }
        }

        parseWorkItem = workItem
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }

    /// 更新当前光标所在的符号
    /// - Parameters:
    ///   - lineNumber: 当前行号
    ///   - column: 当前列号
    func updateCurrentSymbol(at lineNumber: Int, column: Int) {
        // 找到光标所在行之前的最后一个符号
        let symbolAtCursor = symbols.last { $0.lineNumber <= lineNumber }
        currentSymbol = symbolAtCursor
    }

    /// 获取指定类型的符号
    /// - Parameter type: 符号类型
    /// - Returns: 匹配的符号列表
    func symbols(ofType type: SymbolType) -> [Symbol] {
        return symbols.filter { $0.type == type }
    }

    /// 搜索符号
    /// - Parameter query: 搜索关键词
    /// - Returns: 匹配的符号列表
    func searchSymbols(_ query: String) -> [Symbol] {
        guard !query.isEmpty else { return symbols }
        let lowerQuery = query.lowercased()
        return symbols.filter { $0.name.lowercased().contains(lowerQuery) }
    }

    // MARK: - 私有方法

    /// 从文件内容中提取符号
    /// - Parameters:
    ///   - content: 文件内容
    ///   - language: 文件扩展名
    /// - Returns: 符号列表
    private func extractSymbols(from content: String, language: String) -> [Symbol] {
        let lowerLanguage = language.lowercased()
        var symbols: [Symbol] = []

        // 按行解析
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // 跳过空行和注释
            guard !trimmedLine.isEmpty else { continue }
            guard !trimmedLine.hasPrefix("//") && !trimmedLine.hasPrefix("#") && !trimmedLine.hasPrefix("*") else {
                // MARK标记特殊处理
                if trimmedLine.contains("MARK:") {
                    if let symbol = parseMarkComment(trimmedLine, lineNumber: lineNumber, column: 0, content: content) {
                        symbols.append(symbol)
                    }
                }
                continue
            }

            // 根据语言类型解析
            switch lowerLanguage {
            case "swift":
                if let symbol = parseSwiftLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "js", "jsx", "ts", "tsx":
                if let symbol = parseJavaScriptLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "py":
                if let symbol = parsePythonLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "java":
                if let symbol = parseJavaLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "c", "cpp", "h", "hpp", "m", "mm":
                if let symbol = parseCLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "go":
                if let symbol = parseGoLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "rs":
                if let symbol = parseRustLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "rb":
                if let symbol = parseRubyLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "php":
                if let symbol = parsePHPLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            case "sh", "bash", "zsh":
                if let symbol = parseShellLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            default:
                // 通用解析：只解析函数定义
                if let symbol = parseGenericFunctionLine(trimmedLine, lineNumber: lineNumber, column: line.distance(from: line.startIndex, to: trimmedLine.startIndex), content: content) {
                    symbols.append(symbol)
                }
            }
        }

        return symbols
    }

    // MARK: - Swift 解析

    private func parseSwiftLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let nsLine = line as NSString
        let fullRange = NSRange(location: 0, length: nsLine.length)

        // 访问级别
        var accessLevel: String?
        var remainingLine = line

        // 提取访问级别
        let accessLevels = ["public", "private", "fileprivate", "internal", "open"]
        for level in accessLevels {
            if remainingLine.hasPrefix(level + " ") {
                accessLevel = level
                remainingLine = String(remainingLine.dropFirst(level.count + 1))
                break
            }
        }

        // 类定义
        if let range = remainingLine.range(of: #"^(?:final\s+)?(?:class|struct|protocol|enum|extension)\s+(\w+)"#, options: .regularExpression) {
            let typeStr = String(remainingLine[range]).components(separatedBy: .whitespaces).first ?? ""
            let name = String(remainingLine[range].split(separator: " ").last ?? "")
            let type: SymbolType
            switch typeStr {
            case "class": type = .class
            case "struct": type = .structType
            case "protocol": type = .protocol
            case "enum": type = .enumType
            case "extension": type = .extensionType
            default: type = .unknown
            }
            return Symbol(name: name, type: type, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 函数定义
        if let range = remainingLine.range(of: #"^(?:static\s+|class\s+|final\s+)?func\s+(\w+)"#, options: .regularExpression) {
            let name = String(remainingLine[range].split(separator: " ").last ?? "")
            // 提取参数
            var parameters: String?
            if let parenStart = remainingLine.firstIndex(of: "("),
               let parenEnd = remainingLine.firstIndex(of: ")") {
                parameters = String(remainingLine[parenStart...parenEnd])
            }
            // 提取返回类型
            var returnType: String?
            if let arrowRange = remainingLine.range(of: "->") {
                returnType = String(remainingLine[arrowRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange, parameters: parameters, returnType: returnType, accessLevel: accessLevel)
        }

        // 初始化方法
        if remainingLine.hasPrefix("init(") || remainingLine.hasPrefix("init?(") || remainingLine.hasPrefix("init!(") {
            return Symbol(name: "init", type: .initMethod, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 销毁方法
        if remainingLine.hasPrefix("deinit") {
            return Symbol(name: "deinit", type: .deinitMethod, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 下标方法
        if remainingLine.hasPrefix("subscript") {
            return Symbol(name: "subscript", type: .subscriptMethod, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 类型别名
        if remainingLine.hasPrefix("typealias ") {
            let name = String(remainingLine.dropFirst(10)).components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: name, type: .typealias, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 变量/常量
        if remainingLine.hasPrefix("var ") || remainingLine.hasPrefix("let ") {
            let isConstant = remainingLine.hasPrefix("let ")
            let name = String(remainingLine.dropFirst(isConstant ? 4 : 4)).components(separatedBy: CharacterSet(charactersIn: ":= ")).first ?? ""
            return Symbol(name: name, type: isConstant ? .constant : .variable, lineNumber: lineNumber, column: column, range: fullRange, accessLevel: accessLevel)
        }

        // 导入语句
        if remainingLine.hasPrefix("import ") {
            let name = String(remainingLine.dropFirst(7))
            return Symbol(name: name, type: .importStatement, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - JavaScript 解析

    private func parseJavaScriptLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 类定义
        if line.hasPrefix("class ") {
            let name = String(line.dropFirst(6)).components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: name, type: .class, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 函数定义
        if line.hasPrefix("function ") {
            let name = String(line.dropFirst(9)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 箭头函数/方法
        if let range = line.range(of: #"^(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("#, options: .regularExpression) {
            let name = String(line[range]).split(separator: " ")[1]
            return Symbol(name: String(name), type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 类方法
        if let range = line.range(of: #"^(\w+)\s*\("#, options: .regularExpression) {
            let name = String(line[range]).replacingOccurrences(of: "(", with: "").trimmingCharacters(in: .whitespaces)
            if !["if", "for", "while", "switch", "catch", "return", "new", "typeof", "instanceof"].contains(name) {
                return Symbol(name: name, type: .method, lineNumber: lineNumber, column: column, range: fullRange)
            }
        }

        return nil
    }

    // MARK: - Python 解析

    private func parsePythonLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 类定义
        if line.hasPrefix("class ") {
            let name = String(line.dropFirst(6)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .class, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 函数定义
        if line.hasPrefix("def ") {
            let name = String(line.dropFirst(4)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 异步函数
        if line.hasPrefix("async def ") {
            let name = String(line.dropFirst(10)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 导入
        if line.hasPrefix("import ") || line.hasPrefix("from ") {
            return Symbol(name: line, type: .importStatement, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - Java 解析

    private func parseJavaLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 类/接口/枚举定义
        if let range = line.range(of: #"(?:public|private|protected)?\s*(?:static|final|abstract)?\s*(class|interface|enum)\s+(\w+)"#, options: .regularExpression) {
            let match = String(line[range])
            let typeStr = match.contains("class") ? "class" : match.contains("interface") ? "interface" : "enum"
            let name = match.split(separator: " ").last ?? ""
            let type: SymbolType = typeStr == "class" ? .class : typeStr == "interface" ? .protocol : .enumType
            return Symbol(name: String(name), type: type, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 方法定义
        if let range = line.range(of: #"(?:public|private|protected)?\s*(?:static|final|abstract|synchronized)?\s*(?:[\w<>\[\]]+)\s+(\w+)\s*\("#, options: .regularExpression) {
            let match = String(line[range])
            let name = match.split(separator: "(").first?.split(separator: " ").last ?? ""
            return Symbol(name: String(name), type: .method, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - C/C++ 解析

    private func parseCLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 函数定义
        if let range = line.range(of: #"^(?:[\w\s\*]+)\s+(\w+)\s*\([^)]*\)\s*\{"#, options: .regularExpression) {
            let match = String(line[range])
            let name = match.split(separator: "(").first?.split(separator: " ").last ?? ""
            return Symbol(name: String(name), type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 结构体/枚举定义
        if line.hasPrefix("struct ") || line.hasPrefix("enum ") || line.hasPrefix("typedef struct ") || line.hasPrefix("typedef enum ") {
            let typeStr = line.contains("struct") ? "struct" : "enum"
            let name = line.split(separator: " ").last?.replacingOccurrences(of: "{", with: "") ?? ""
            return Symbol(name: String(name), type: typeStr == "struct" ? .structType : .enumType, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - Go 解析

    private func parseGoLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 函数定义
        if line.hasPrefix("func ") {
            let name = String(line.dropFirst(5)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 方法定义
        if line.hasPrefix("func (") {
            if let parenEnd = line.firstIndex(of: ")") {
                let afterParen = line[parenEnd...].trimmingCharacters(in: .whitespaces)
                let name = afterParen.dropFirst(5).components(separatedBy: "(").first ?? ""
                return Symbol(name: String(name), type: .method, lineNumber: lineNumber, column: column, range: fullRange)
            }
        }

        // 结构体/接口定义
        if line.hasPrefix("type ") && (line.contains("struct") || line.contains("interface")) {
            let name = String(line.dropFirst(5)).components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: name, type: line.contains("struct") ? .structType : .protocol, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - Rust 解析

    private func parseRustLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 函数定义
        if line.hasPrefix("fn ") || line.contains("pub fn ") || line.contains("pub(crate) fn ") {
            let name = line.components(separatedBy: "fn ").last?.components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 结构体/枚举/特征定义
        if line.hasPrefix("struct ") || line.hasPrefix("enum ") || line.hasPrefix("trait ") || line.contains("pub struct ") || line.contains("pub enum ") || line.contains("pub trait ") {
            let typeStr = line.contains("struct") ? "struct" : line.contains("enum") ? "enum" : "trait"
            let name = line.components(separatedBy: typeStr + " ").last?.components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: name, type: typeStr == "struct" ? .structType : typeStr == "enum" ? .enumType : .protocol, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // impl块
        if line.hasPrefix("impl ") {
            let name = String(line.dropFirst(5)).components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: "impl \(name)", type: .extensionType, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - Ruby 解析

    private func parseRubyLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 类/模块定义
        if line.hasPrefix("class ") || line.hasPrefix("module ") {
            let name = line.components(separatedBy: " ").last ?? ""
            return Symbol(name: name, type: line.hasPrefix("class") ? .class : .protocol, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 方法定义
        if line.hasPrefix("def ") {
            let name = String(line.dropFirst(4)).components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .method, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - PHP 解析

    private func parsePHPLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 类/接口/特征定义
        if line.contains("class ") || line.contains("interface ") || line.contains("trait ") {
            let typeStr = line.contains("class") ? "class" : line.contains("interface") ? "interface" : "trait"
            let name = line.components(separatedBy: typeStr + " ").last?.components(separatedBy: .whitespaces).first ?? ""
            return Symbol(name: name, type: typeStr == "class" ? .class : typeStr == "interface" ? .protocol : .extensionType, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 函数/方法定义
        if line.contains("function ") {
            let name = line.components(separatedBy: "function ").last?.components(separatedBy: "(").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - Shell 解析

    private func parseShellLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 函数定义
        if line.hasPrefix("function ") {
            let name = String(line.dropFirst(9)).components(separatedBy: "()").first ?? ""
            return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        // 简写函数定义
        if line.hasSuffix("() {") || line.hasSuffix("()") {
            let name = line.components(separatedBy: "()").first ?? ""
            if !name.contains(" ") && !name.isEmpty {
                return Symbol(name: name, type: .function, lineNumber: lineNumber, column: column, range: fullRange)
            }
        }

        return nil
    }

    // MARK: - 通用函数解析

    private func parseGenericFunctionLine(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 通用函数定义模式
        if let range = line.range(of: #"^(?:public|private|protected|static|final|abstract|async|export|default)?\s*(?:function|func|def|fn|method)\s+(\w+)"#, options: .regularExpression) {
            let name = String(line[range]).split(separator: " ").last ?? ""
            return Symbol(name: String(name), type: .function, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }

    // MARK: - MARK 注释解析

    private func parseMarkComment(_ line: String, lineNumber: Int, column: Int, content: String) -> Symbol? {
        let fullRange = NSRange(location: 0, length: (line as NSString).length)

        // 提取MARK:后面的内容
        if let range = line.range(of: "MARK:") {
            let markContent = line[range.upperBound...].trimmingCharacters(in: .whitespaces)
            let name = markContent.isEmpty ? "MARK" : markContent
            return Symbol(name: name, type: .mark, lineNumber: lineNumber, column: column, range: fullRange)
        }

        return nil
    }
}

// ==============================================================================
// SymbolPickerView 符号选择器视图
// 功能：显示当前文件的所有符号，支持搜索和快速跳转
// ==============================================================================

struct SymbolPickerView: View {
    @ObservedObject var symbolNavigator: SymbolNavigator
    var onSelect: (SymbolNavigator.Symbol) -> Void
    @State private var searchText: String = ""
    @Environment(\.dismiss) private var dismiss  // 用于关闭当前sheet页面

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("搜索符号...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))

                // 符号列表
                List {
                    ForEach(filteredSymbols) { symbol in
                        Button(action: {
                            onSelect(symbol)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: symbol.type.systemImage)
                                    .foregroundColor(symbol.type.color)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(symbol.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    HStack(spacing: 8) {
                                        Text(symbol.type.rawValue)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Text("第 \(symbol.lineNumber) 行")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("符号导航")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()  // 关闭当前sheet页面
                    }
                }
            }
        }
    }

    private var filteredSymbols: [SymbolNavigator.Symbol] {
        if searchText.isEmpty {
            return symbolNavigator.symbols
        }
        return symbolNavigator.searchSymbols(searchText)
    }
}
