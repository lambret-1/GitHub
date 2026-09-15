import SwiftUI

// MARK: - 作业步骤时间线视图
// 以时间线方式展示作业的所有步骤，显示每个步骤的状态、开始时间、结束时间、耗时
// 支持点击步骤跳转到对应的日志位置

struct JobTimelineView: View {
    let job: WorkflowJob
    let onStepTap: (Int) -> Void  // 点击步骤回调，参数为步骤索引

    @State private var rotationAngle: Double = 0

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let steps = job.steps, !steps.isEmpty {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        timelineRow(step: step, index: index, isLast: index == steps.count - 1)
                            .onTapGesture {
                                onStepTap(index)
                            }
                    }
                } else {
                    emptyStateView
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 时间线行视图

    private func timelineRow(step: JobStep, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // 时间线左侧：图标和连接线
            VStack(spacing: 0) {
                // 步骤图标
                ZStack {
                    Circle()
                        .fill(backgroundColorForStep(step))
                        .frame(width: 28, height: 28)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算

                    if step.status == "in_progress" {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 12, weight: .bold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.white)
                            .rotationEffect(.degrees(rotationAngle))
                            .onAppear {
                                withAnimation(Animation.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                                    rotationAngle = 360
                                }
                            }
                    } else {
                        Image(systemName: iconForStep(step))
                            .font(.system(size: 12, weight: .bold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 28, height: 28)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算

                // 连接线
                if !isLast {
                    Rectangle()
                        .fill(lineColorForStep(step))
                        .frame(width: 2, height: 40)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                }
            }
            .frame(width: 28)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            // 时间线右侧：步骤信息
            VStack(alignment: .leading, spacing: 4) {
                // 步骤名称和编号
                HStack(spacing: 6) {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .center)

                    Text(step.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)

                    Spacer()

                    // 状态标签
                    Text(step.statusDisplay)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(textColorForStep(step))
                        .padding(.horizontal, 6)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 2)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(backgroundColorForStep(step).opacity(0.15))
                        .cornerRadius(4)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }

                // 时间信息
                HStack(spacing: 12) {
                    if let startedAt = step.startedAt, let startDate = parseDate(startedAt) {
                        HStack(spacing: 3) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.green)
                            Text("开始: \(formatTime(startDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let completedAt = step.completedAt, let endDate = parseDate(completedAt) {
                        HStack(spacing: 3) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 8))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(Color.red)
                            Text("结束: \(formatTime(endDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let duration = step.durationSeconds {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 8))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.blue)
                            Text("耗时: \(formatDuration(duration))")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                }

                // 进度条（仅进行中显示）
                if step.status == "in_progress" {
                    ProgressView(value: 0.5)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        .padding(.top, 2)  // 这是顶部内边距，控制内容上方与边缘的空白距离，单位是pt；改大上方留白更宽，改小上方留白更窄；还能改成.vertical同时控制上下或用EdgeInsets精确控制四边
                }
            }
            .padding(.leading, 4)  // 这是左侧内边距，控制内容左方与边缘的空白距离，单位是pt；改大左方留白更宽，改小左方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
            .padding(.trailing, 8)  // 这是右侧内边距，控制内容右方与边缘的空白距离，单位是pt；改大右方留白更宽，改小右方留白更窄；还能改成.horizontal同时控制左右或用EdgeInsets精确控制四边
            .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            .background(Color(.systemGray6).opacity(0.5))
            .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
        }
        .padding(.vertical, 2)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 空状态视图

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundColor(.gray)
            Text("暂无步骤信息")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 辅助方法

    private func iconForStep(_ step: JobStep) -> String {
        if step.status == "completed" {
            switch step.conclusion {
            case "success": return "checkmark"
            case "failure": return "xmark"
            case "cancelled": return "stop"
            case "skipped": return "arrow.right.to.line"
            default: return "circle"
            }
        } else if step.status == "queued" || step.status == "pending" {
            return "clock"
        }
        return "circle"
    }

    private func backgroundColorForStep(_ step: JobStep) -> Color {
        if step.status == "completed" {
            switch step.conclusion {
            case "success": return .green
            case "failure": return .red
            case "cancelled": return .gray
            case "skipped": return .gray
            default: return .gray
            }
        } else if step.status == "in_progress" {
            return .blue
        } else if step.status == "queued" || step.status == "pending" {
            return .orange
        }
        return .gray
    }

    private func textColorForStep(_ step: JobStep) -> Color {
        if step.status == "completed" {
            switch step.conclusion {
            case "success": return .green
            case "failure": return .red
            case "cancelled": return .gray
            case "skipped": return .gray
            default: return .gray
            }
        } else if step.status == "in_progress" {
            return .blue
        } else if step.status == "queued" || step.status == "pending" {
            return .orange
        }
        return .gray
    }

    private func lineColorForStep(_ step: JobStep) -> Color {
        if step.status == "completed" && step.conclusion == "success" {
            return .green.opacity(0.5)
        } else if step.status == "completed" && step.conclusion == "failure" {
            return .red.opacity(0.5)
        } else if step.status == "in_progress" {
            return .blue.opacity(0.5)
        }
        return .gray.opacity(0.3)
    }

    private func parseDate(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)秒"
        } else if seconds < 3600 {
            return "\(seconds / 60)分\(seconds % 60)秒"
        } else {
            return "\(seconds / 3600)时\((seconds % 3600) / 60)分"
        }
    }
}
