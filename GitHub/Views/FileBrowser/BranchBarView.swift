import SwiftUI

// ==============================================================================
// BranchBarView 分支栏组件
// 功能：复刻GitHub网页仓库页分支栏布局，左侧分支选择器，右侧代码下拉菜单
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

    @EnvironmentObject var appState: AppState
    @State private var showBranchPicker: Bool = false
    @State private var showCodeMenu: Bool = false

    init(
        branches: Binding<[Branch]>,
        selectedBranch: Binding<String>,
        onBranchChange: @escaping () -> Void,
        owner: String,
        repo: String,
        onBranchesChanged: @escaping () -> Void,
        @ViewBuilder menuContent: @escaping () -> MenuContent
    ) {
        self._branches = branches
        self._selectedBranch = selectedBranch
        self.onBranchChange = onBranchChange
        self.owner = owner
        self.repo = repo
        self.onBranchesChanged = onBranchesChanged
        self.menuContent = menuContent
    }

    var body: some View {
        HStack(spacing: 0) {
            // 左侧：分支选择按钮
            Button(action: {
                showBranchPicker = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Text(selectedBranch.isEmpty ? "main" : selectedBranch)
                        .font(.system(size: 14, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .white : .primary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }
                .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 7)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(appState.isDarkMode ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(red: 0.96, green: 0.96, blue: 0.96))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(appState.isDarkMode ? Color(red: 0.25, green: 0.25, blue: 0.25) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())

            Spacer()

            // 右侧：代码操作下拉按钮（绿色，修复P0问题：文字改为代码操作，箭头移到右侧）
            Menu {
                menuContent()
            } label: {
                HStack(spacing: 6) {
                    Text("代码操作")
                        .font(.system(size: 14, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.white)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                .padding(.vertical, 7)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                .background(Color(red: 0.13, green: 0.55, blue: 0.27))
                .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
            }
            .menuStyle(BorderlessButtonMenuStyle())
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 10)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
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
    }
}
