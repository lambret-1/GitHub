import SwiftUI

// ==============================================================================
// DebugLogView 调试日志查看器
// 功能：在APP内查看DebugLogger记录的日志，支持按标签过滤、清理日志
// 位置：Views/Debug，从"我的"页面进入
// 设计原则：简洁实用，支持复制日志，方便排查问题
// ==============================================================================

struct DebugLogView: View {
    // MARK: - 状态属性

    @State private var logContent: String = ""
    @State private var selectedTag: String = "全部"
    @State private var showClearConfirm: Bool = false

    // MARK: - 计算属性

    private var allTags: [String] {
        ["全部"] + DebugLogger.shared.getAllTags()
    }

    // MARK: - 视图主体

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签选择栏
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(allTags, id: \.self) { tag in
                            Button(action: {
                                selectedTag = tag
                                loadLogs()
                            }) {
                                Text(tag)
                                    .font(.system(size: 13))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTag == tag ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                                    .foregroundColor(selectedTag == tag ? .blue : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // 日志内容区域
                ScrollView {
                    if logContent.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("暂无日志记录")
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 60)
                    } else {
                        Text(logContent)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }

                // 底部操作栏
                HStack(spacing: 12) {
                    Button(action: {
                        loadLogs()
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("刷新")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    }

                    Button(action: {
                        // 复制日志到剪贴板
                        UIPasteboard.general.string = logContent
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("复制")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(8)
                    }

                    Button(action: {
                        showClearConfirm = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清理")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("调试日志")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadLogs()
            }
            .alert("确认清理", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) { }
                Button("清理", role: .destructive) {
                    DebugLogger.shared.clearTodayLogs()
                    loadLogs()
                }
            } message: {
                Text("确定要清理今天的所有调试日志吗？此操作不可恢复。")
            }
        }
    }

    // MARK: - 私有方法

    private func loadLogs() {
        if selectedTag == "全部" {
            logContent = DebugLogger.shared.readTodayLogs()
        } else {
            logContent = DebugLogger.shared.readLogs(withTag: selectedTag)
        }
    }
}
