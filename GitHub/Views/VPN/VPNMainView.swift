//
//  VPNMainView.swift
//  GitHub
//
//  用途：VPN 主页面，显示节点列表和连接控制
//  功能：
//    1. 显示 VPN 连接状态和控制按钮
//    2. 显示节点列表（支持选择、删除、编辑）
//    3. 添加节点（手动添加、剪贴板导入）
//    4. 节点测速（第一期占位，后续实现）
//

import SwiftUI

// MARK: - VPN 主页面

/// VPN 主页面
struct VPNMainView: View {

    // MARK: - 状态属性

    /// VPN 管理器
    @ObservedObject private var vpnManagerObservable = VPNManagerObservable()

    /// 页面关闭控制器（用于独立全屏页面返回）
    @Environment(\.dismiss) private var dismiss

    /// 是否显示添加节点页面
    @State private var showAddNodeView = false

    /// 是否显示订阅管理页面
    @State private var showSubscriptionView = false

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

    /// 展开的分组名称集合（用于分组折叠/展开）
    @State private var expandedGroups: Set<String> = []

    /// 本地节点分组名称常量
    private let localGroupName = "本地节点"

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 连接状态卡片
                connectionStatusCard
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // 节点列表
                nodeList
            }
            .navigationTitle("VPN 代理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .onChange(of: showAddNodeView) { newValue in
                // 添加节点页面关闭后刷新节点列表
                if !newValue {
                    vpnManagerObservable.refresh()
                }
            }
            .onAppear {
                // 页面出现时刷新节点列表和连接状态
                vpnManagerObservable.refresh()
                // 默认展开所有分组，让用户一进来就能看到所有节点
                if expandedGroups.isEmpty {
                    expandedGroups = Set(sortedGroupNames)
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

    // MARK: - 连接状态卡片

    /// 连接状态卡片
    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            // 状态图标和文字
            HStack(spacing: 12) {
                // 状态图标
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.2))
                        .frame(width: 48, height: 48)
                    // 这是一个什么东西：状态图标圆形背景
                    // 控制哪里：连接状态卡片左侧的圆形图标背景
                    // 单位是什么：pt（点）
                    // 改大有什么效果：图标背景变大，更醒目
                    // 改小有什么效果：图标背景变小，更紧凑
                    // 还能怎么改：可以改成圆角矩形、或者添加渐变效果

                    Image(systemName: statusIconName)
                        .font(.system(size: 24))
                        // 这是一个什么东西：状态图标字体大小
                        // 控制哪里：连接状态图标的大小
                        // 单位是什么：pt（点）
                        // 改大有什么效果：图标变大，更醒目
                        // 改小有什么效果：图标变小，更精致
                        // 还能怎么改：可以根据状态动态改变大小，连接时添加动画
                        .foregroundColor(statusColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if let node = vpnManagerObservable.currentNode {
                        Text(node.remark)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("未选择节点")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }

            // 连接/断开按钮
            Button(action: {
                toggleConnection()
            }) {
                HStack {
                    Image(systemName: vpnManagerObservable.connectionStatus.isActive ? "pause.circle.fill" : "play.circle.fill")
                    Text(vpnManagerObservable.connectionStatus.isActive ? "断开连接" : "连接 VPN")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                // 这是一个什么东西：连接按钮垂直内边距
                // 控制哪里：连接按钮的高度
                // 单位是什么：pt（点）
                // 改大有什么效果：按钮变高，点击区域更大
                // 改小有什么效果：按钮变矮，更紧凑
                // 还能怎么改：可以根据屏幕动态调整，或者使用固定高度
                .background(statusColor)
                .cornerRadius(10)
                // 这是一个什么东西：连接按钮圆角半径
                // 控制哪里：连接按钮四个角的圆润程度
                // 单位是什么：pt（点）
                // 改大有什么效果：按钮角更圆，更柔和
                // 改小有什么效果：按钮角更尖，更硬朗
                // 还能怎么改：可以改成完全圆形（高度的一半），或者直角
            }
            .disabled(vpnManagerObservable.currentNode == nil)
            .opacity(vpnManagerObservable.currentNode == nil ? 0.5 : 1.0)
        }
        .padding(16)
        // 这是一个什么东西：状态卡片内边距
        // 控制哪里：连接状态卡片内容与卡片边缘的距离
        // 单位是什么：pt（点）
        // 改大有什么效果：卡片内容更宽松
        // 改小有什么效果：卡片内容更紧凑
        // 还能怎么改：可以分别设置上下左右不同的内边距
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        // 这是一个什么东西：状态卡片圆角半径
        // 控制哪里：连接状态卡片四个角的圆润程度
        // 单位是什么：pt（点）
        // 改大有什么效果：卡片角更圆
        // 改小有什么效果：卡片角更尖
        // 还能怎么改：可以使用不同的圆角风格
    }

    // MARK: - 节点列表

    // MARK: - 分组计算属性

    /// 节点分组字典（分组名称 -> 节点列表）
    /// 本地节点（group为nil或空）放在"本地节点"分组，订阅节点按订阅名称分组
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
        // 本地节点排在最前面
        return names.sorted { first, second in
            if first == localGroupName { return true }
            if second == localGroupName { return false }
            return first < second
        }
    }

    // MARK: - 节点列表

    /// 节点列表（分组折叠展示）
    private var nodeList: some View {
        List {
            if vpnManagerObservable.nodes.isEmpty {
                // 空状态
                emptyStateView
                    .listRowSeparator(.hidden)
            } else {
                // 按分组展示节点
                ForEach(sortedGroupNames, id: \.self) { groupName in
                    groupSection(groupName: groupName, nodes: groupedNodes[groupName] ?? [])
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
        .overlay(alignment: .bottom) {
            // 编辑模式下的底部操作栏
            if editMode == .active && !selectedNodes.isEmpty {
                editModeBottomBar
                    .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - 分组区域

    /// 单个分组区域（可折叠/展开）
    private func groupSection(groupName: String, nodes: [VPNNode]) -> some View {
        let isExpanded = expandedGroups.contains(groupName)

        return Section {
            if isExpanded {
                // 展开状态：显示该分组下的所有节点
                ForEach(nodes) { node in
                    nodeRow(node)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        // 这是一个什么东西：节点行内边距
                        // 控制哪里：每个节点行内容与列表边缘的距离
                        // 单位是什么：pt（点）
                        // 改大有什么效果：行内容更宽松
                        // 改小有什么效果：行内容更紧凑
                        // 还能怎么改：可以分别设置上下左右不同的内边距
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if editMode == .inactive {
                                selectNode(node)
                            } else {
                                toggleSelection(node)
                            }
                        }
                        .contextMenu {
                            Button(action: {
                                selectNode(node)
                            }) {
                                Label("使用此节点", systemImage: "checkmark.circle")
                            }

                            Button(action: {
                                displayAlert(message: "编辑节点功能（后续实现）")
                            }) {
                                Label("编辑节点", systemImage: "pencil")
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
                    // 批量删除（仅删除当前分组内的节点）
                    let nodesToDelete = indexSet.map { nodes[$0] }
                    VPNManager.shared.removeNodes(nodesToDelete)
                    vpnManagerObservable.refresh()
                }
            }
        } header: {
            // 分组标题（点击折叠/展开）
            Button(action: {
                toggleGroup(groupName)
            }) {
                HStack(spacing: 8) {
                    // 折叠/展开箭头图标
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

                    // 分组图标（本地节点用文件夹，订阅用天线图标）
                    Image(systemName: groupName == localGroupName ? "folder.fill" : "dot.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundColor(groupName == localGroupName ? .orange : .blue)

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
                }
                .padding(.vertical, 6)
                // 这是一个什么东西：分组标题垂直内边距
                // 控制哪里：分组标题栏的高度
                // 单位是什么：pt（点）
                // 改大有什么效果：标题栏变高，点击区域更大
                // 改小有什么效果：标题栏变矮，更紧凑
                // 还能怎么改：可以使用固定高度
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    /// 切换分组展开/折叠状态
    private func toggleGroup(_ groupName: String) {
        if expandedGroups.contains(groupName) {
            expandedGroups.remove(groupName)
        } else {
            expandedGroups.insert(groupName)
        }
    }

    // MARK: - 节点行

    /// 单个节点行
    private func nodeRow(_ node: VPNNode) -> some View {
        HStack(spacing: 12) {
            // 编辑模式下的选择框
            if editMode == .active {
                Image(systemName: selectedNodes.contains(node.id) ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedNodes.contains(node.id) ? .blue : .gray)
                    .font(.system(size: 20))
            }

            // 协议图标
            ZStack {
                Circle()
                    .fill(protocolColor(node.protocolType).opacity(0.15))
                    .frame(width: 40, height: 40)
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
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(node.remark)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    // 当前选中标记
                    if vpnManagerObservable.currentNode?.id == node.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                    }
                }

                HStack(spacing: 8) {
                    Text(node.displayAddress)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(node.latencyText)
                        .font(.caption)
                        .foregroundColor(latencyColor(node))
                }
            }

            Spacer()

            // 右侧指示
            if editMode == .inactive {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
        }
        .padding(.vertical, 8)
        // 这是一个什么东西：节点行垂直内边距
        // 控制哪里：每个节点行内容上下的间距
        // 单位是什么：pt（点）
        // 改大有什么效果：行变高，更宽松
        // 改小有什么效果：行变矮，更紧凑
        // 还能怎么改：可以根据内容动态调整
        .background(vpnManagerObservable.currentNode?.id == node.id ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }

    // MARK: - 空状态视图

    /// 空状态视图（没有节点时显示）
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding(.top, 60)
            // 这是一个什么东西：空状态图标顶部间距
            // 控制哪里：空状态图标与上方的距离
            // 单位是什么：pt（点）
            // 改大有什么效果：图标更靠下
            // 改小有什么效果：图标更靠上
            // 还能怎么改：可以使用居中布局

            Text("还没有添加节点")
                .font(.headline)
                .foregroundColor(.primary)

            Text("点击右上角 + 号添加节点，或从剪贴板导入 VMess/VLESS 链接")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            // 这是一个什么东西：空状态描述文字水平内边距
            // 控制哪里：描述文字左右的边距
            // 单位是什么：pt（点）
            // 改大有什么效果：文字更窄，换行更多
            // 改小有什么效果：文字更宽，换行更少
            // 还能怎么改：可以根据屏幕宽度动态调整

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

    // MARK: - 编辑模式底部操作栏

    /// 编辑模式底部操作栏
    private var editModeBottomBar: some View {
        HStack {
            Button(action: {
                selectedNodes.removeAll()
            }) {
                Text("全不选")
                    .foregroundColor(.blue)
            }

            Spacer()

            Text("已选 \(selectedNodes.count) 个")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Button(role: .destructive, action: {
                deleteSelectedNodes()
            }) {
                Text("删除")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: -2)
    }

    // MARK: - 计算属性

    /// 状态颜色
    private var statusColor: Color {
        switch vpnManagerObservable.connectionStatus {
        case .connected:
            return .green
        case .connecting, .reasserting:
            return .orange
        case .disconnecting:
            return .yellow
        default:
            return .gray
        }
    }

    /// 状态图标名称
    private var statusIconName: String {
        switch vpnManagerObservable.connectionStatus {
        case .connected:
            return "lock.fill"
        case .connecting, .reasserting:
            return "link"
        case .disconnecting:
            return "link.badge.plus"
        default:
            return "globe"
        }
    }

    /// 状态文字
    private var statusText: String {
        vpnManagerObservable.connectionStatus.displayText
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

    /// 选择节点
    private func selectNode(_ node: VPNNode) {
        VPNManager.shared.selectNode(node)
        vpnManagerObservable.refresh()
        displayAlert(message: "已选择节点：\(node.remark)")
    }

    /// 测试节点延迟
    /// - Parameter node: 要测试的节点
    private func testNodeLatency(_ node: VPNNode) {
        displayAlert(message: "正在测速：\(node.remark)...")

        VPNManager.shared.testNodeLatency(node) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let latency):
                    self.vpnManagerObservable.refresh()
                    self.displayAlert(message: "测速完成：\(node.remark) 延迟 \(latency)ms")
                case .failure(let error):
                    self.displayAlert(message: "测速失败：\(error.localizedDescription)")
                }
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

    /// 切换节点选中状态
    private func toggleSelection(_ node: VPNNode) {
        if selectedNodes.contains(node.id) {
            selectedNodes.remove(node.id)
        } else {
            selectedNodes.insert(node.id)
        }
    }

    /// 删除选中的节点
    private func deleteSelectedNodes() {
        let nodesToDelete = vpnManagerObservable.nodes.filter { selectedNodes.contains($0.id) }
        VPNManager.shared.removeNodes(nodesToDelete)
        vpnManagerObservable.refresh()
        selectedNodes.removeAll()
        displayAlert(message: "已删除 \(nodesToDelete.count) 个节点")
    }

    /// 显示提示
    private func displayAlert(message: String) {
        alertMessage = message
        showAlert = true
    }

    // MARK: - 辅助方法

    /// 获取协议对应的颜色
    private func protocolColor(_ type: VPNProtocolType) -> Color {
        switch type {
        case .vmess:
            return .blue
        case .vless:
            return .purple
        case .trojan:
            return .green
        case .shadowsocks:
            return .orange
        case .hysteria:
            return .pink
        case .tuic:
            return .teal
        }
    }

    /// 获取延迟对应的颜色
    private func latencyColor(_ node: VPNNode) -> Color {
        guard let latency = node.latency else { return .gray }
        if latency < 100 { return .green }
        if latency < 300 { return .yellow }
        return .red
    }
}

// MARK: - VPN 管理器可观察对象

/// VPN 管理器可观察对象（用于 SwiftUI 响应式更新）
/// 因为 VPNManager 是 NSObject 子类，不能直接用 @Observable，所以用这个包装类
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
