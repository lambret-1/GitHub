//
//  CrashLogListView.swift
//  GitHub
//
//  崩溃日志列表页面：显示所有崩溃日志，支持查看详情、删除、导出
//

import SwiftUI

/// 崩溃日志列表页面
struct CrashLogListView: View {
    // MARK: - 状态
    /// 崩溃日志列表
    @State private var crashLogs: [CrashLogFile] = []
    /// 是否显示删除确认对话框
    @State private var showDeleteAllConfirmation = false
    /// 选中的崩溃日志（用于查看详情）
    @State private var selectedCrashLog: CrashLogFile?
    /// 是否显示分享面板
    @State private var showShareSheet = false
    /// 要分享的文件URL
    @State private var shareFileURLs: [URL] = []

    // MARK: - 视图
    var body: some View {
        List {
            if crashLogs.isEmpty {
                // 空状态
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)

                        Text("暂无崩溃日志")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("应用运行稳定，未检测到崩溃")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                // 崩溃日志列表
                ForEach(crashLogs) { crashLog in
                    Button(action: {
                        selectedCrashLog = crashLog
                    }) {
                        HStack(spacing: 12) {
                            // 崩溃图标
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .frame(width: 40, height: 40)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 4) {
                                // 崩溃时间 + 来源标签
                                HStack(spacing: 8) {
                                    Text(crashLog.formattedCreationDate)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    // 崩溃来源标签（主App/VPN扩展）
                                    Text(crashLog.source.显示名称)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(crashLog.source.颜色)
                                        .cornerRadius(4)
                                }

                                // 文件名和大小
                                HStack {
                                    Text(crashLog.fileName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)

                                    Spacer()

                                    Text(crashLog.formattedFileSize)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()

                            // 右箭头
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    // 滑动删除
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteCrashLog(crashLog)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("崩溃日志")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if !crashLogs.isEmpty {
                    Menu {
                        Button(action: {
                            exportAllCrashLogs()
                        }) {
                            Label("导出全部", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive, action: {
                            showDeleteAllConfirmation = true
                        }) {
                            Label("清空全部", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadCrashLogs()
        }
        // 崩溃日志详情弹窗
        .sheet(item: $selectedCrashLog) { crashLog in
            CrashLogDetailView(crashLog: crashLog) {
                loadCrashLogs()
            }
        }
        // 分享面板
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: shareFileURLs)
        }
        // 删除确认对话框
        .alert("确认清空", isPresented: $showDeleteAllConfirmation) {
            Button("取消", role: .cancel) {}
            Button("清空", role: .destructive) {
                deleteAllCrashLogs()
            }
        } message: {
            Text("确定要清空所有崩溃日志吗？此操作不可恢复。")
        }
    }

    // MARK: - 私有方法

    /// 加载崩溃日志列表
    private func loadCrashLogs() {
        crashLogs = CrashLogger.shared.getAllCrashLogs()
    }

    /// 删除单个崩溃日志
    private func deleteCrashLog(_ crashLog: CrashLogFile) {
        CrashLogger.shared.deleteCrashLog(crashLog)
        loadCrashLogs()
    }

    /// 删除所有崩溃日志
    private func deleteAllCrashLogs() {
        CrashLogger.shared.deleteAllCrashLogs()
        loadCrashLogs()
    }

    /// 导出所有崩溃日志
    private func exportAllCrashLogs() {
        shareFileURLs = CrashLogger.shared.exportCrashLogs(crashLogs)
        showShareSheet = true
    }
}

// MARK: - 崩溃日志详情页面
/// 崩溃日志详情页面
struct CrashLogDetailView: View {
    // MARK: - 属性
    /// 崩溃日志文件
    let crashLog: CrashLogFile
    /// 刷新回调
    let onDelete: () -> Void

    // MARK: - 状态
    /// 崩溃日志内容
    @State private var logContent: String = ""
    /// 是否显示分享面板
    @State private var showShareSheet = false
    /// 环境对象
    @Environment(\.dismiss) private var dismiss

    // MARK: - 视图
    var body: some View {
        NavigationView {
            ScrollView {
                if logContent.isEmpty {
                    // 加载中
                    ProgressView("加载中...")
                        .padding(.vertical, 40)
                } else {
                    // 崩溃日志内容
                    Text(logContent)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
            }
            .navigationTitle("崩溃详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            shareCrashLog()
                        }) {
                            Label("导出", systemImage: "square.and.arrow.up")
                        }

                        Button(action: {
                            copyCrashLog()
                        }) {
                            Label("复制", systemImage: "doc.on.doc")
                        }

                        Button(role: .destructive, action: {
                            deleteCrashLog()
                        }) {
                            Label("删除", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadLogContent()
            }
            // 分享面板
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(activityItems: [crashLog.fileURL])
            }
        }
    }

    // MARK: - 私有方法

    /// 加载崩溃日志内容
    private func loadLogContent() {
        logContent = CrashLogger.shared.readCrashLog(crashLog) ?? "无法读取崩溃日志内容"
    }

    /// 分享崩溃日志
    private func shareCrashLog() {
        showShareSheet = true
    }

    /// 复制崩溃日志
    private func copyCrashLog() {
        UIPasteboard.general.string = logContent
    }

    /// 删除崩溃日志
    private func deleteCrashLog() {
        CrashLogger.shared.deleteCrashLog(crashLog)
        onDelete()
        dismiss()
    }
}
