// VPN LiveActivity 管理器
// 监控 VPN 连接状态：隧道 up 时启动 LiveActivity，down 时结束
// 替代被越狱插件损坏的状态栏 WiFi 图标，在锁屏和灵动岛显示绿色 VPN 状态
// 注意：LiveActivity 需要 iOS 16.1+，iOS 16.0 上自动降级不启用
import ActivityKit
import Foundation

@available(iOS 16.1, *)
final class VPNLiveActivityManager {
    static let shared = VPNLiveActivityManager()

    private var 当前Activity: Activity<VPNLiveActivityAttributes>?
    private let 队列 = DispatchQueue(label: "com.github.client.vpn.liveactivity")
    private var 已启动 = false

    private init() {}

    // MARK: - 公开接口

    /// VPN 连接成功时调用，启动 LiveActivity
    /// - Parameter 节点名称: 当前连接的节点名称
    func 连接成功(节点名称: String) {
        队列.async { [weak self] in
            guard let self = self else { return }
            guard !self.已启动 else { return }
            self.已启动 = true

            // 结束可能存在的旧 Activity
            self.结束同步()

            // 检查 LiveActivity 权限
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                return
            }

            let 属性 = VPNLiveActivityAttributes(名称: "GitHub 中文 VPN")
            let 状态 = VPNLiveActivityAttributes.ContentState(
                连接状态: "已连接",
                节点名称: 节点名称,
                连接开始时间: Date()
            )

            do {
                let activity = try Activity.request(
                    attributes: 属性,
                    content: .init(state: 状态, staleDate: nil),
                    pushType: nil
                )
                self.当前Activity = activity
            } catch {
                // 静默失败：LiveActivity 不可用时不影响 VPN 功能
                self.已启动 = false
            }
        }
    }

    /// VPN 断开时调用，结束 LiveActivity
    func 断开连接() {
        队列.async { [weak self] in
            self?.结束同步()
            self?.已启动 = false
        }
    }

    /// 更新当前节点名称（切换节点时调用）
    func 更新节点(节点名称: String) {
        队列.async { [weak self] in
            guard let self = self, let activity = self.当前Activity else { return }

            let 状态 = VPNLiveActivityAttributes.ContentState(
                连接状态: "已连接",
                节点名称: 节点名称,
                连接开始时间: activity.content.state.连接开始时间
            )

            Task {
                await activity.update(.init(state: 状态, staleDate: nil))
            }
        }
    }

    // MARK: - 内部方法

    /// 同步结束 Activity（必须在 队列 上调用）
    private func 结束同步() {
        guard let activity = 当前Activity else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        当前Activity = nil
    }
}
