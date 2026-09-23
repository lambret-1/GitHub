import SwiftUI

// ==============================================================================
// BranchBarView 分支栏组件
// 功能：复刻GitHub网页仓库页分支栏布局，左侧分支选择器 + 标签选择器，右侧代码下拉菜单
// 位置：仓库头部下方，文件列表上方
// ==============================================================================

struct BranchBarView<MenuContent: View>: View {
    @Binding var branches: [Branch]
    @Binding var selectedBranch: String
    let onBranchChange: () -> Void
    let menuContent: () -> MenuContent
    let owner: String
    let repo: String
    let onBranchesChanged: () -> Void // 分支变更后回调（刷新分支列表）

    // 标签相关
    let tags: [GitTag]
    let onTagSelected: (String) -> Void

    @EnvironmentObject var appState: AppState
    @State private var showBranchPicker: Bool = false
    @State private var showTagListView: Bool = false

    init(
        branches: Binding<[Branch]>,
        selectedBranch: Binding<String>,
        onBranchChange: @escaping () -> Void,
        owner: String,
        repo: String,
        onBranchesChanged: @escaping () -> Void,
        tags: [GitTag] = [],
        onTagSelected: @escaping (String) -> Void = { _ in },
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self._branches = branches
        self._selectedBranch = selectedBranch
        self.onBranchChange = onBranchChange
        self.owner = owner
        self.repo = repo
        self.onBranchesChanged = onBranchesChanged
        self.tags = tags
        self.onTagSelected = onTagSelected
        self.menuContent = menuContent
    }

    /// 当前是否处于标签视图（selectedBranch 匹配某个标签名）
    private var 当前是标签视图: Bool {
        tags.contains { $0.name == selectedBranch }
    }

    /// 当前选中的标签名（如果是标签视图）
    private var 当前标签名: String? {
        当前是标签视图 ? selectedBranch : nil
    }

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
                        .lineLimit(1)
                        .frame(maxWidth: 120)
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
            .buttonStyle(PlainButtonStyle())

            // 标签选择按钮
            Button(action: {
                showTagListView = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 12))
                        .foregroundColor(当前是标签视图 ? .white : .blue)
                    Text(当前标签名 ?? "Tags")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(当前是标签视图 ? .white : .blue)
                        .lineLimit(1)
                        .frame(maxWidth: 100)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(当前是标签视图 ? .white : .blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(当前是标签视图 ? Color.blue.opacity(0.85) : Color.blue.opacity(0.08))
                .cornerRadius(6)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.leading, 8)

            Spacer()

            // 右侧：代码操作下拉按钮（绿色）
            Menu {
                menuContent()
            } label: {
                HStack(spacing: 6) {
                    Text("代码操作")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color(red: 0.13, green: 0.55, blue: 0.27))
                .cornerRadius(6)
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.98, green: 0.98, blue: 0.98))
        .sheet(isPresented: $showBranchPicker) {
            BranchPickerView(
                branches: $branches,
                selectedBranch: $selectedBranch,
                onSelect: {
                    showBranchPicker = false
                    onBranchChange()
                },
                owner: owner,
                repo: repo,
                onBranchesChanged: onBranchesChanged
            )
            .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showTagListView) {
            TagListView(
                owner: owner,
                repo: repo,
                当前选中Ref: $selectedBranch,
                onTagSelected: { tagName in
                    onTagSelected(tagName)
                }
            )
            .environmentObject(appState)
        }
    }
}
