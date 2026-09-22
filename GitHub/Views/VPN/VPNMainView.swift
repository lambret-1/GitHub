//
//  VPNMainView.swift
//  GitHub
//
//  用途：VPN 主页面，按照小火箭（Shadowrocket）布局一比一实现
//  功能：
//    1. VPN 连接控制（开关式）
//    2. 全局路由配置
//    3. 连通性测试
//    4. 节点分组管理（本地节点 + 订阅分组）
//    5. 订阅更新
//    6. 节点测速
//  布局参考：小火箭首页（除顶部和底部导航栏外的所有功能）
//

import SwiftUI

// MARK: - VPN 主页面

/// VPN 主页面
/// 独立全屏页面，使用 NavigationView 拥有独立导航栈
struct VPNMainView: View {

    // MARK: - 状态属性

    /// VPN 管理器可观察对象
    @ObservedObject private var vpnManagerObservable = VPNManagerObservable()

    /// 页面关闭控制器（用于独立全屏页面返回）
    @Environment(\.dismiss) private var dismiss

    /// 是否显示添加节点页面
    @State private var showAddNodeView = false

    /// 是否显示订阅管理页面
    @State private var showSubscriptionView = false

    /// 是否显示分组详情页面
    @State private var showGroupDetail = false
    @State private var selectedGroupName: String?

    /// 是否显示导入中提示
    @State private var isImporting = false

    /// 提示消息
    @State private var alertMessage: String?

    /// 是否显示提示
    @State private var showAlert = false

    /// 要删除的节点（用于确认对话框）
    @State private var nodeToDelete: VPNNode?

    /// 编辑模式（用于批量删除）
    @State private var editMode: EditMode = .inactive

    /// 选中的节点（批量删除用）
    @State private var selectedNodes = Set<String>()

    /// 展开的分组名称集合
    @State private var expandedGroups: Set<String> = []

    /// 连通性测试中
    @State private var isTestingConnectivity = false

    /// 连通性测试结果
    @State private var connectivityResult: String?

    /// 本地节点分组名称常量
    private let localGroupName = "本地节点"

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 连接控制区（小火箭风格）
                connectionControlSection

                // 工具栏（模块、全部更新、更多）
                toolbarSection

                // 分组列表
                groupList
            }
            .navigationTitle("VPN 代理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角返回按钮
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("我的")
                        }
                    }
                }

                // 右上角添加按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showSubscriptionView = true
                        }) {
                            Label("订阅管理", systemImage: "dot.radiowaves.left.and.right")
                        }

                        Divider()

                        Button(action: {
                            showAddNodeView = true
                        }) {
                            Label("手动添加节点", systemImage: "plus.circle")
                        }

                        Button(action: {
                            importFromPasteboard()
                        }) {
                            Label("从剪贴板导入", systemImage: "doc.on.clipboard")
                        }

                        Button(action: {
                            toggleEditMode()
                        }) {
                            Label(editMode == .active ? "完成" : "管理节点", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddNodeView) {
                AddNodeView()
            }
            .fullScreenCover(isPresented: $showSubscriptionView) {
                SubscriptionListView()
            }
            .fullScreenCover(isPresented: $showGroupDetail) {
                if let groupName = selectedGroupName {
                    GroupDetailView(groupName: groupName)
                }
            }
            .onChange(of: showAddNodeView) { newValue in
                // 添加节点页面关闭后刷新节点列表
                if !newValue {
                    vpnManagerObservable.refresh()
                }
            }
            .onAppear {
                // 页面出现时刷新节点列表和连接状态
                vpnManagerObservable.refresh()
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("确认删除", isPresented: .constant(nodeToDelete != nil)) {
                Button("取消", role: .cancel) {
                    nodeToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let node = nodeToDelete {
                        VPNManager.shared.removeNode(node)
                        vpnManagerObservable.refresh()
                    }
                    nodeToDelete = nil
                }
            } message: {
                if let node = nodeToDelete {
                    Text("确定要删除节点「\(node.remark)」吗？")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 连接控制区（小火箭风格）

    /// 连接控制区
    /// 包含：连接开关、全局路由、连通性测试
    private var connectionControlSection: some View {
        VStack(spacing: 0) {
            // 1. 连接状态行（火箭图标 + 未连接 + 开关）
            HStack(spacing: 12) {
                // 火箭图标
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 22))
                    .foregroundColor(vpnManagerObservable.connectionStatus.isActive ? .green : .gray)
                    .frame(width: 30)
                // 这是一个什么东西：火箭图标宽度
                // 控制哪里：连接状态行左侧火箭图标的宽度
                // 单位是什么：pt（点）
                // 改大有什么效果：图标区域变宽
                // 改小有什么效果：图标区域变窄
                // 还能怎么改：可以根据图标大小动态调整

                // 状态文字
                Text(vpnManagerObservable.connectionStatus.isActive ? "已连接" : "未连接")
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                // 连接开关
                Toggle("", isOn: Binding(
                    get: { vpnManagerObservable.connectionStatus.isActive },
                    set: { _ in toggleConnection() }
                ))
                .labelsHidden()
                .frame(width: 51)
                // 这是一个什么东西：连接开关宽度
                // 控制哪里：连接状态行右侧开关的宽度
                // 单位是什么：pt（点）
                // 改大有什么效果：开关变宽，点击区域更大
                // 改小有什么效果：开关变窄，更紧凑
                // 还能怎么改：iOS 系统开关默认宽度51pt，不建议修改
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            // 这是一个什么东西：连接状态行内边距
            // 控制哪里：连接状态行内容与边缘的距离
            // 单位是什么：pt（点）
            // 改大有什么效果：行变高，更宽松
            // 改小有什么效果：行变矮，更紧凑
            // 还能怎么改：可以分别设置上下左右不同的内边距
            .background(Color(.systemBackground))

            Divider()
                .padding(.leading, 58)
            // 这是一个什么东西：分隔线左内边距
            // 控制哪里：分隔线左侧的缩进距离
            // 单位是什么：pt（点）
            // 改大有什么效果：分隔线更短，缩进更多
            // 改小有什么效果：分隔线更长，缩进更少
            // 还能怎么改：可以设置为0实现全宽分隔线

            // 2. 全局路由行
            Button(action: {
                displayAlert(message: "全局路由配置功能（后续实现）")
            }) {
                HStack(spacing: 12) {
                    // 设置图标
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                        .frame(width: 30)

                    Text("全局路由")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    Text("配置")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)

            Divider()
                .padding(.leading, 58)

            // 3. 连通性测试行
            Button(action: {
                testConnectivity()
            }) {
                HStack(spacing: 12) {
                    // 时钟图标
                    Image(systemName: "clock.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                        .frame(width: 30)

                    Text("连通性测试")
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    if isTestingConnectivity {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if let result = connectivityResult {
                        Text(result)
                            .font(.caption)
                            .foregroundColor(result.contains("成功") ? .green : .red)
                    }

                    Image(systemName: "arrow.clockwise.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
            .disabled(isTestingConnectivity)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - 工具栏

    /// 工具栏（模块、全部更新、更多）
    private var toolbarSection: some View {
        HStack(spacing: 0) {
            Spacer()

            // 模块/配置图标
            Button(action: {
                displayAlert(message: "模块配置功能（后续实现）")
            }) {
                Image(systemName: "slider.horizontal.below.rectangle")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
                    // 这是一个什么东西：工具栏按钮尺寸
                    // 控制哪里：工具栏每个按钮的点击区域大小
                    // 单位是什么：pt（点）
                    // 改大有什么效果：按钮变大，点击区域更大
                    // 改小有什么效果：按钮变小，更紧凑
                    // 还能怎么改：可以使用不同的宽高比
            }

            // 全部更新
            Button(action: {
                updateAllSubscriptions()
            }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
            }

            // 更多操作
            Menu {
                Button(action: {
                    showSubscriptionView = true
                }) {
                    Label("订阅管理", systemImage: "dot.radiowaves.left.and.right")
                }
                Button(action: {
                    testAllNodesLatency()
                }) {
                    Label("全部测速", systemImage: "gauge")
                }
                Button(action: {
                    toggleEditMode()
                }) {
                    Label(editMode == .active ? "完成管理" : "管理节点", systemImage: "slider.horizontal.3")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - 分组列表

    /// 分组列表（折叠/展开模式）
    private var groupList: some View {
        List {
            if vpnManagerObservable.nodes.isEmpty {
                // 空状态
                emptyStateView
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemGroupedBackground))
            } else {
                // 按分组展示
                ForEach(sortedGroupNames, id: \.self) { groupName in
                    groupSection(groupName: groupName, nodes: groupedNodes[groupName] ?? [])
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .background(Color(.systemGroupedBackground))
    }

    /// 单个分组区域（可折叠/展开）
    private func groupSection(groupName: String, nodes: [VPNNode]) -> some View {
        let isExpanded = expandedGroups.contains(groupName)
        let isLocal = groupName == localGroupName

        return Section {
            // 展开状态：显示该分组下的所有节点
            if isExpanded {
                ForEach(nodes) { node in
                    nodeRowInGroup(node)
                        .listRowInsets(EdgeInsets(top: 6, leading: 58, bottom: 6, trailing: 16))
                        // 这是一个什么东西：节点行左内边距
                        // 控制哪里：展开后节点行左侧的缩进距离
                        // 单位是什么：pt（点）
                        // 改大有什么效果：节点缩进更多，层级更明显
                        // 改小有什么效果：节点缩进更少，更紧凑
                        // 还能怎么改：可以与分组名称左对齐
                        .listRowBackground(Color(.systemBackground))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectNode(node)
                        }
                        .contextMenu {
                            Button(action: {
                                selectNode(node)
                            }) {
                                Label("使用此节点", systemImage: "checkmark.circle")
                            }
                            Button(action: {
                                testNodeLatency(node)
                            }) {
                                Label("测速", systemImage: "gauge")
                            }
                            Button(role: .destructive, action: {
                                nodeToDelete = node
                            }) {
                                Label("删除节点", systemImage: "trash")
                            }
                        }
                }
                .onDelete { indexSet in
                    let nodesToDelete = indexSet.map { nodes[$0] }
                    VPNManager.shared.removeNodes(nodesToDelete)
                    vpnManagerObservable.refresh()
                }
            }
        } header: {
            // 分组标题行（点击折叠/展开）
            Button(action: {
                toggleGroup(groupName)
            }) {
                HStack(spacing: 10) {
                    // 折叠/展开箭头
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    // 这是一个什么东西：折叠箭头图标宽度
                    // 控制哪里：分组标题左侧箭头图标的宽度
                    // 单位是什么：pt（点）
                    // 改大有什么效果：箭头区域变宽
                    // 改小有什么效果：箭头区域变窄
                    // 还能怎么改：可以根据图标大小动态调整

                    // 分组图标
                    Image(systemName: isLocal ? "folder.fill" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 16))
                        .foregroundColor(isLocal ? .orange : .blue)
                        .frame(width: 24)
                    // 这是一个什么东西：分组图标宽度
                    // 控制哪里：分组标题中图标的宽度
                    // 单位是什么：pt（点）
                    // 改大有什么效果：图标区域变宽
                    // 改小有什么效果：图标区域变窄
                    // 还能怎么改：可以根据图标大小动态调整

                    // 分组名称
                    Text(groupName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    // 节点数量
                    Text("(\(nodes.count))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    // 非本地分组显示更新按钮
                    if !isLocal {
                        Button(action: {
                            updateSubscription(groupName)
                        }) {
                            Image(systemName: "arrow.clockwise.circle")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    // 信息按钮（进入分组详情）
                    Button(action: {
                        selectedGroupName = groupName
                        showGroupDetail = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)
                // 这是一个什么东西：分组标题垂直内边距
                // 控制哪里：分组标题栏的高度
                // 单位是什么：pt（点）
                // 改大有什么效果：标题栏变高，点击区域更大
                // 改小有什么效果：标题栏变矮，更紧凑
                // 还能怎么改：可以使用固定高度
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color(.systemGroupedBackground))
        }
    }

    /// 分组内的节点行（简化版）
    private func nodeRowInGroup(_ node: VPNNode) -> some View {
        HStack(spacing: 10) {
            // 协议图标
            ZStack {
                Circle()
                    .fill(protocolColor(node.protocolType).opacity(0.15))
                    .frame(width: 32, height: 32)
                // 这是一个什么东西：协议图标圆形背景大小
                // 控制哪里：节点行左侧协议图标的背景大小
                // 单位是什么：pt（点）
                // 改大有什么效果：图标背景变大
                // 改小有什么效果：图标背景变小
                // 还能怎么改：可以改成圆角矩形

                Text(node.protocolType.displayName.prefix(2))
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(protocolColor(node.protocolType))
            }

            // 节点信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(node.remark)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    if vpnManagerObservable.currentNode?.id == node.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 11))
                    }
                }

                Text("\(node.protocolType.displayName)/\(node.transportType.displayName.uppercased())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // 延迟
            if let latency = node.latency {
                Text("\(latency)ms")
                    .font(.subheadline)
                    .foregroundColor(latencyColor(latency))
            }
        }
        .padding(.vertical, 4)
    }

    /// 切换分组展开/折叠状态
    private func toggleGroup(_ groupName: String) {
        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
        } else {
            expandedGroups.insert(groupName)
        }
    }

    // MARK: - 分组计算属性

    /// 节点分组字典（分组名称 -> 节点列表）
    private var groupedNodes: [String: [VPNNode]] {
        var groups: [String: [VPNNode]] = [:]

        for node in vpnManagerObservable.nodes {
            let groupName = (node.group?.isEmpty == false) ? node.group! : localGroupName
            if groups[groupName] == nil {
                groups[groupName] = []
            }
            groups[groupName]?.append(node)
        }

        return groups
    }

    /// 排序后的分组名称列表（本地节点排在最前面）
    private var sortedGroupNames: [String] {
        let names = groupedNodes.keys.sorted()
        return names.sorted { first, second in
            if first == localGroupName { return true }
            if second == localGroupName { return false }
            return first < second
        }
    }

    /// 获取分组对应的订阅信息
    private func getSubscription(for groupName: String) -> VPNSubscription? {
        return VPNSubscriptionManager.shared.subscriptions.first { $0.name == groupName }
    }

    // MARK: - 空状态视图

    /// 空状态视图（没有节点时显示）
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "paperplane")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding(.top, 60)

            Text("还没有添加节点")
                .font(.headline)
                .foregroundColor(.primary)

            Text("点击右上角 + 号添加节点，或从剪贴板导入")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: {
                showAddNodeView = true
            }) {
                Text("添加节点")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 方法

    /// 切换连接状态
    private func toggleConnection() {
        VPNManager.shared.toggleConnection { error in
            if let error = error {
                displayAlert(message: "连接失败: \(error.localizedDescription)")
            }
        }
    }

    /// 连通性测试
    private func testConnectivity() {
        isTestingConnectivity = true
        connectivityResult = nil

        // 简单的网络连通性测试（访问百度）
        let url = URL(string: "https://www.baidu.com")!
        let task = URLSession.shared.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                self.isTestingConnectivity = false
                if let error = error {
                    self.connectivityResult = "失败"
                    self.displayAlert(message: "连通性测试失败：\(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    self.connectivityResult = httpResponse.statusCode == 200 ? "成功" : "失败(\(httpResponse.statusCode))"
                }
            }
        }
        task.resume()
    }

    /// 更新单个订阅
    private func updateSubscription(_ groupName: String) {
        guard let subscription = getSubscription(for: groupName) else {
            displayAlert(message: "未找到订阅「\(groupName)」")
            return
        }

        displayAlert(message: "正在更新订阅「\(groupName)」...")

        VPNSubscriptionManager.shared.updateSubscription(subscription) { result in
            DispatchQueue.main.async {
                self.vpnManagerObservable.refresh()
                switch result {
                case .success(_, let nodes):
                    self.displayAlert(message: "更新成功，获取到 \(nodes.count) 个节点")
                case .failure(_, let error):
                    self.displayAlert(message: "更新失败：\(error.localizedDescription)")
                }
            }
        }
    }

    /// 更新所有订阅
    private func updateAllSubscriptions() {
        let subscriptions = VPNSubscriptionManager.shared.enabledSubscriptions()
        guard !subscriptions.isEmpty else {
            displayAlert(message: "没有可更新的订阅")
            return
        }

        displayAlert(message: "正在更新 \(subscriptions.count) 个订阅...")

        VPNSubscriptionManager.shared.updateAllSubscriptions { successCount, failureCount in
            DispatchQueue.main.async {
                self.vpnManagerObservable.refresh()
                if failureCount == 0 {
                    self.displayAlert(message: "全部更新成功，共更新 \(successCount) 个订阅")
                } else {
                    self.displayAlert(message: "更新完成：成功 \(successCount) 个，失败 \(failureCount) 个")
                }
            }
        }
    }

    /// 测试所有节点延迟
    private func testAllNodesLatency() {
        let nodes = vpnManagerObservable.nodes
        guard !nodes.isEmpty else {
            displayAlert(message: "没有可测速的节点")
            return
        }

        displayAlert(message: "正在测速 \(nodes.count) 个节点...")

        VPNManager.shared.testAllNodesLatency(nodes: nodes, progress: { completed, total in
            // 进度更新
        }) {
            DispatchQueue.main.async {
                self.vpnManagerObservable.refresh()
                self.displayAlert(message: "全部测速完成")
            }
        }
    }

    /// 从剪贴板导入节点
    private func importFromPasteboard() {
        isImporting = true

        VPNNodeImporter.importFromPasteboard { result in
            isImporting = false

            switch result {
            case .success(let nodes):
                for node in nodes {
                    VPNManager.shared.addNode(node)
                }
                vpnManagerObservable.refresh()
                displayAlert(message: "成功导入 \(nodes.count) 个节点")

            case .failure(let error):
                displayAlert(message: "导入失败: \(error.localizedDescription)")
            }
        }
    }

    /// 切换编辑模式
    private func toggleEditMode() {
        withAnimation {
            if editMode == .active {
                editMode = .inactive
                selectedNodes.removeAll()
            } else {
                editMode = .active
            }
        }
    }

    /// 显示提示
    private func displayAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 分组详情页面

/// 分组详情页面（小火箭风格）
/// 显示分组内的所有节点，支持测试/更新标签切换
struct GroupDetailView: View {

    // MARK: - 属性

    /// 分组名称
    let groupName: String

    /// VPN 管理器可观察对象
    @ObservedObject private var vpnManagerObservable = VPNManagerObservable()

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// 当前选中的标签（测试/更新）
    @State private var selectedTab: Int = 0 // 0=测试, 1=更新

    /// 是否显示分组选择器
    @State private var showGroupPicker = false

    /// 要删除的节点
    @State private var nodeToDelete: VPNNode?

    /// 提示消息
    @State private var alertMessage: String?
    @State private var showAlert = false

    /// 本地节点分组名称常量
    private let localGroupName = "本地节点"

    // MARK: - 计算属性

    /// 当前分组的节点列表
    private var nodes: [VPNNode] {
        if groupName == localGroupName {
            return vpnManagerObservable.nodes.filter { $0.group?.isEmpty != false }
        }
        return vpnManagerObservable.nodes.filter { $0.group == groupName }
    }

    /// 所有分组名称
    private var allGroupNames: [String] {
        var groups = Set<String>()
        for node in vpnManagerObservable.nodes {
            let name = (node.group?.isEmpty == false) ? node.group! : localGroupName
            groups.insert(name)
        }
        return groups.sorted { first, second in
            if first == localGroupName { return true }
            if second == localGroupName { return false }
            return first < second
        }
    }

    /// 当前分组的订阅信息
    private var subscription: VPNSubscription? {
        return VPNSubscriptionManager.shared.subscriptions.first { $0.name == groupName }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 分组控制栏
                groupControlBar

                // 节点列表
                nodeList
            }
            .navigationTitle(groupName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("VPN")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // 分组详情/设置
                        displayAlert(message: "分组设置功能（后续实现）")
                    }) {
                        Image(systemName: "info.circle")
                    }
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("确认删除", isPresented: .constant(nodeToDelete != nil)) {
                Button("取消", role: .cancel) {
                    nodeToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let node = nodeToDelete {
                        VPNManager.shared.removeNode(node)
                        vpnManagerObservable.refresh()
                    }
                    nodeToDelete = nil
                }
            } message: {
                if let node = nodeToDelete {
                    Text("确定要删除节点「\(node.remark)」吗？")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 分组控制栏

    /// 分组控制栏（测试/更新标签 + 分组名称 + 下拉切换）
    private var groupControlBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // 测试标签
                Button(action: {
                    selectedTab = 0
                }) {
                    Text("测试")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == 0 ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == 0 ? Color.green : Color.clear)
                }

                // 更新标签
                Button(action: {
                    selectedTab = 1
                }) {
                    Text("更新")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedTab == 1 ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedTab == 1 ? Color.green : Color.clear)
                }
            }
            .frame(height: 36)
            // 这是一个什么东西：标签栏高度
            // 控制哪里：测试/更新标签栏的高度
            // 单位是什么：pt（点）
            // 改大有什么效果：标签栏变高，点击区域更大
            // 改小有什么效果：标签栏变矮，更紧凑
            // 还能怎么改：可以使用固定高度或自适应

            // 分组名称和更新时间
            HStack {
                // 下拉箭头 + 分组名称
                Button(action: {
                    showGroupPicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                        Text(groupName)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // 更新时间
                if let subscription = subscription {
                    Text(subscription.lastUpdatedText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()
        }
        .background(Color(.systemBackground))
        .actionSheet(isPresented: $showGroupPicker) {
            var buttons: [ActionSheet.Button] = allGroupNames.map { name in
                .default(Text(name)) {
                    // 切换分组（通过重新创建视图实现）
                    NotificationCenter.default.post(name: NSNotification.Name("SwitchGroup"), object: name)
                }
            }
            buttons.append(.cancel())
            return ActionSheet(title: Text("选择分组"), buttons: buttons)
        }
    }

    // MARK: - 节点列表

    /// 节点列表（小火箭风格）
    private var nodeList: some View {
        List {
            if nodes.isEmpty {
                Text("该分组暂无节点")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color(.systemGroupedBackground))
            } else {
                ForEach(nodes) { node in
                    nodeRow(node)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(vpnManagerObservable.currentNode?.id == node.id ? Color.blue.opacity(0.05) : Color(.systemBackground))
                }
                .onDelete { indexSet in
                    let nodesToDelete = indexSet.map { nodes[$0] }
                    VPNManager.shared.removeNodes(nodesToDelete)
                    vpnManagerObservable.refresh()
                }
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
    }

    /// 单个节点行（小火箭风格）
    private func nodeRow(_ node: VPNNode) -> some View {
        Button(action: {
            selectNode(node)
        }) {
            HStack(spacing: 12) {
                // 协议图标（圆形背景 + 协议缩写）
                ZStack {
                    Circle()
                        .fill(protocolColor(node.protocolType).opacity(0.15))
                        .frame(width: 36, height: 36)
                    // 这是一个什么东西：协议图标圆形背景大小
                    // 控制哪里：节点行左侧协议图标的背景大小
                    // 单位是什么：pt（点）
                    // 改大有什么效果：图标背景变大
                    // 改小有什么效果：图标背景变小
                    // 还能怎么改：可以改成圆角矩形

                    Text(node.protocolType.displayName.prefix(2))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(protocolColor(node.protocolType))
                }

                // 节点信息
                VStack(alignment: .leading, spacing: 3) {
                    // 节点名称
                    HStack(spacing: 6) {
                        Text(node.remark)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        // 当前选中标记
                        if vpnManagerObservable.currentNode?.id == node.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                        }
                    }

                    // 协议/传输方式
                    Text("\(node.protocolType.displayName) / \(node.transportType.displayName.uppercased())")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // 延迟
                if let latency = node.latency {
                    Text("\(latency)ms")
                        .font(.subheadline)
                        .foregroundColor(latencyColor(latency))
                } else {
                    Image(systemName: "gauge")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 4)
            // 这是一个什么东西：节点行垂直内边距
            // 控制哪里：每个节点行内容上下的间距
            // 单位是什么：pt（点）
            // 改大有什么效果：行变高，更宽松
            // 改小有什么效果：行变矮，更紧凑
            // 还能怎么改：可以根据内容动态调整
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: {
                selectNode(node)
            }) {
                Label("使用此节点", systemImage: "checkmark.circle")
            }

            Button(action: {
                testNodeLatency(node)
            }) {
                Label("测速", systemImage: "gauge")
            }

            Button(role: .destructive, action: {
                nodeToDelete = node
            }) {
                Label("删除节点", systemImage: "trash")
            }
        }
    }

    // MARK: - 方法

    /// 选择节点
    private func selectNode(_ node: VPNNode) {
        VPNManager.shared.selectNode(node)
        vpnManagerObservable.refresh()
        displayAlert(message: "已选择节点：\(node.remark)")
    }

    /// 测试节点延迟
    private func testNodeLatency(_ node: VPNNode) {
        displayAlert(message: "正在测速：\(node.remark)...")

        VPNManager.shared.testNodeLatency(node) { result in
            DispatchQueue.main.async {
                self.vpnManagerObservable.refresh()
                switch result {
                case .success(let latency):
                    self.displayAlert(message: "测速完成：\(node.remark) 延迟 \(latency)ms")
                case .failure(let error):
                    self.displayAlert(message: "测速失败：\(error.localizedDescription)")
                }
            }
        }
    }

    /// 显示提示
    private func displayAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

    /// 获取协议对应的颜色
    private func protocolColor(_ type: VPNProtocolType) -> Color {
        switch type {
        case .vmess: return .blue
        case .vless: return .purple
        case .trojan: return .green
        case .shadowsocks: return .orange
        case .hysteria: return .pink
        case .tuic: return .teal
        }
    }

    /// 获取延迟对应的颜色
    private func latencyColor(_ latency: Int) -> Color {
        if latency < 100 { return .green }
        if latency < 300 { return .yellow }
        return .red
    }
}

// MARK: - VPN 管理器可观察对象

/// VPN 管理器可观察对象（用于 SwiftUI 响应式更新）
final class VPNManagerObservable: ObservableObject {

    /// 节点列表
    @Published var nodes: [VPNNode] = []

    /// 当前选中的节点
    @Published var currentNode: VPNNode?

    /// 连接状态
    @Published var connectionStatus: VPNConnectionStatus = .disconnected

    /// 初始化
    init() {
        refresh()

        // 监听 VPN 状态变化
        VPNManager.shared.onStatusChange = { [weak self] status in
            self?.connectionStatus = status
        }
    }

    /// 刷新数据
    func refresh() {
        nodes = VPNManager.shared.nodes
        currentNode = VPNManager.shared.currentNode
        connectionStatus = VPNManager.shared.connectionStatus
    }
}

// MARK: - 预览

struct VPNMainView_Previews: PreviewProvider {
    static var previews: some View {
        VPNMainView()
    }
}
