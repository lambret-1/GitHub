import Foundation

// MARK: - 统一日期工具类
/// 全局统一的日期格式化和相对时间计算工具
/// 所有时间显示统一使用本工具类，确保格式一致
enum 日期工具 {
    // MARK: - 相对时间计算（统一标准）
    /// 将日期转换为相对时间字符串
    /// 格式：x分钟前、x小时前、x天前、x年前
    /// - Parameter date: 日期对象
    /// - Returns: 相对时间字符串
    static func 相对时间(_ date: Date) -> String {
        let now = Date()
        let interval = now.timeIntervalSince(date)

        // 小于1分钟显示1分钟前
        if interval < 60 {
            return "1 分钟前"
        }
        // 小于1小时显示x分钟前
        else if interval < 3600 {
            return "\(Int(interval / 60)) 分钟前"
        }
        // 小于1天显示x小时前
        else if interval < 86400 {
            return "\(Int(interval / 3600)) 小时前"
        }
        // 小于1年显示x天前
        else if interval < 31536000 {
            return "\(Int(interval / 86400)) 天前"
        }
        // 大于等于1年显示x年前
        else {
            return "\(Int(interval / 31536000)) 年前"
        }
    }

    // MARK: - ISO 8601 字符串解析
    /// 解析 ISO 8601 格式的日期字符串
    /// 支持带小数秒和不带小数秒的格式
    /// - Parameter dateString: ISO 8601 日期字符串
    /// - Returns: 解析后的日期，解析失败返回 nil
    static func 解析ISO日期(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        // 先尝试带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // 再尝试不带小数秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    // MARK: - ISO 字符串转相对时间
    /// 将 ISO 8601 日期字符串直接转换为相对时间
    /// - Parameter dateString: ISO 8601 日期字符串
    /// - Returns: 相对时间字符串，解析失败返回原始字符串
    static func 相对时间(fromISO dateString: String) -> String {
        guard let date = 解析ISO日期(dateString) else {
            return dateString
        }
        return 相对时间(date)
    }

    // MARK: - 格式化日期（备用）
    /// 格式化日期为 yyyy-MM-dd HH:mm 格式
    /// 使用系统默认时区，不强制设置时区
    /// - Parameter date: 日期对象
    /// - Returns: 格式化后的日期字符串
    static func 格式化日期(_ date: Date) -> String {
        let displayFormatter = DateFormatter()
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        // 不设置时区，使用系统默认时区
        return displayFormatter.string(from: date)
    }
}

// MARK: - String 扩展（便捷方法）
extension String {
    /// 将 ISO 8601 日期字符串转换为相对时间
    /// 用法：dateString.相对时间
    var 相对时间: String {
        return 日期工具.相对时间(fromISO: self)
    }
}

// MARK: - Date 扩展（便捷方法）
extension Date {
    /// 将日期转换为相对时间
    /// 用法：date.相对时间
    var 相对时间: String {
        return 日期工具.相对时间(self)
    }
}
