//
//  SubscriptionListView.swift
//  GitHub
//
//  用途：VPN 订阅管理页面，显示订阅列表，支持添加、删除、更新、启用/禁用订阅
//  功能：
//    1. 订阅列表展示（名称、URL、类型、状态、节点数量、最后更新时间）
//    2. 添加订阅（跳转到添加订阅页面）
//    3. 删除订阅（左滑删除或长按菜单）
//    4. 更新订阅（手动拉取最新节点）
//    5. 启用/禁用订阅（开关切换）
//    6. 全部更新（一键更新所有启用的订阅）
//  注意：本页面为独立全屏页面，拥有独立导航栈，不与其他页面共用导航
//

import SwiftUI

// MARK: - 订阅列表页面

/// VPN 订阅管理页面
/// 独立全屏页面，使用 NavigationView 拥有独立导航栈
struct SubscriptionListView: View {

    // MARK: - 状态属性

    /// 订阅管理器可观察对象
    @ObservedObject private var subscriptionObservable = VPNSubscriptionObservable()

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// 是否显示添加订阅页面
    @State private var showAddSubscription = false

    /// 提示消息
    @State private var alertMessage: String?

    /// 是否显示提示
    @State private var showAlert = false

    /// 要删除的订阅（用于确认对话框）
    @State private var subscriptionToDelete: VPNSubscription?

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 订阅列表
                if subscriptionObservable.subscriptions.isEmpty {
                    // 空状态
                    emptyStateView
                } else {
                    subscriptionList
                }
            }
            .navigationTitle("订阅管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角返回按钮
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

                // 右上角添加按钮
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddSubscription = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSubscription) {
                AddSubscriptionView()
            }
            .onChange(of: showAddSubscription) { newValue in
                // 添加订阅页面关闭后刷新
                if !newValue {
                    subscriptionObservable.refresh()
                }
            }
            .alert("提示", isPresented: $showAlert) {
                Button("确定", role: .cancel) { }
            } message: {
                Text(alertMessage ?? "")
            }
            .alert("确认删除", isPresented: .constant(subscriptionToDelete != nil)) {
                Button("取消", role: .cancel) {
                    subscriptionToDelete = nil
                }
                Button("删除", role: .destructive) {
                    if let subscription = subscriptionToDelete {
                        subscriptionObservable.removeSubscription(subscription)
                        showAlert(message: "已删除订阅「\(subscription.name)」")
                    }
                    subscriptionToDelete = nil
                }
            } message: {
                if let subscription = subscriptionToDelete {
                    Text("确定要删除订阅「\(subscription.name)」吗？该订阅的所有节点也会被移除。")
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 订阅列表

    /// 订阅列表
    private var subscriptionList: some View {
        List {
            // 全部更新按钮
            Section {
                Button(action: {
                    updateAllSubscriptions()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                        Text("全部更新")
                            .foregroundColor(.primary)
                        Spacer()
                        if subscriptionObservable.isUpdating {
                            ProgressView()
                        }
                    }
                }
                .disabled(subscriptionObservable.isUpdating)
            }

            // 订阅列表
            ForEach(subscriptionObservable.subscriptions) { subscription in
                subscriptionRow(subscription)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(action: {
                            updateSubscription(subscription)
                        }) {
                            Label("更新订阅", systemImage: "arrow.clockwise")
                        }

                        Button(action: {
                            subscriptionObservable.toggleSubscriptionEnabled(subscription)
                        }) {
                            Label(subscription.isEnabled ? "禁用订阅" : "启用订阅", systemImage: subscription.isEnabled ? "pause.circle" : "play.circle")
                        }

                        Button(role: .destructive, action: {
                            subscriptionToDelete = subscription
                        }) {
                            Label("删除订阅", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                // 左滑删除
                let subscriptionsToDelete = indexSet.map { subscriptionObservable.subscriptions[$0] }
                for subscription in subscriptionsToDelete {
                    subscriptionObservable.removeSubscription(subscription)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - 订阅行

    /// 单个订阅行
    private func subscriptionRow(_ subscription: VPNSubscription) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 第一行：名称 + 启用开关
            HStack {
                // 订阅图标
                ZStack {
                    Circle()
                        .fill(subscription.isEnabled ? Color.blue.opacity(0.15) : Color.gray.opacity(0.15))
                        .frame(width: 36, height: 36)
                    // 这是一个什么东西：订阅图标圆形背景大小
                    // 控制哪里：订阅行左侧图标的背景大小
                    // 单位是什么：pt（点）
                    // 改大有什么效果：图标背景变大，更醒目
                    // 改小有什么效果：图标背景变小，更紧凑
                    // 还能怎么改：可以改成圆角矩形

                    Image(systemName: subscription.isEnabled ? "dot.radiowaves.left.and.right" : "dot.radiowaves.left.and.right.slash")
                        .font(.system(size: 16))
                        .foregroundColor(subscription.isEnabled ? .blue : .gray)
                }

                // 订阅名称和类型
                VStack(alignment: .leading, spacing: 2) {
                    Text(subscription.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(subscription.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 启用开关
                Toggle("", isOn: Binding(
                    get: { subscription.isEnabled },
                    set: { _ in subscriptionObservable.toggleSubscriptionEnabled(subscription) }
                ))
                .labelsHidden()
                .frame(width: 51)
                // 这是一个什么东西：启用开关宽度
                // 控制哪里：订阅行右侧开关的宽度
                // 单位是什么：pt（点）
                // 改大有什么效果：开关变宽，点击区域更大
                // 改小有什么效果：开关变窄，更紧凑
                // 还能怎么改：iOS 系统开关默认宽度51pt，不建议修改
            }

            // 第二行：订阅 URL
            Text(subscription.url)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // 第三行：状态信息
            HStack(spacing: 8) {
                // 节点数量
                Label("\(subscription.nodeCount) 个节点", systemImage: "server.rack")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text("·")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // 最后更新时间
                Label(subscription.lastUpdatedText, systemImage: "clock")
                    .font(.caption2)
                    .foregroundColor(subscription.lastUpdateSuccess ? .secondary : .red)
            }
        }
        .padding(.vertical, 4)
        // 这是一个什么东西：订阅行垂直内边距
        // 控制哪里：每个订阅行内容上下的间距
        // 单位是什么：pt（点）
        // 改大有什么效果：行变高，更宽松
        // 改小有什么效果：行变矮，更紧凑
        // 还能怎么改：可以根据内容动态调整
        .background(subscription.isEnabled ? Color(.systemBackground) : Color(.secondarySystemBackground).opacity(0.5))
        .cornerRadius(10)
        // 这是一个什么东西：订阅行圆角半径
        // 控制哪里：订阅行四个角的圆润程度
        // 单位是什么：pt（点）
        // 改大有什么效果：行角更圆，更柔和
        // 改小有什么效果：行角更尖，更硬朗
        // 还能怎么改：可以改成完全直角
        .opacity(subscription.isEnabled ? 1.0 : 0.6)
    }

    // MARK: - 空状态视图

    /// 空状态视图（没有订阅时显示）
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundColor(.gray)
                .padding(.top, 80)
            // 这是一个什么东西：空状态图标大小
            // 控制哪里：空状态页面图标的大小
            // 单位是什么：pt（点）
            // 改大有什么效果：图标变大，更醒目
            // 改小有什么效果：图标变小，更精致
            // 还能怎么改：可以使用自定义图标或动画

            Text("还没有添加订阅")
                .font(.headline)
                .foregroundColor(.primary)

            Text("点击右上角 + 号添加订阅链接，支持小火箭和圈X格式")
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
                showAddSubscription = true
            }) {
                Text("添加订阅")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 方法

    /// 更新单个订阅
    private func updateSubscription(_ subscription: VPNSubscription) {
        subscriptionObservable.updateSubscription(subscription) { result in
            switch result {
            case .success(let subscription, let nodes):
                showAlert(message: "更新成功，获取到 \(nodes.count) 个节点")
            case .failure(_, let error):
                showAlert(message: "更新失败：\(error.localizedDescription)")
            }
        }
    }

    /// 更新所有订阅
    private func updateAllSubscriptions() {
        subscriptionObservable.updateAllSubscriptions { successCount, failureCount in
            if failureCount == 0 {
                showAlert(message: "全部更新成功，共更新 \(successCount) 个订阅")
            } else {
                showAlert(message: "更新完成：成功 \(successCount) 个，失败 \(failureCount) 个")
            }
        }
    }

    /// 显示提示
    private func showAlert(message: String) {
        alertMessage = message
        showAlert = true
    }
}

// MARK: - 预览

struct SubscriptionListView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionListView()
    }
}
