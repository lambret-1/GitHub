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

    /// 是否显示添加节点页面
    @State private var showAddNodeView = false

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
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddNodeView = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddNodeView) {
                AddNodeView()
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

    // MARK: - 连接状态卡片

    /// 连接状态卡片
    private var connectionStatusCard: some View {
        VStack(spacing: 12) {
            // 状态图标和文字
            HStack(spacing: 12) {
                // 状态图标（地球）
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("\(vpnManagerObservable.nodes.count)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // 连接/断开按钮
            Button(action: {
                toggleConnection()
            }) {
                HStack {
                    Image(systemName: vpnManagerObservable.connectionStatus.isActive ? "pause.fill" : "play.fill")
                    Text(vpnManagerObservable.connectionStatus.isActive ? "断开连接" : "连接 VPN")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.darkGray))
                .cornerRadius(10)
            }
            .disabled(vpnManagerObservable.currentNode == nil)
            .opacity(vpnManagerObservable.currentNode == nil ? 0.5 : 1.0)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - 节点列表

    /// 节点列表
    private var nodeList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if vpnManagerObservable.nodes.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    ForEach(vpnManagerObservable.nodes) { node in
                        nodeRow(node)
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
                                    showAlert(message: "编辑节点功能（后续实现）")
                                }) {
                                    Label("编辑节点", systemImage: "pencil")
                                }

                                Button(action: {
                                    showAlert(message: "节点测速功能（后续实现）")
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .overlay(alignment: .bottom) {
            // 编辑模式下的底部操作栏
            if editMode == .active && !selectedNodes.isEmpty {
                editModeBottomBar
                    .transition(.move(edge: .bottom))
            }
        }
    }

    // MARK: - 节点行

    /// 单个节点行（卡片样式）
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
        .padding(12)
        .background(vpnManagerObservable.currentNode?.id == node.id ? Color.blue.opacity(0.08) : Color(.systemBackground))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 0.5)
        )
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
                showAlert(message: "连接失败: \(error.localizedDescription)")
            }
        }
    }

    /// 选择节点
    private func selectNode(_ node: VPNNode) {
        VPNManager.shared.selectNode(node)
        vpnManagerObservable.refresh()
        showAlert(message: "已选择节点：\(node.remark)")
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
                showAlert(message: "成功导入 \(nodes.count) 个节点")

            case .failure(let error):
                showAlert(message: "导入失败: \(error.localizedDescription)")
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
        showAlert(message: "已删除 \(nodesToDelete.count) 个节点")
    }

    /// 显示提示
    private func showAlert(message: String) {
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
