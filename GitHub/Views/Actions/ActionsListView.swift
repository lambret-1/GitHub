import SwiftUI

// MARK: - Actions 主入口视图（重做版）

struct ActionsListView: View {
    let owner: String
    let repo: String

    // 标签页状态
    @State private var selectedTab: Int = 0

    // 运行记录相关状态
    @State private var runs: [WorkflowRun] = []
    @State private var isLoadingRuns: Bool = false
    @State private var runsError: String?
    @State private var currentPage: Int = 1
    @State private var hasMoreRuns: Bool = true

    // 工作流相关状态
    @State private var workflows: [Workflow] = []
    @State private var isLoadingWorkflows: Bool = false
    @State private var workflowsError: String?

    // 统计概览相关状态
    @State private var stats: RunStats?
    @State private var isLoadingStats: Bool = false

    // 筛选相关状态
    @State private var showFilter: Bool = false
    @State private var filterStatus: String = "all" // all/in_progress/success/failure/cancelled
    @State private var filterBranch: String = ""
    @State private var sortOrder: String = "desc" // desc/asc
    @State private var showSortMenu: Bool = false

    // 触发工作流相关状态
    @State private var showTriggerAlert: Bool = false
    @State private var selectedWorkflow: Workflow?

    // 运行对比相关状态
    @State private var isComparisonMode: Bool = false
    @State private var selectedRunForComparison1: WorkflowRun?
    @State private var selectedRunForComparison2: WorkflowRun?
    @State private var showComparisonView: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏：对比、统计、设置按钮（原导航栏按钮移到这里，避免嵌入FileBrowserView时导航栏冲突）
            HStack {
                Spacer()
                // 对比按钮
                Button(action: {
                    isComparisonMode.toggle()
                    if !isComparisonMode {
                        selectedRunForComparison1 = nil
                        selectedRunForComparison2 = nil
                    }
                }) {
                    Image(systemName: isComparisonMode ? "xmark.circle.fill" : "arrow.left.arrow.right")
                        .foregroundColor(isComparisonMode ? .red : .primary)
                }
                .padding(.horizontal, 8)

                NavigationLink(destination: RunStatsView(owner: owner, repo: repo)) {
                    Image(systemName: "chart.bar.xaxis")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)

                NavigationLink(destination: ActionsSettingsView(owner: owner, repo: repo)) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 8)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)  // 这是垂直内边距，控制工具栏上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽更透气，改小上下留白更窄更紧凑；还能改成.top/.bottom单独控制某一侧

            // 统计概览卡片
            statsOverviewCard

            // 标签切换
            Picker("选择", selection: $selectedTab) {
                Text("运行记录").tag(0)
                Text("工作流").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧

            // 内容区域
            if selectedTab == 0 {
                runsListView
            } else {
                workflowsListView
            }
        }
        // 移除导航栏相关修饰符，因为ActionsListView现在嵌入在FileBrowserView中，不需要自己的导航栏
        // 原.navigationTitle("Actions")、.navigationBarTitleDisplayMode(.inline)、.navigationBarItems(trailing:)已移除
        .navigationDestination(isPresented: $showComparisonView) {
            comparisonDestination
        }
        .onAppear {
            if runs.isEmpty {
                loadRuns()
            }
            if workflows.isEmpty {
                loadWorkflows()
            }
            if stats == nil {
                loadStats()
            }
        }
        .alert(isPresented: $showTriggerAlert) {
            Alert(
                title: Text("触发工作流"),
                message: Text("确定要触发「\(selectedWorkflow?.name ?? "")」工作流吗？"),
                primaryButton: .default(Text("触发")) {
                    if let workflow = selectedWorkflow {
                        triggerWorkflow(workflow)
                    }
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }

    // MARK: - 对比目标视图

    @ViewBuilder
    private var comparisonDestination: some View {
        if let run1 = selectedRunForComparison1, let run2 = selectedRunForComparison2 {
            RunComparisonView(owner: owner, repo: repo, run1: run1, run2: run2)
        } else {
            EmptyView()
        }
    }

    // MARK: - 统计概览卡片

    private var statsOverviewCard: some View {
        HStack(spacing: 12) {
            // 总运行次数
            statItem(
                icon: "bolt.fill",
                color: .blue,
                value: "\(stats?.totalRuns ?? 0)",
                label: "总运行"
            )

            Divider()
                .frame(height: 25)  // 这是视图高度尺寸，控制组件垂直方向显示高度，单位是pt；改大组件纵向更高，改小组件纵向更矮；还能改成.maxHeight: .infinity占满父视图或用.minHeight设最小高度

            // 成功率
            statItem(
                icon: "checkmark.circle.fill",
                color: .green,
                value: String(format: "%.0f%%", stats?.successRate ?? 0),
                label: "成功率"
            )

            Divider()
                .frame(height: 25)  // 这是视图高度尺寸，控制组件垂直方向显示高度，单位是pt；改大组件纵向更高，改小组件纵向更矮；还能改成.maxHeight: .infinity占满父视图或用.minHeight设最小高度

            // 平均耗时
            statItem(
                icon: "clock.fill",
                color: .orange,
                value: stats?.averageDurationDisplay ?? "-",
                label: "平均耗时"
            )
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 12)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(Color(.systemGray6))
    }

    private func statItem(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 筛选和排序后的运行列表

    private var filteredRuns: [WorkflowRun] {
        var result = runs

        // 按状态筛选
        if filterStatus != "all" {
            if filterStatus == "in_progress" {
                result = result.filter { $0.status == "in_progress" || $0.status == "queued" }
            } else {
                result = result.filter { $0.conclusion == filterStatus }
            }
        }

        // 按分支筛选
        if !filterBranch.isEmpty {
            result = result.filter { $0.headBranch == filterBranch }
        }

        // 排序
        if sortOrder == "asc" {
            result = result.reversed()
        }

        return result
    }

    // MARK: - 对比模式提示栏

    private var comparisonModeBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.blue)
                Text("对比模式 - 选择两次运行进行对比")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                Spacer()
            }

            HStack(spacing: 8) {
                // 已选择的运行1
                VStack(alignment: .leading, spacing: 2) {
                    Text("运行1")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let run1 = selectedRunForComparison1 {
                        Text("#\(run1.runNumber) - \(run1.name)")
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Text("未选择")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑

                Text("VS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.gray)

                // 已选择的运行2
                VStack(alignment: .leading, spacing: 2) {
                    Text("运行2")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if let run2 = selectedRunForComparison2 {
                        Text("#\(run2.runNumber) - \(run2.name)")
                            .font(.caption)
                            .lineLimit(1)
                    } else {
                        Text("未选择")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)  // 这是四向统一内边距，控制内容上下左右四边与边缘的空白距离，单位是pt；改大四边留白更宽内容更居中透气，改小四边留白更窄内容更紧凑靠边；还能改成.horizontal/.vertical分别控制或用EdgeInsets精确设置不同边距
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }

            // 开始对比按钮
            if selectedRunForComparison1 != nil && selectedRunForComparison2 != nil {
                Button(action: {
                    showComparisonView = true
                }) {
                    HStack {
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                        Text("开始对比")
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    .background(Color.blue)
                    .cornerRadius(8)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .listRowSeparator(.hidden)
    }

    // MARK: - 对比模式辅助方法

    private func selectRunForComparison(_ run: WorkflowRun) {
        if selectedRunForComparison1 == nil {
            selectedRunForComparison1 = run
        } else if selectedRunForComparison2 == nil {
            if selectedRunForComparison1?.id == run.id {
                // 取消选择第一个
                selectedRunForComparison1 = nil
            } else {
                selectedRunForComparison2 = run
            }
        } else {
            // 两个都已选择，重新开始
            selectedRunForComparison1 = run
            selectedRunForComparison2 = nil
        }
    }

    private func isRunSelected(_ run: WorkflowRun) -> Bool {
        return selectedRunForComparison1?.id == run.id || selectedRunForComparison2?.id == run.id
    }

    // MARK: - 筛选和排序栏

    private var filterSortBar: some View {
        HStack(spacing: 8) {
            // 状态筛选
            Menu {
                Button("全部") { filterStatus = "all" }
                Button("进行中") { filterStatus = "in_progress" }
                Button("成功") { filterStatus = "success" }
                Button("失败") { filterStatus = "failure" }
                Button("已取消") { filterStatus = "cancelled" }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                    Text(statusFilterDisplay)
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }

            // 排序
            Button(action: {
                sortOrder = sortOrder == "desc" ? "asc" : "desc"
            }) {
                HStack(spacing: 4) {
                    Image(systemName: sortOrder == "desc" ? "arrow.down.circle" : "arrow.up.circle")
                        .font(.caption)
                    Text(sortOrder == "desc" ? "最新" : "最早")
                        .font(.caption)
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color.blue.opacity(0.1))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }

            Spacer()

            // 结果计数
            Text("\(filteredRuns.count) 条")
                .font(.caption2)
                .foregroundColor(.secondary)

            // 清除筛选
            if filterStatus != "all" || !filterBranch.isEmpty {
                Button(action: {
                    filterStatus = "all"
                    filterBranch = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 4)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .listRowSeparator(.hidden)
    }

    private var statusFilterDisplay: String {
        switch filterStatus {
        case "all": return "全部状态"
        case "in_progress": return "进行中"
        case "success": return "成功"
        case "failure": return "失败"
        case "cancelled": return "已取消"
        default: return "全部状态"
        }
    }

    // MARK: - 运行记录列表

    private var runsListView: some View {
        Group {
            if isLoadingRuns && runs.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = runsError, runs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadRuns()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if runs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无运行记录")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 使用VStack替代List和ScrollView，让内容直接跟随外层屏幕滑动，避免嵌套滚动冲突
                VStack(spacing: 0) {
                    // 对比模式提示栏
                    if isComparisonMode {
                        comparisonModeBar
                    }

                    // 筛选和排序栏
                    filterSortBar

                    ForEach(filteredRuns) { run in
                        if isComparisonMode {
                            // 对比模式：点击选择运行
                            Button(action: {
                                selectRunForComparison(run)
                            }) {
                                WorkflowRunRow(run: run)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isRunSelected(run) ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // 正常模式：点击进入详情
                            NavigationLink(destination: WorkflowRunDetailView(owner: owner, repo: repo, run: run)) {
                                WorkflowRunRow(run: run)
                            }
                            .onAppear {
                                if run.id == filteredRuns.last?.id && hasMoreRuns && !isLoadingRuns {
                                    loadMoreRuns()
                                }
                            }
                        }
                        // 手动添加分隔线，替代List默认分隔线
                        Divider()
                            .padding(.leading, 16)
                    }

                    if isLoadingRuns {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
        }
    }

    // MARK: - 工作流列表

    private var workflowsListView: some View {        Group {
            if isLoadingWorkflows && workflows.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = workflowsError, workflows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadWorkflows()
                    }
                    .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if workflows.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "bolt")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无工作流")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 使用VStack替代List和ScrollView，让内容直接跟随外层屏幕滑动，避免嵌套滚动冲突
                VStack(spacing: 12) {
                    ForEach(workflows) { workflow in
                        WorkflowCard(owner: owner, repo: repo, workflow: workflow) {
                            selectedWorkflow = workflow
                            showTriggerAlert = true
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    // MARK: - 数据加载

    private func loadRuns(completion: (() -> Void)? = nil) {
        isLoadingRuns = true
        runsError = nil

        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                isLoadingRuns = false
                switch result {
                case .success(let runs):
                    if currentPage == 1 {
                        self.runs = runs
                    } else {
                        self.runs.append(contentsOf: runs)
                    }
                    self.hasMoreRuns = runs.count >= 30
                case .failure(let error):
                    self.runsError = "加载运行记录失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadMoreRuns() {
        currentPage += 1
        loadRuns()
    }

    private func loadWorkflows(completion: (() -> Void)? = nil) {
        isLoadingWorkflows = true
        workflowsError = nil

        GitHubAPI.shared.getWorkflows(owner: owner, repo: repo) { result in
            DispatchQueue.main.async {
                isLoadingWorkflows = false
                switch result {
                case .success(let workflows):
                    self.workflows = workflows
                case .failure(let error):
                    self.workflowsError = "加载工作流失败: \(error.localizedDescription)"
                }
                completion?()
            }
        }
    }

    private func loadStats() {
        isLoadingStats = true
        // 加载最近30次运行用于统计
        GitHubAPI.shared.getWorkflowRuns(owner: owner, repo: repo, page: 1, perPage: 30) { result in
            DispatchQueue.main.async {
                self.isLoadingStats = false
                switch result {
                case .success(let runs):
                    var successCount = 0
                    var failureCount = 0
                    var cancelledCount = 0
                    var inProgressCount = 0
                    var totalDuration = 0
                    var durationCount = 0

                    for run in runs {
                        if run.status == "completed" {
                            switch run.conclusion {
                            case "success": successCount += 1
                            case "failure": failureCount += 1
                            case "cancelled": cancelledCount += 1
                            default: break
                            }
                            // 计算运行时长（秒）
                            if let createdDate = 日期工具.解析ISO日期(run.createdAt),
                               let updatedDate = 日期工具.解析ISO日期(run.updatedAt) {
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

                    // 安全计算平均耗时，避免除以零
                    let avgDuration: Int?
                    if durationCount > 0 {
                        avgDuration = totalDuration / durationCount
                    } else {
                        avgDuration = nil
                    }

                    self.stats = RunStats(
                        totalRuns: runs.count,
                        successCount: successCount,
                        failureCount: failureCount,
                        cancelledCount: cancelledCount,
                        inProgressCount: inProgressCount,
                        averageDurationSeconds: avgDuration
                    )
                case .failure:
                    self.stats = nil
                }
            }
        }
    }

    private func triggerWorkflow(_ workflow: Workflow) {
        GitHubAPI.shared.triggerWorkflowDispatch(owner: owner, repo: repo, workflowId: workflow.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // 触发成功后刷新运行记录
                    selectedTab = 0
                    currentPage = 1
                    hasMoreRuns = true
                    loadRuns()
                case .failure(let error):
                    runsError = "触发工作流失败: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - 异步加载方法（用于下拉刷新）

    private func loadRunsAsync() async {
        await withCheckedContinuation { continuation in
            loadRuns {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }

    private func loadWorkflowsAsync() async {
        await withCheckedContinuation { continuation in
            loadWorkflows {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - 工作流运行行视图（重做版）

struct WorkflowRunRow: View {
    let run: WorkflowRun
    @State private var rotationAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            // 状态图标
            ZStack {
                if run.status == "in_progress" {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                        .rotationEffect(.degrees(rotationAngle))
                        .onAppear {
                            withAnimation(Animation.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                                rotationAngle = 360
                            }
                        }
                } else if run.status == "queued" || run.status == "pending" {
                    Image(systemName: "clock")
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                        .opacity(0.5 + 0.5 * sin(rotationAngle / 180 * .pi))
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                                rotationAngle = 360
                            }
                        }
                } else {
                    Image(systemName: run.statusIcon)
                        .font(.title2)
                        .foregroundColor(Color(run.statusColor))
                }
            }
            .frame(width: 30)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            VStack(alignment: .leading, spacing: 4) {
                // 工作流名称和运行编号
                HStack {
                    Text(run.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text("#\(run.runNumber)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // 分支和提交信息
                HStack(spacing: 8) {
                    Image(systemName: "branch")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(run.headBranch)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(run.shortSha)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }

                // 触发事件和时间
                HStack(spacing: 8) {
                    Text(run.eventDisplay)
                        .font(.caption2)
                        .padding(.horizontal, 6)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 2)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑

                    Text(run.formattedCreatedAt)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 状态文本
            Text(run.statusDisplay)
                .font(.caption)
                .foregroundColor(Color(run.statusColor))
                .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color(run.statusColor).opacity(0.1))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
        }
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }
}

// MARK: - 工作流卡片视图（重做版）

struct WorkflowCard: View {
    let owner: String
    let repo: String
    let workflow: Workflow
    var onTrigger: () -> Void
    @State private var showFileView: Bool = false
    @State private var showTriggerView: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // 工作流图标
            Image(systemName: "bolt.fill")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                // 工作流名称
                Text(workflow.name)
                    .font(.headline)
                    .lineLimit(1)

                // 文件名
                Text(workflow.fileName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                // 状态
                HStack(spacing: 4) {
                    Circle()
                        .fill(workflow.state == "active" ? Color.green : Color.gray)
                        .frame(width: 6, height: 6)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    Text(workflow.stateDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 8) {
                // 查看文件按钮
                Button(action: {
                    showFileView = true
                }) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .buttonStyle(PlainButtonStyle())

                // 触发按钮（带参数）
                Button(action: {
                    showTriggerView = true
                }) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .background(Color.green)
                        .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .sheet(isPresented: $showFileView) {
            NavigationView {
                WorkflowFileView(owner: owner, repo: repo, workflow: workflow)
            }
        }
        .sheet(isPresented: $showTriggerView) {
            TriggerWorkflowView(owner: owner, repo: repo, workflow: workflow)
        }
    }
}

// MARK: - 颜色扩展

extension Color {
    init(_ name: String) {
        switch name {
        case "systemGreen": self = .green
        case "systemRed": self = .red
        case "systemBlue": self = .blue
        case "systemOrange": self = .orange
        case "systemGray": self = .gray
        default: self = .gray
        }
    }
}
