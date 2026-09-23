//
//  TagListView.swift
//  GitHub
//
//  用途：仓库标签列表选择页
//  功能：展示仓库所有 Git 标签，支持搜索、选中切换到该标签版本
//  布局：独立全屏页，顶部搜索框 + 标签列表
//

import SwiftUI

// MARK: - 标签列表页

/// 仓库标签列表选择页（独立全屏页）
struct TagListView: View {

    // MARK: - 属性

    /// 仓库所有者
    let owner: String

    /// 仓库名称
    let repo: String

    /// 当前选中的 ref（分支名或标签名），用于判断哪个标签被选中
    @Binding var 当前选中Ref: String

    /// 选中标签后的回调
    let onTagSelected: (String) -> Void

    /// 下载标签源代码ZIP的回调
    let onDownloadTag: (String) -> Void

    /// 页面关闭控制器
    @Environment(\.dismiss) private var dismiss

    /// 标签列表数据
    @State private var 标签列表: [GitTag] = []

    /// 搜索关键词
    @State private var 搜索关键词: String = ""

    /// 加载状态
    @State private var 加载中: Bool = true

    /// 错误信息
    @State private var 错误信息: String?

    // MARK: - 过滤后的标签列表

    private var 过滤后标签: [GitTag] {
        if 搜索关键词.trimmingCharacters(in: .whitespaces).isEmpty {
            return 标签列表
        }
        return 标签列表.filter { 标签 in
            标签.name.lowercased().contains(搜索关键词.lowercased())
        }
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索框
                搜索框
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                // 内容区
                if 加载中 {
                    加载中视图
                } else if let 错误 = 错误信息 {
                    错误视图(错误详情: 错误)
                } else if 标签列表.isEmpty {
                    空态视图
                } else {
                    标签列表视图
                }
            }
            .navigationTitle("选择标签（共\(标签列表.count)个）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            加载标签列表()
        }
    }

    // MARK: - 搜索框

    private var 搜索框: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("搜索标签...", text: $搜索关键词)
                .textFieldStyle(PlainTextFieldStyle())
            if !搜索关键词.isEmpty {
                Button(action: {
                    搜索关键词 = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    // MARK: - 加载中视图

    private var 加载中视图: some View {
        VStack {
            Spacer()
            ProgressView("加载标签中...")
            Spacer()
        }
    }

    // MARK: - 错误视图

    private func 错误视图(错误详情: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("加载失败")
                .font(.headline)
            Text(错误详情)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                加载中 = true
                self.错误信息 = nil
                加载标签列表()
            }) {
                Text("重试")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    // MARK: - 空态视图

    private var 空态视图: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tag")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("该仓库暂无标签")
                .font(.headline)
                .foregroundColor(.primary)
            Text("标签用于标记发布版本，如 v1.0.0")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - 标签列表视图

    private var 标签列表视图: some View {
        List {
            if 过滤后标签.isEmpty {
                HStack {
                    Spacer()
                    Text("未找到匹配的标签")
                        .foregroundColor(.secondary)
                        .padding()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else {
                ForEach(过滤后标签) { 标签 in
                    HStack(spacing: 12) {
                        // 标签选择按钮（点击整行选中）
                        Button(action: {
                            当前选中Ref = 标签.name
                            onTagSelected(标签.name)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                // 标签图标
                                Image(systemName: "tag.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                // 标签名 + commit 短码
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(标签.name)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Text(标签.短码)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                // 选中标记
                                if 当前选中Ref == 标签.name {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 16))
                                }
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        // 下载按钮（独立按钮，不触发选中）
                        Button(action: {
                            onDownloadTag(标签.name)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - 加载标签列表

    private func 加载标签列表() {
        GitHubAPI.shared.getTags(owner: owner, repo: repo) { 结果 in
            DispatchQueue.main.async {
                加载中 = false
                switch 结果 {
                case .success(let 标签):
                    标签列表 = 标签
                    错误信息 = nil
                case .failure(let 错误):
                    错误信息 = 错误.localizedDescription
                }
            }
        }
    }
}

// MARK: - 预览

struct TagListView_Previews: PreviewProvider {
    static var previews: some View {
        TagListView(
            owner: "owner",
            repo: "repo",
            当前选中Ref: .constant(""),
            onTagSelected: { _ in },
            onDownloadTag: { _ in }
        )
    }
}
