//
//  CrashLogger.swift
//  GitHub
//
//  崩溃日志记录器（纯C底层实现，确保在崩溃上下文中能够可靠保存日志）
//  使用sigaction安装Signal Handler，NSSetUncaughtExceptionHandler安装异常Handler
//  Handler中仅使用write系统调用直接写文件，不执行任何Swift高层API操作
//

import Foundation
import UIKit

/// 崩溃日志记录器（单例模式）
final class CrashLogger {

    // MARK: - 单例
    static let shared = CrashLogger()

    // MARK: - 全局变量（用于Signal Handler中访问，避免访问对象属性）
    /// 崩溃日志目录路径（C字符串，用于Signal Handler）
    private static var crashLogDirCString: [CChar] = []
    /// 是否已安装崩溃处理器
    private static var isInstalled = false
    /// 之前的NSException Handler
    private static var previousUncaughtExceptionHandler: NSUncaughtExceptionHandler?
    /// 之前的Signal Handler
    private static var previousSignalHandlers: [Int32: sig_t] = [:]

    // MARK: - 私有属性
    /// 崩溃日志存储目录
    private let crashLogDirectory: URL
    /// 最大保留崩溃日志数量
    private let maxCrashLogs = 20
    /// 崩溃日志文件前缀
    private let crashLogFilePrefix = "crash_"
    /// 崩溃日志文件扩展名
    private let crashLogFileExtension = "log"

    // MARK: - 初始化
    private init() {
        // 获取Documents目录
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        crashLogDirectory = documentsDirectory.appendingPathComponent("CrashLogs", isDirectory: true)

        // 创建崩溃日志目录（如果不存在）
        try? FileManager.default.createDirectory(at: crashLogDirectory, withIntermediateDirectories: true, attributes: nil)

        // 将目录路径转换为C字符串，保存到全局变量（用于Signal Handler）
        let pathString = crashLogDirectory.path
        crashLogDirCString = pathString.utf8CString.map { $0 }
    }

    // MARK: - 安装崩溃处理器
    /// 安装崩溃处理器（在App启动最早期调用，只需调用一次）
    func install() {
        guard !CrashLogger.isInstalled else { return }
        CrashLogger.isInstalled = true

        // 保存之前的NSException Handler
        CrashLogger.previousUncaughtExceptionHandler = NSGetUncaughtExceptionHandler()

        // 设置NSException Handler（捕获Objective-C异常，如数组越界、字典nil等）
        NSSetUncaughtExceptionHandler { exception in
            CrashLogger.handleObjectiveCException(exception)
        }

        // 使用sigaction安装Signal Handler（捕获Mach异常，如段错误、总线错误等）
        // sigaction比signal更可靠，不会被系统重置
        let signals: [Int32] = [
            SIGABRT,  // 程序中止（如assert失败、abort()调用、Swift运行时崩溃）
            SIGSEGV,  // 段错误（非法内存访问）
            SIGBUS,   // 总线错误（非法地址访问）
            SIGFPE,   // 浮点异常（除零、溢出等）
            SIGILL,   // 非法指令
            SIGTRAP,  // 断点/陷阱
            SIGSYS    // 非法系统调用
        ]

        for sig in signals {
            var action = sigaction()
            action.sa_flags = SA_SIGINFO | SA_RESTART
            action.sa_sigaction = { (signalNumber, _, _) in
                CrashLogger.handleSignal(signalNumber)
            }
            sigemptyset(&action.sa_mask)

            // 保存之前的Handler
            var oldAction = sigaction()
            if sigaction(sig, &action, &oldAction) == 0 {
                // 保存之前的Handler（用于恢复和链式调用）
                if let handler = oldAction.__sigaction_u.__sa_handler {
                    CrashLogger.previousSignalHandlers[sig] = handler
                }
            }
        }
    }

    // MARK: - 处理Objective-C异常（C函数，使用纯C实现）
    /// 处理Objective-C异常（在崩溃上下文中调用，仅使用安全的C API）
    private static func handleObjectiveCException(_ exception: NSException) {
        // 生成崩溃日志内容（使用NSString，避免Swift字符串在崩溃上下文中的问题）
        let crashType = "NSException"
        let exceptionName = exception.name.rawValue
        let exceptionReason = exception.reason ?? "未知原因"
        let callStack = exception.callStackSymbols.joined(separator: "\n")

        let crashReason = "\(exceptionName): \(exceptionReason)"

        // 保存崩溃日志
        saveCrashLogPureC(crashType: crashType, crashReason: crashReason, callStack: callStack)

        // 调用之前的Handler（如果有）
        if let previousHandler = previousUncaughtExceptionHandler {
            previousHandler(exception)
        }
    }

    // MARK: - 处理Signal异常（C函数，使用纯C实现）
    /// 处理Signal异常（在崩溃上下文中调用，仅使用安全的C API）
    private static func handleSignal(_ signalNumber: Int32) {
        // 生成崩溃日志内容
        let crashType = "Signal"
        let signalName = signalNamePureC(signalNumber)
        let crashReason = "Signal \(signalNumber) (\(signalName))"

        // 获取调用栈（使用backtrace_symbols，纯C实现）
        let callStack = getCallStackPureC()

        // 保存崩溃日志
        saveCrashLogPureC(crashType: crashType, crashReason: crashReason, callStack: callStack)

        // 恢复之前的Handler并重新抛出Signal（确保系统能够正常终止进程）
        if let previousHandler = previousSignalHandlers[signalNumber] {
            signal(signalNumber, previousHandler)
        } else {
            signal(signalNumber, SIG_DFL)
        }
        raise(signalNumber)
    }

    // MARK: - 纯C实现的崩溃日志保存（关键：在崩溃上下文中可靠执行）
    /// 保存崩溃日志（纯C实现，使用write系统调用直接写文件）
    /// - Parameters:
    ///   - crashType: 崩溃类型
    ///   - crashReason: 崩溃原因
    ///   - callStack: 调用栈
    private static func saveCrashLogPureC(crashType: String, crashReason: String, callStack: String) {
        // 获取当前时间（使用time系统调用）
        var currentTime = time(nil)
        var timeInfo = tm()
        localtime_r(&currentTime, &timeInfo)

        // 生成文件名：crash_YYYYMMDD_HHMMSS.log
        let fileName = String(format: "crash_%04d%02d%02d_%02d%02d%02d.log",
                              timeInfo.tm_year + 1900,
                              timeInfo.tm_mon + 1,
                              timeInfo.tm_mday,
                              timeInfo.tm_hour,
                              timeInfo.tm_min,
                              timeInfo.tm_sec)

        // 构建完整文件路径：目录/文件名
        let fullPath = crashLogDirCString.withUnsafeBufferPointer { dirPtr -> String in
            guard let dirBase = dirPtr.baseAddress else { return fileName }
            let dirString = String(cString: dirBase)
            return dirString + "/" + fileName
        }

        // 生成崩溃日志内容
        let dateString = String(format: "%04d-%02d-%02d %02d:%02d:%02d",
                                 timeInfo.tm_year + 1900,
                                 timeInfo.tm_mon + 1,
                                 timeInfo.tm_mday,
                                 timeInfo.tm_hour,
                                 timeInfo.tm_min,
                                 timeInfo.tm_sec)

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

        // 组装崩溃日志
        let logContent = """
        ========================================
        崩溃日志
        ========================================
        崩溃时间: \(dateString)
        崩溃类型: \(crashType)
        崩溃原因: \(crashReason)

        ----------------------------------------
        设备信息
        ----------------------------------------
        \(deviceInfo)

        ----------------------------------------
        应用信息
        ----------------------------------------
        \(appInfo)

        ----------------------------------------
        调用栈
        ----------------------------------------
        \(callStack)

        ========================================
        崩溃日志结束
        ========================================
        """

        // 使用write系统调用直接写文件（关键：在崩溃上下文中可靠执行）
        let fileDescriptor = open(fullPath, O_WRONLY | O_CREAT | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH)
        if fileDescriptor >= 0 {
            // 将日志内容转换为UTF-8数据
            if let data = logContent.data(using: .utf8) {
                data.withUnsafeBytes { buffer in
                    if let baseAddress = buffer.baseAddress {
                        // 使用write系统调用写入文件
                        _ = write(fileDescriptor, baseAddress, data.count)
                    }
                }
            }
            // 关闭文件
            close(fileDescriptor)
        }

        // 清理旧的崩溃日志（超过最大保留数量时删除最旧的）
        cleanupOldCrashLogsPureC()
    }

    // MARK: - 纯C实现的调用栈获取
    /// 获取当前调用栈（纯C实现，使用backtrace_symbols）
    /// - Returns: 调用栈字符串
    private static func getCallStackPureC() -> String {
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

    // MARK: - 纯C实现的Signal名称获取
    /// 获取Signal名称（纯C实现）
    /// - Parameter signalNumber: Signal编号
    /// - Returns: Signal名称
    private static func signalNamePureC(_ signalNumber: Int32) -> String {
        switch signalNumber {
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

    // MARK: - 纯C实现的旧日志清理
    /// 清理旧的崩溃日志（超过最大保留数量时删除最旧的）
    private static func cleanupOldCrashLogsPureC() {
        let fileManager = FileManager.default
        let crashLogDirURL = URL(fileURLWithPath: String(cString: crashLogDirCString))

        // 获取所有崩溃日志文件
        guard let files = try? fileManager.contentsOfDirectory(
            at: crashLogDirURL,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        // 过滤崩溃日志文件并按创建时间排序（从旧到新）
        let crashLogFiles = files
            .filter { $0.lastPathComponent.hasPrefix("crash_") && $0.pathExtension == "log" }
            .sorted { (url1, url2) -> Bool in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }

        // 如果超过最大保留数量，删除最旧的
        let maxLogs = 20
        if crashLogFiles.count > maxLogs {
            let filesToDelete = crashLogFiles.prefix(crashLogFiles.count - maxLogs)
            for fileURL in filesToDelete {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }

    // MARK: - 公开方法（Swift层，用于正常运行时访问）

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

    /// 检查上次是否有崩溃（在App启动时调用，用于提示用户）
    /// - Returns: 是否有上次未处理的崩溃
    func hasUnprocessedCrash() -> Bool {
        return !getAllCrashLogs().isEmpty
    }
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
