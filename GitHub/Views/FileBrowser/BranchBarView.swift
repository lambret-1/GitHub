import SwiftUI

// ==============================================================================
// BranchBarView 分支栏组件
// 功能：复刻GitHub网页仓库页分支栏布局，左侧分支选择器，右侧代码下拉菜单
// 位置：仓库头部下方，文件列表上方
// ==============================================================================

struct BranchBarView: View {
    let branches: [Branch]
    @Binding var selectedBranch: String
    let onBranchChange: () -> Void
    let onDownloadZip: () -> Void

    @EnvironmentObject var appState: AppState
    @State private var showBranchPicker: Bool = false
    @State private var showCodeMenu: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：分支选择按钮
            Button(action: {
                showBranchPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14))
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Text(selectedBranch.isEmpty ? "main" : selectedBranch)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(appState.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.96))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(appState.isDarkMode ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                )
            }

            Spacer()

            // 右侧：代码下拉按钮（绿色）
            Button(action: {
                showCodeMenu = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                    Text("代码")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(red: 0.13, green: 0.55, blue: 0.27))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.98, green: 0.98, blue: 0.98))
        .sheet(isPresented: $showBranchPicker) {
            BranchPickerView(
                branches: branches,
                selectedBranch: $selectedBranch,
                onSelect: {
                    showBranchPicker = false
                    onBranchChange()
                }
            )
            .environmentObject(appState)
        }
        .confirmationDialog("代码操作", isPresented: $showCodeMenu, titleVisibility: .visible) {
            Button(action: {
                showCodeMenu = false
                onDownloadZip()
            }) {
                Label("下载 ZIP", systemImage: "square.and.arrow.down")
            }

            Button(action: {
                showCodeMenu = false
                // 复制仓库地址
                UIPasteboard.general.string = "https://github.com/\(branches.isEmpty ? "" : "")"
            }) {
                Label("复制仓库地址", systemImage: "link")
            }

            Button("取消", role: .cancel) {
                showCodeMenu = false
            }
        } message: {
            Text("选择代码操作")
        }
    }
}
