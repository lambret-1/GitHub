import SwiftUI

// MARK: - 运行统计图表视图

struct RunStatsView: View {
    let owner: String
    let repo: String
    @State private var runs: [WorkflowRun] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var selectedTimeRange: Int = 30 // 最近30次运行

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView("加载统计数据中...")
                        Spacer()
                    }
                    .frame(height: 300)  // 视图高度300pt，控制组件垂直尺寸
                } else if let error = errorMessage {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        Text(error)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            loadStats()
                        }
                        .foregroundColor(.blue)
                        Spacer()
                    }
                    .frame(height: 300)  // 视图高度300pt，控制组件垂直尺寸
                    .padding()
                } else {
                    // 时间范围选择
                    timeRangeSelector

                    // 统计概览卡片
                    statsOverviewCard

                    // 成功率饼图
                    successRatePieChart

                    // 状态分布柱状图
                    statusDistributionBarChart

                    // 耗时趋势图
                    durationTrendChart
                }
            }
            .padding()
        }
        .navigationTitle("运行统计")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadStats()
        }
    }

    // MARK: - 时间范围选择器

    private var timeRangeSelector: some View {
        HStack(spacing: 8) {
            Text("统计范围:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Picker("范围", selection: $selectedTimeRange) {
                Text("最近10次").tag(10)
                Text("最近30次").tag(30)
                Text("最近50次").tag(50)
                Text("最近100次").tag(100)
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedTimeRange) { _ in
                loadStats()
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
        .background(Color(.systemGray6))
        .cornerRadius(8)  // 圆角半径8pt，控制视图边角圆润程度
    }

    // MARK: - 统计概览卡片

    private var statsOverviewCard: some View {
        let stats = calculateStats()
        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.blue)
                Text("统计概览")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 0) {
                statItem(title: "总运行", value: "\(stats.totalRuns)", color: .blue)
                Divider()
                statItem(title: "成功", value: "\(stats.successCount)", color: .green)
                Divider()
                statItem(title: "失败", value: "\(stats.failureCount)", color: .red)
                Divider()
                statItem(title: "取消", value: "\(stats.cancelledCount)", color: .gray)
            }
            .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距

            HStack(spacing: 0) {
                statItem(title: "成功率", value: String(format: "%.1f%%", stats.successRate), color: .green)
                Divider()
                statItem(title: "平均耗时", value: stats.averageDurationDisplay, color: .orange)
                Divider()
                statItem(title: "进行中", value: "\(stats.inProgressCount)", color: .blue)
            }
            .padding(.vertical, 8)  // 垂直内边距8pt，控制上下留白间距
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 成功率饼图

    private var successRatePieChart: some View {
        let stats = calculateStats()
        let successAngle = Double(stats.successCount) / Double(max(stats.totalRuns, 1)) * 360
        let failureAngle = Double(stats.failureCount) / Double(max(stats.totalRuns, 1)) * 360
        let cancelledAngle = Double(stats.cancelledCount) / Double(max(stats.totalRuns, 1)) * 360

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.purple)
                Text("成功率分布")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 20) {
                // 饼图
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    // 成功部分
                    Circle()
                        .trim(from: 0, to: CGFloat(successAngle / 360))
                        .stroke(Color.green, lineWidth: 20)
                        .rotationEffect(.degrees(-90))
                    // 失败部分
                    Circle()
                        .trim(from: CGFloat(successAngle / 360), to: CGFloat((successAngle + failureAngle) / 360))
                        .stroke(Color.red, lineWidth: 20)
                        .rotationEffect(.degrees(-90))
                    // 取消部分
                    Circle()
                        .trim(from: CGFloat((successAngle + failureAngle) / 360), to: CGFloat((successAngle + failureAngle + cancelledAngle) / 360))
                        .stroke(Color.gray, lineWidth: 20)
                        .rotationEffect(.degrees(-90))

                    // 中心文字
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f%%", stats.successRate))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("成功率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)  // 视图尺寸宽120pt高120pt，控制组件显示大小

                // 图例
                VStack(alignment: .leading, spacing: 8) {
                    legendItem(color: .green, label: "成功", count: stats.successCount)
                    legendItem(color: .red, label: "失败", count: stats.failureCount)
                    legendItem(color: .gray, label: "取消", count: stats.cancelledCount)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)  // 视图尺寸宽10pt高10pt，控制组件显示大小
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - 状态分布柱状图

    private var statusDistributionBarChart: some View {
        let stats = calculateStats()
        let maxCount = max(stats.successCount, stats.failureCount, stats.cancelledCount, 1)

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.doc.horizontal")
                    .foregroundColor(.orange)
                Text("状态分布")
                    .font(.headline)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 20) {
                barItem(label: "成功", count: stats.successCount, maxCount: maxCount, color: .green)
                barItem(label: "失败", count: stats.failureCount, maxCount: maxCount, color: .red)
                barItem(label: "取消", count: stats.cancelledCount, maxCount: maxCount, color: .gray)
                barItem(label: "进行中", count: stats.inProgressCount, maxCount: maxCount, color: .blue)
            }
            .frame(height: 120)  // 视图高度120pt，控制组件垂直尺寸
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func barItem(label: String, count: Int, maxCount: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .frame(width: 30, height: CGFloat(Double(count) / Double(maxCount) * 80))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 耗时趋势图

    private var durationTrendChart: some View {
        let completedRuns = runs.filter { $0.status == "completed" }.prefix(20)
        let durations = completedRuns.compactMap { run -> Int? in
            let createdAt = run.createdAt
            let updatedAt = run.updatedAt
            guard let createdDate = 日期工具.解析ISO日期(createdAt),
                  let updatedDate = 日期工具.解析ISO日期(updatedAt) else {
                return nil
            }
            return Int(updatedDate.timeIntervalSince(createdDate))
        }
        let maxDuration = max(durations.max() ?? 1, 1)

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("最近运行耗时趋势")
                    .font(.headline)
                Spacer()
            }

            if durations.isEmpty {
                Text("暂无已完成的运行数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 80)  // 视图高度80pt，控制组件垂直尺寸
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(durations.enumerated()), id: \.offset) { index, duration in
                            VStack(spacing: 2) {
                                Text(formatDuration(duration))
                                    .font(.system(size: 8))  // 字体大小8pt，控制文字显示尺寸
                                    .foregroundColor(.secondary)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .bottom, endPoint: .top))
                                    .frame(width: 12, height: CGFloat(Double(duration) / Double(maxDuration) * 60))
                                Text("#\(durations.count - index)")
                                    .font(.system(size: 7))  // 字体大小7pt，控制文字显示尺寸
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)  // 水平内边距4pt，控制左右留白间距
                }
                .frame(height: 100)  // 视图高度100pt，控制组件垂直尺寸
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)  // 圆角半径12pt，控制视图边角圆润程度
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    // MARK: - 计算统计数据

    private func calculateStats() -> (totalRuns: Int, successCount: Int, failureCount: Int, cancelledCount: Int, inProgressCount: Int, successRate: Double, averageDurationSeconds: Int?, averageDurationDisplay: String) {
        let filteredRuns = runs.prefix(selectedTimeRange)
        var successCount = 0
        var failureCount = 0
        var cancelledCount = 0
        var inProgressCount = 0
        var totalDuration = 0
        var durationCount = 0

        for run in filteredRuns {
            if run.status == "completed" {
                switch run.conclusion {
                case "success": successCount += 1
                case "failure": failureCount += 1
                case "cancelled": cancelledCount += 1
                default: break
                }
                // 计算耗时
                let createdAt = run.createdAt
                let updatedAt = run.updatedAt
                if let createdDate = 日期工具.解析ISO日期(createdAt),
                   let updatedDate = 日期工具.解析ISO日期(updatedAt) {
                    let duration = Int(updatedDate.timeIntervalSince(createdDate))
                    if duration > 0 {
                        totalDuration += duration
                        durationCount += 1
                    }
                }
            } else if run.status == "in_progress" {
                inProgressCount += 1
            }
        }

        let totalRuns = filteredRuns.count
        let completedCount = successCount + failureCount + cancelledCount
        let successRate = completedCount > 0 ? Double(successCount) / Double(completedCount) * 100 : 0
        let averageDurationSeconds = durationCount > 0 ? totalDuration / durationCount : nil
        let averageDurationDisplay = averageDurationSeconds != nil ? formatDuration(averageDurationSeconds!) : "-"

        return (totalRuns, successCount, failureCount, cancelledCount, inProgressCount, successRate, averageDurationSeconds, averageDurationDisplay)
    }

    // MARK: - 格式化耗时

    private func formatDuration(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds / 60)m\(seconds % 60)s"
        } else {
            return "\(seconds / 3600)h\((seconds % 3600) / 60)m"
        }
    }

    // MARK: - 加载统计数据

    private func loadStats() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: 1, perPage: selectedTimeRange) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let runs):
                    self.runs = runs
                case .failure(let error):
                    self.errorMessage = "加载统计数据失败: \(error.localizedDescription)"
                }
            }
        }
    }
}
