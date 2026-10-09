// VPN 状态 Widget 扩展入口
// 承载 LiveActivity 视图，在锁屏和灵动岛显示 VPN 连接状态
// 替代被越狱插件损坏的状态栏 WiFi 图标
import ActivityKit
import SwiftUI
import WidgetKit

@main
struct VPNWidgetBundle: WidgetBundle {
    var body: some Widget {
        VPNLiveActivityWidget()
    }
}

// VPN LiveActivity Widget 定义
struct VPNLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: VPNLiveActivityAttributes.self) { context in
            // 锁屏视图
            VPNLiveActivity锁屏视图(状态: context.state)
        } dynamicIsland: { context in
            // 灵动岛视图
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "wifi.circle.fill")
                            .foregroundColor(.green)
                        Text(context.state.节点名称)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.连接开始时间...Date.distantFuture, countsDown: false)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("VPN 已连接")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("隧道运行正常")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "wifi")
                    .foregroundColor(.green)
            } compactTrailing: {
                Text("VPN")
                    .font(.caption2)
                    .foregroundColor(.green)
            } minimal: {
                Image(systemName: "wifi")
                    .foregroundColor(.green)
            }
        }
    }
}

// 锁屏视图
struct VPNLiveActivity锁屏视图: View {
    let 状态: VPNLiveActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            // 绿色 WiFi 图标
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "wifi.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("VPN 已连接")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Text(状态.节点名称)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 连接时长计时器
            VStack(alignment: .trailing, spacing: 2) {
                Text(timerInterval: 状态.连接开始时间...Date.distantFuture, countsDown: false)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Text("已连接")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 4)
    }
}
