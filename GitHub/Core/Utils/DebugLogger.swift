import Foundation

// ==============================================================================
// DebugLogger 统一日志记录器
// 功能：记录调试日志、崩溃日志到文件，支持按标签过滤，用户可在APP内查看
// 位置：Core/Utils，全局可用
// 设计原则：单例模式，线程安全，日志写入文件，支持按标签分类
// ==============================================================================

class DebugLogger {
    // MARK: - 共享实例

    static let shared = DebugLogger()

    private init() {
        // 确保日志目录存在
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - 日志级别

    enum LogLevel: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
        case crash = "CRASH"
    }

    // MARK: - 日志目录和文件

    /// 日志文件保存目录（Documents/DebugLogs）
    private var logDirectory: URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("DebugLogs", isDirectory: true)
    }

    /// 当前日志文件路径（按日期命名，每天一个文件）
    private var currentLogFile: URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        return logDirectory.appendingPathComponent("debug_\(dateString).log")
    }

    // MARK: - 串行队列（保证线程安全）

    private let logQueue = DispatchQueue(label: "com.github.client.debuglogger", qos: .utility)

    // MARK: - 公共方法

    /// 记录一条日志
    /// - Parameters:
    ///   - tag: 日志标签（如"分享调试"、"崩溃日志"）
    ///   - message: 日志内容
    ///   - level: 日志级别
    func log(tag: String, message: String, level: LogLevel = .debug) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // 格式化时间
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            let timeString = timeFormatter.string(from: Date())

            // 组装日志行
            let logLine = "[\(timeString)] [\(level.rawValue)] [\(tag)] \(message)\n"

            // 写入文件
            do {
                if FileManager.default.fileExists(atPath: self.currentLogFile.path) {
                    // 文件存在，追加写入
                    let fileHandle = try FileHandle(forWritingTo: self.currentLogFile)
                    fileHandle.seekToEndOfFile()
                    if let data = logLine.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                } else {
                    // 文件不存在，创建并写入
                    try logLine.data(using: .utf8)?.write(to: self.currentLogFile, options: .atomic)
                }
            } catch {
                // 写入失败时打印到控制台（兜底）
                print("【DebugLogger】写入日志失败: \(error.localizedDescription)")
            }

            // 同时打印到控制台（方便Xcode调试）
            print("[\(tag)] \(message)")
        }
    }

    /// 读取今天的日志内容
    func readTodayLogs() -> String {
        do {
            let content = try String(contentsOf: currentLogFile, encoding: .utf8)
            return content
        } catch {
            return "暂无日志记录（\(error.localizedDescription)）"
        }
    }

    /// 读取指定标签的日志（过滤）
    func readLogs(withTag tag: String) -> String {
        let allLogs = readTodayLogs()
        let lines = allLogs.components(separatedBy: .newlines)
        let filteredLines = lines.filter { $0.contains("[\(tag)]") }
        return filteredLines.joined(separator: "\n")
    }

    /// 获取所有可用的日志标签
    func getAllTags() -> [String] {
        let allLogs = readTodayLogs()
        let lines = allLogs.components(separatedBy: .newlines)
        var tags = Set<String>()
        for line in lines {
            // 提取 [标签] 格式的内容
            if let range = line.range(of: "\\[[^\\]]+\\]$", options: .regularExpression) {
                let tag = String(line[range]).trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                tags.insert(tag)
            }
        }
        return Array(tags).sorted()
    }

    /// 清理今天的日志
    func clearTodayLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try FileManager.default.removeItem(at: self.currentLogFile)
            } catch {
                print("【DebugLogger】清理日志失败: \(error.localizedDescription)")
            }
        }
    }

    /// 清理所有历史日志（保留今天）
    func clearAllHistoryLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let files = try FileManager.default.contentsOfDirectory(at: self.logDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
                for file in files {
                    if file.lastPathComponent != self.currentLogFile.lastPathComponent {
                        try FileManager.default.removeItem(at: file)
                    }
                }
            } catch {
                print("【DebugLogger】清理历史日志失败: \(error.localizedDescription)")
            }
        }
    }

    /// 获取日志文件大小
    func getLogFileSize() -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: currentLogFile.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}

// MARK: - 便捷方法（全局可用）

extension DebugLogger {
    /// 记录分享调试日志
    static func share(_ message: String) {
        shared.log(tag: "分享调试", message: message, level: .debug)
    }

    /// 记录代码格式化日志
    static func format(_ message: String) {
        shared.log(tag: "代码格式化", message: message, level: .debug)
    }

    /// 记录崩溃日志
    static func crash(_ message: String) {
        shared.log(tag: "崩溃日志", message: message, level: .crash)
    }

    /// 记录错误日志
    static func error(tag: String, _ message: String) {
        shared.log(tag: tag, message: message, level: .error)
    }

    /// 记录普通日志
    static func info(tag: String, _ message: String) {
        shared.log(tag: tag, message: message, level: .info)
    }

    /// 记录网络请求日志
    static func network(_ message: String) {
        shared.log(tag: "网络请求", message: message, level: .debug)
    }

    /// 记录网络错误日志
    static func networkError(_ message: String) {
        shared.log(tag: "网络请求", message: message, level: .error)
    }

    /// 记录文件操作日志
    static func file(_ message: String) {
        shared.log(tag: "文件操作", message: message, level: .debug)
    }

    /// 记录文件错误日志
    static func fileError(_ message: String) {
        shared.log(tag: "文件操作", message: message, level: .error)
    }

    /// 记录登录/认证日志
    static func auth(_ message: String) {
        shared.log(tag: "登录认证", message: message, level: .debug)
    }

    /// 记录登录错误日志
    static func authError(_ message: String) {
        shared.log(tag: "登录认证", message: message, level: .error)
    }

    /// 记录页面跳转日志
    static func navigation(_ message: String) {
        shared.log(tag: "页面跳转", message: message, level: .info)
    }

    /// 记录代码编辑器操作日志
    static func editor(_ message: String) {
        shared.log(tag: "代码编辑器", message: message, level: .debug)
    }

    /// 记录Actions操作日志
    static func actions(_ message: String) {
        shared.log(tag: "Actions", message: message, level: .debug)
    }

    /// 记录搜索操作日志
    static func search(_ message: String) {
        shared.log(tag: "搜索", message: message, level: .debug)
    }

    /// 记录上传操作日志
    static func upload(_ message: String) {
        shared.log(tag: "文件上传", message: message, level: .debug)
    }

    /// 记录下载操作日志
    static func download(_ message: String) {
        shared.log(tag: "文件下载", message: message, level: .debug)
    }

    /// 记录更新检查日志
    static func update(_ message: String) {
        shared.log(tag: "应用更新", message: message, level: .debug)
    }

    /// 记录VPN调试日志
    static func vpn(_ message: String) {
        shared.log(tag: "VPN调试", message: message, level: .debug)
    }

    /// 记录VPN错误日志
    static func vpnError(_ message: String) {
        shared.log(tag: "VPN调试", message: message, level: .error)
    }

    /// 记录VPN信息日志
    static func vpnInfo(_ message: String) {
        shared.log(tag: "VPN调试", message: message, level: .info)
    }
}
