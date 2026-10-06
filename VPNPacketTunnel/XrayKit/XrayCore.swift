//
//  XrayCore.swift
//  XrayKit
//
//  用途：Xray 核心 C API 的 Swift 封装
//  说明：将 libxray.h 中的 C 函数封装为 Swift 方法，供扩展调用
//  架构：扩展 → XrayKit（动态框架）→ Xray Go 核心（静态库）
//

import Foundation

/// Xray 核心封装类
/// 负责启动/停止 Xray 核心，查询版本和统计信息
public final class XrayCore {

    /// 单例
    public static let shared = XrayCore()

    /// Xray 核心是否已启动
    public private(set) var isRunning = false

    /// 私有初始化方法，防止外部创建实例
    private init() {
        // 在 Go runtime 首次被 cgo 唤起之前（即第一次调用 StartXray 之前）
        // 注入内存治理环境变量。cgo 静态库的 Go runtime 是 lazy 初始化的，
        // 所以这里 setenv 一定能被 Go runtime 读到。
        //
        // GOMEMLIMIT: 软内存上限 35MiB，触发后 Go runtime 会更积极 GC 并归还堆。
        //   这是 iOS Network Extension jetsam 红线（~40-50MB）下的关键防护，
        //   避免 speedtest 大流量时 resident_size 持续上涨被系统杀死。
        // GOGC: 从默认 100 调到 50，堆增长到上一次存活堆的 50% 就触发 GC，
        //   比默认更积极回收，牺牲一点 CPU 换内存稳定。
        setenv("GOMEMLIMIT", "35MiB", 1)
        setenv("GOGC", "50", 1)
    }

    /// 启动 Xray 核心
    /// - Parameters:
    ///   - configJSON: Xray 配置 JSON 字符串
    ///   - tunFd: TUN 设备文件描述符
    /// - Returns: 0 表示成功，非 0 表示失败（错误码）
    public func start(configJSON: String, tunFd: Int32) -> Int32 {
        let result = configJSON.withCString { configPtr in
            StartXray(UnsafeMutablePointer(mutating: configPtr), tunFd)
        }
        if result == 0 {
            isRunning = true
        }
        return result
    }

    /// 停止 Xray 核心
    /// - Returns: 0 表示成功，非 0 表示失败
    public func stop() -> Int32 {
        let result = StopXray()
        if result == 0 {
            isRunning = false
        }
        return result
    }

    /// 获取 Xray 版本号
    /// - Returns: 版本号字符串
    public func getVersion() -> String {
        guard let versionPtr = GetVersion() else {
            return "unknown"
        }
        let version = String(cString: versionPtr)
        FreeString(versionPtr)
        return version
    }

    /// 查询出站流量统计
    /// - Parameter tag: 出站标签（如 "proxy"）
    /// - Returns: 统计信息 JSON 字符串
    public func queryStats(tag: String) -> String {
        guard let statsPtr = QueryStats(UnsafeMutablePointer(mutating: (tag as NSString).utf8String)) else {
            return "{}"
        }
        let stats = String(cString: statsPtr)
        FreeString(statsPtr)
        return stats
    }
}
