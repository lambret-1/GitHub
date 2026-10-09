// VPN 连接状态 LiveActivity 属性定义
// 主 App 与 Widget 扩展共享此结构体，必须保持两边完全一致
import ActivityKit
import Foundation

struct VPNLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// 连接状态描述（如"已连接"）
        var 连接状态: String
        /// 当前节点名称
        var 节点名称: String
        /// 连接开始时间（用于显示连接时长计时器）
        var 连接开始时间: Date
    }

    /// 静态属性：VPN 服务名称
    var 名称: String
}
