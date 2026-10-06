//
//  路由模式选择视图.swift
//  GitHub
//
//  用途：VPN 路由模式选择页面，支持全局代理/绕过局域网/绕过中国大陆/规则模式
//

import SwiftUI

// MARK: - 路由模式选择视图

/// 路由模式选择视图（底部弹出式）
struct 路由模式选择视图: View {

    // MARK: - 属性

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// VPN 管理器可观察对象
    @ObservedObject private var vpnManagerObservable = VPNManagerObservable()

    /// 选中的路由模式（临时，点击确定后才生效）
    @State private var 选中模式: VPN路由模式

    // MARK: - 初始化

    init() {
        _选中模式 = State(initialValue: VPNManager.shared.当前路由模式)
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 模式列表
                List {
                    Section {
                        ForEach(VPN路由模式.allCases) { 模式 in
                            模式行(模式: 模式, 已选中: 选中模式 == 模式) {
                                选中模式 = 模式
                                触觉反馈()
                            }
                        }
                    } header: {
                        Text("选择路由模式")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } footer: {
                        Text("路由模式决定网络流量的走向，修改后下次连接生效")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .listStyle(.insetGrouped)

                // 底部确定按钮
                VStack(spacing: 0) {
                    Divider()
                    Button(action: {
                        确认选择()
                    }) {
                        Text("确定")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("路由模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - 模式行

    private func 模式行(模式: VPN路由模式, 已选中: Bool, 操作: @escaping () -> Void) -> some View {
        Button(action: 操作) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(已选中 ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 36, height: 36)

                    Image(systemName: 模式.图标名)
                        .font(.system(size: 16))
                        .foregroundColor(已选中 ? .blue : .gray)
                }

                // 名称和描述
                VStack(alignment: .leading, spacing: 3) {
                    Text(模式.显示名称)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(模式.描述)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                // 选中标记
                if 已选中 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 20))
                }
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color(.systemBackground))
    }

    // MARK: - 方法

    private func 确认选择() {
        VPNManager.shared.设置路由模式(选中模式)
        vpnManagerObservable.refresh()
        dismiss()
    }

    private func 触觉反馈() {
        let 生成器 = UIImpactFeedbackGenerator(style: .light)
        生成器.impactOccurred()
    }
}

// MARK: - 预览

struct 路由模式选择视图_Previews: PreviewProvider {
    static var previews: some View {
        路由模式选择视图()
    }
}
