//
//  CrashLogger.swift
//  GitHub
//
//  崩溃日志记录器：使用Signal Handler和NSException Handler双机制捕获崩溃
//  完整记录崩溃时间、类型、原因、调用栈、设备信息、应用版本
//  持久化到Documents/CrashLogs目录，保留最近20条
//

import Foundation
import UIKit

/// 崩溃日志记录器（单例模式）
final class CrashLogger {

    // MARK: - 单例
    static let shared = CrashLogger()

    // MARK: - 私有属性
    /// 崩溃日志存储目录
    private let crashLogDirectory: URL
    /// 最大保留崩溃日志数量
    private let maxCrashLogs = 20
    /// 崩溃日志文件前缀
    private let crashLogFilePrefix = "crash_"
    /// 崩溃日志文件扩展名
    private let crashLogFileExtension = "log"
    /// 之前的Signal Handler（用于恢复）
    private var previousSignalHandlers: [Int32: sig_t] = [:]
    /// 之前的NSException Handler
    private var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?
    /// 是否已安装崩溃处理器
    private var isInstalled = false
    /// 崩溃日志队列（串行队列，保证线程安全）
    private let logQueue = DispatchQueue(label: "com.github.crashlogger.queue", qos: .utility)

    // MARK: - 初始化
    private init() {
        // 获取Documents目录
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        crashLogDirectory = documentsDirectory.appendingPathComponent("CrashLogs", isDirectory: true)

        // 创建崩溃日志目录（如果不存在）
        try? FileManager.default.createDirectory(at: crashLogDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    // MARK: - 安装崩溃处理器
    /// 安装崩溃处理器（在App启动时调用，只需调用一次）
    func install() {
        guard !isInstalled else { return }
        isInstalled = true

        // 保存之前的NSException Handler
        previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()

        // 设置NSException Handler（捕获Objective-C异常，如数组越界、字典nil等）
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.shared.handleException(exception)
        }

        // 保存之前的Signal Handler并设置新的Signal Handler（捕获Mach异常，如段错误、总线错误等）
        let signals: [Int32] = [
            SIGABRT,  // 程序中止（如assert失败、abort()调用）
            SIGSEGV,  // 段错误（非法内存访问）
            SIGBUS,   // 总线错误（非法地址访问）
            SIGFPE,   // 浮点异常（除零、溢出等）
            SIGILL,   // 非法指令
            SIGTRAP,  // 断点/陷阱
            SIGSYS    // 非法系统调用
        ]

        for sig in signals {
            let previousHandler = signal(sig) { signalValue in
                CrashLogger.shared.handleSignal(signalValue)
            }
            previousSignalHandlers[sig] = previousHandler
        }
    }

    // MARK: - 处理NSException
    /// 处理Objective-C异常
    private func handleException(_ exception: NSException) {
        let crashType = "NSException"
        let crashReason = exception.reason ?? "未知原因"
        let callStack = exception.callStackSymbols.joined(separator: "\n")
        let exceptionName = exception.name.rawValue

        let crashInfo = CrashInfo(
            crashType: crashType,
            crashReason: "\(exceptionName): \(crashReason)",
            callStack: callStack,
            additionalInfo: [
                "exception_name": exceptionName,
                "exception_reason": crashReason,
                "user_info": String(describing: exception.userInfo ?? [:])
            ]
        )

        saveCrashLog(crashInfo)

        // 调用之前的Handler（如果有）
        if let previousHandler = previousUncaughtExceptionHandler {
            previousHandler(exception)
        }
    }

    // MARK: - 处理Signal
    /// 处理Signal异常
    private func handleSignal(_ sigValue: Int32) {
        let crashType = "Signal"
        let signalName = signalName(for: sigValue)
        let crashReason = "Signal \(sigValue) (\(signalName))"

        // 获取调用栈（使用backtrace_symbols）
        let callStack = getCallStack()

        let crashInfo = CrashInfo(
            crashType: crashType,
            crashReason: crashReason,
            callStack: callStack,
            additionalInfo: [
                "signal_number": "\(sigValue)",
                "signal_name": signalName
            ]
        )

        saveCrashLog(crashInfo)

        // 恢复之前的Handler并重新抛出Signal（确保系统能够正常终止进程）
        if let previousHandler = previousSignalHandlers[sigValue] {
            signal(sigValue, previousHandler)
        } else {
            signal(sigValue, SIG_DFL)
        }
        raise(sigValue)
    }

    // MARK: - 获取调用栈
    /// 获取当前调用栈
    private func getCallStack() -> String {
        // 使用backtrace_symbols获取调用栈
        let maxFrames = 128
        var frames = [UnsafeMutableRawPointer?](repeating: nil, count: maxFrames)
        let frameCount = backtrace(&frames, Int32(maxFrames))

        guard let symbols = backtrace_symbols(frames, Int32(frameCount)) else {
            return "无法获取调用栈"
        }

        var callStack: [String] = []
        for i in 0..<Int(frameCount) {
            if let symbol = symbols[i] {
                callStack.append(String(cString: symbol))
            }
        }

        free(symbols)
        return callStack.joined(separator: "\n")
    }

    // MARK: - Signal名称映射
    /// 获取Signal名称
    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS: return "SIGBUS"
        case SIGFPE: return "SIGFPE"
        case SIGILL: return "SIGILL"
        case SIGTRAP: return "SIGTRAP"
        case SIGSYS: return "SIGSYS"
        default: return "UNKNOWN"
        }
    }

    // MARK: - 保存崩溃日志
    /// 保存崩溃日志到文件
    private func saveCrashLog(_ crashInfo: CrashInfo) {
        logQueue.async { [weak self] in
            guard let self = self else { return }

            // 生成崩溃日志内容
            let logContent = self.formatCrashLog(crashInfo)

            // 生成文件名（包含时间戳）
            let timestamp = Int(Date().timeIntervalSince1970)
            let fileName = "\(self.crashLogFilePrefix)\(timestamp).\(self.crashLogFileExtension)"
            let fileURL = self.crashLogDirectory.appendingPathComponent(fileName)

            // 写入文件
            do {
                try logContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                // 写入失败，无法处理（因为已经崩溃了）
                print("崩溃日志写入失败: \(error)")
            }

            // 清理旧的崩溃日志（超过最大保留数量时删除最旧的）
            self.cleanupOldCrashLogs()
        }
    }

    // MARK: - 格式化崩溃日志
    /// 格式化崩溃日志内容
    private func formatCrashLog(_ crashInfo: CrashInfo) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        let crashTime = dateFormatter.string(from: Date())

        // 设备信息
        let device = UIDevice.current
        let deviceInfo = """
        设备型号: \(device.model)
        系统版本: \(device.systemName) \(device.systemVersion)
        设备名称: \(device.name)
        屏幕尺寸: \(UIScreen.main.bounds.size.width) x \(UIScreen.main.bounds.size.height)
        屏幕缩放: \(UIScreen.main.scale)
        """

        // 应用信息
        let appInfo = """
        应用名称: \(Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "GitHub")
        应用版本: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "未知")
        构建版本: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "未知")
        Bundle ID: \(Bundle.main.bundleIdentifier ?? "未知")
        """

        // 附加信息
        var additionalInfoString = ""
        if !crashInfo.additionalInfo.isEmpty {
            additionalInfoString = "\n附加信息:\n" + crashInfo.additionalInfo.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
        }

        // 组装崩溃日志
        let logContent = """
        ========================================
        崩溃日志
        ========================================
        崩溃时间: \(crashTime)
        崩溃类型: \(crashInfo.crashType)
        崩溃原因: \(crashInfo.crashReason)

        ----------------------------------------
        设备信息
        ----------------------------------------
        \(deviceInfo)

        ----------------------------------------
        应用信息
        ----------------------------------------
        \(appInfo)
        \(additionalInfoString)

        ----------------------------------------
        调用栈
        ----------------------------------------
        \(crashInfo.callStack)

        ========================================
        崩溃日志结束
        ========================================
        """

        return logContent
    }

    // MARK: - 清理旧崩溃日志
    /// 清理旧的崩溃日志（超过最大保留数量时删除最旧的）
    private func cleanupOldCrashLogs() {
        let fileManager = FileManager.default

        // 获取所有崩溃日志文件
        guard let files = try? fileManager.contentsOfDirectory(
            at: crashLogDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // 过滤崩溃日志文件并按创建时间排序（从旧到新）
        let crashLogFiles = files
            .filter { $0.lastPathComponent.hasPrefix(crashLogFilePrefix) && $0.pathExtension == crashLogFileExtension }
            .sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }

        // 如果超过最大保留数量，删除最旧的
        if crashLogFiles.count > maxCrashLogs {
            let filesToDelete = crashLogFiles.prefix(crashLogFiles.count - maxCrashLogs)
            for fileURL in filesToDelete {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - 公开方法

    /// 获取所有崩溃日志列表（按时间从新到旧排序）
    func getAllCrashLogs() -> [CrashLogFile] {
        let fileManager = FileManager.default

        // 获取所有崩溃日志文件
        guard let files = try? fileManager.contentsOfDirectory(
            at: crashLogDirectory,
            includingPropertiesForKeys: [.creationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        // 过滤崩溃日志文件并按创建时间排序（从新到旧）
        let crashLogFiles = files
            .filter { $0.lastPathComponent.hasPrefix(crashLogFilePrefix) && $0.pathExtension == crashLogFileExtension }
            .compactMap { url -> CrashLogFile? in
                guard let creationDate = try? url.resourceValues(forKeys: [.creationDateKey]).creationDate,
                      let fileSize = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else {
                    return nil
                }
                return CrashLogFile(
                    fileName: url.lastPathComponent,
                    fileURL: url,
                    creationDate: creationDate,
                    fileSize: fileSize
                )
            }
            .sorted { $0.creationDate > $1.creationDate }

        return crashLogFiles
    }

    /// 读取崩溃日志内容
    func readCrashLog(_ crashLogFile: CrashLogFile) -> String? {
        return try? String(contentsOf: crashLogFile.fileURL, encoding: .utf8)
    }

    /// 删除单个崩溃日志
    func deleteCrashLog(_ crashLogFile: CrashLogFile) {
        try? FileManager.default.removeItem(at: crashLogFile.fileURL)
    }

    /// 删除所有崩溃日志
    func deleteAllCrashLogs() {
        let crashLogs = getAllCrashLogs()
        for crashLog in crashLogs {
            deleteCrashLog(crashLog)
        }
    }

    /// 导出崩溃日志（返回文件URL列表，用于分享）
    func exportCrashLogs(_ crashLogs: [CrashLogFile]) -> [URL] {
        return crashLogs.map { $0.fileURL }
    }
}

// MARK: - 崩溃信息结构体
/// 崩溃信息
struct CrashInfo {
    /// 崩溃类型（NSException / Signal）
    let crashType: String
    /// 崩溃原因
    let crashReason: String
    /// 调用栈
    let callStack: String
    /// 附加信息
    let additionalInfo: [String: String]
}

// MARK: - 崩溃日志文件结构体
/// 崩溃日志文件信息
struct CrashLogFile: Identifiable {
    /// 唯一标识（文件名）
    let id = UUID()
    /// 文件名
    let fileName: String
    /// 文件URL
    let fileURL: URL
    /// 创建时间
    let creationDate: Date
    /// 文件大小（字节）
    let fileSize: Int

    /// 格式化的创建时间
    var formattedCreationDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return dateFormatter.string(from: creationDate)
    }

    /// 格式化的文件大小
    var formattedFileSize: String {
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useBytes, .useKB, .useMB]
        byteCountFormatter.countStyle = .file
        return byteCountFormatter.string(fromByteCount: Int64(fileSize))
    }
}
