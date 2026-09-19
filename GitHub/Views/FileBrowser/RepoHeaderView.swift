import SwiftUI

// ==============================================================================
// RepoHeaderView 仓库头部组件
// 功能：复刻GitHub网页仓库页顶部布局，展示仓库信息、Watch/Fork/Star按钮
// 位置：仓库页面最顶部，分支栏上方
// ==============================================================================

struct RepoHeaderView: View {
    let repository: Repository
    let isStarred: Bool
    let isCheckingStar: Bool
    let isStarring: Bool
    let isForking: Bool
    let onToggleStar: () -> Void
    let onFork: () -> Void
    // 星标数量（可选，用于星标状态变化时实时更新）
    var starCount: Int? = nil
    // 新增回调：查看父仓库（Fork来源）
    var onViewParent: ((RepositoryParent) -> Void)? = nil
    // 新增回调：点击所有者头像跳转到其主页仓库
    var onOwnerClick: (() -> Void)? = nil
    // 最新提交信息（用于在操作按钮组下方显示提交记录栏）
    var latestCommit: Commit? = nil
    var isLoadingLatestCommit: Bool = false
    var onShowCommits: (() -> Void)? = nil

    @EnvironmentObject var appState: AppState
    // 描述展开状态
    @State private var isDescriptionExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 第一行：所有者头像 + 用户名（点击头像跳转到所有者主页仓库）
            HStack(spacing: 8) {
                // 所有者头像（点击跳转到其主页仓库）
                Button(action: {
                    onOwnerClick?()
                }) {
                    Group {
                        if let url = URL(string: repository.owner.avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 20))  // 这是字体大小尺寸，控制占位图标显示的大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难辨认；还能配合.imageScale设大小或用.tint改图标颜色
                                    .foregroundColor(.gray)
                            }
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))  // 这是字体大小尺寸，控制占位图标显示的大小，单位是pt；改大图标更醒目易读但占空间，改小图标更精致节省空间但可能难辨认；还能配合.imageScale设大小或用.tint改图标颜色
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 24, height: 24)  // 这是视图宽高尺寸，控制头像显示的宽度和高度，单位是pt（点）；改大头像显示更大更醒目，改小头像显示更小更精致；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())

                Text(repository.ownerName)
                    .font(.system(size: 17))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    .foregroundColor(.blue)

                Spacer()

                // 仓库可见性标签
                if repository.isPrivate {
                    Text("私有")
                        .font(.system(size: 11, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 3)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.isDarkMode ? Color.gray.opacity(0.4) : Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                } else {
                    Text("公开")
                        .font(.system(size: 11, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        .padding(.horizontal, 8)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                        .padding(.vertical, 3)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.isDarkMode ? Color.gray.opacity(0.4) : Color.secondary.opacity(0.4), lineWidth: 1)
                        )
                }
            }

            // Fork来源标识（如果是Fork仓库）
            if repository.是Fork, let parent = repository.parent {
                Button(action: {
                    onViewParent?(parent)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.blue)
                        Text("复刻自 ")
                            .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        Text("\(parent.ownerName)/\(parent.name)")
                            .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }

            // 第二行：仓库描述（可展开/收起）
            if let description = repository.description, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text(description)
                        .font(.system(size: 14))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? Color(red: 0.8, green: 0.8, blue: 0.8) : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(isDescriptionExpanded ? nil : 2)

                    // 展开/收起按钮
                    if description.count > 60 {
                        Button(action: {
                            isDescriptionExpanded.toggle()
                        }) {
                            Text(isDescriptionExpanded ? "收起" : "展开")
                                .font(.system(size: 12, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // 第三行：操作按钮组（Watch / Fork / Star）
            HStack(spacing: 8) {
                // 关注按钮
                Button(action: {
                    // Watch功能暂未实现，显示提示
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        Text("关注")
                            .font(.system(size: 13, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        Text(formatCount(repository.watchersCount ?? 0))
                            .font(.system(size: 13, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                    .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    .background(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())

                // 复刻按钮
                Button(action: {
                    onFork()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        Text("复刻")
                            .font(.system(size: 13, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        Text(formatCount(repository.forksCount ?? 0))
                            .font(.system(size: 13, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                    .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    .background(appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85), lineWidth: 1)
                    )
                }
                .disabled(isForking)
                .buttonStyle(PlainButtonStyle())

                // 标星按钮（带动画效果）
                Button(action: {
                    // 点击时添加缩放动画
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        onToggleStar()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: isStarred ? "star.fill" : "star")
                            .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(isStarred ? .yellow : (appState.isDarkMode ? .white : .primary))
                            // 星标图标缩放动画
                            .scaleEffect(isStarred ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isStarred)
                        Text(isStarred ? "已标星" : "标星")
                            .font(.system(size: 13, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        Text(formatCount(starCount ?? repository.stargazersCount ?? 0))
                            .font(.system(size: 13, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                    }
                    .foregroundColor(appState.isDarkMode ? .white : .primary)
                    .padding(.horizontal, 12)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                    .padding(.vertical, 6)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    .background(
                        // 背景颜色过渡动画
                        isStarred ?
                        Color.yellow.opacity(appState.isDarkMode ? 0.2 : 0.15) :
                        (appState.isDarkMode ? Color(red: 0.15, green: 0.15, blue: 0.15) : Color(red: 0.96, green: 0.96, blue: 0.96))
                    )
                    .animation(.easeInOut(duration: 0.2), value: isStarred)
                    .cornerRadius(6)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                // 边框颜色过渡动画
                                isStarred ? Color.yellow :
                                (appState.isDarkMode ? Color(red: 0.3, green: 0.3, blue: 0.3) : Color(red: 0.85, green: 0.85, blue: 0.85)),
                                lineWidth: 1
                            )
                            .animation(.easeInOut(duration: 0.2), value: isStarred)
                    )
                    // 按钮整体缩放动画
                    .scaleEffect(isStarring ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isStarring)
                }
                .disabled(isStarring || isCheckingStar)
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }

            // 提交信息栏（上移到操作按钮组下方，背景色与RepoHeaderView一致）
            HStack(spacing: 10) {
                if isLoadingLatestCommit {
                    // 加载中状态
                    ProgressView()
                        .scaleEffect(0.8)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
                    Text("加载提交信息...")
                        .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Spacer()
                } else if let commit = latestCommit {
                    // 提交者头像（24pt，生产级尺寸）
                    Group {
                        if let avatarUrl = commit.author?.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 24))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 24, height: 24)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 24, height: 24)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算

                    // 提交者名称 + 提交信息（垂直布局，生产级信息层次）
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(commit.authorName)
                                .font(.system(size: 13, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Text("提交了")
                                .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.secondary)
                        }
                        Text(commit.message)
                            .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .layoutPriority(1)
                    }

                    Spacer(minLength: 12)

                    // 提交时间（生产级次要信息）
                    Text(commit.commit.committer.relativeDate)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .frame(minWidth: 60, alignment: .trailing)

                    // 查看提交历史按钮（生产级点击区域44pt）
                    Button(action: {
                        onShowCommits?()
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("查看提交历史")
                } else {
                    // 无提交信息（空仓库状态，生产级空态设计）
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 18))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.orange)
                    Text("此目录暂无提交记录")
                        .font(.system(size: 13))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
            .padding(.vertical, 5)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
            .frame(minHeight: 22) // 紧凑版最小行高，原44pt降低一半，节省空间
            .contentShape(Rectangle())
            .onTapGesture {
                if latestCommit != nil {
                    onShowCommits?()
                }
            }

            // 第四行：Topics标签（如果有）
            if let topics = repository.topics, !topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(topics, id: \.self) { topic in
                            Text(topic)
                                .font(.system(size: 11, weight: .medium))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                                .foregroundColor(.blue)
                                .padding(.horizontal, 10)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
                                .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)  // 这是圆角半径尺寸，控制视图四个角的圆润弯曲程度，单位是pt；改大圆角更圆润柔和更现代，改小圆角更方正锐利更硬朗；还能改成.clipShape(RoundedRectangle(cornerRadius:))单独控制或用continuous圆角更丝滑
                        }
                    }
                }
            }

            // 第五行：仓库元信息
            HStack(spacing: 16) {
                // 语言
                if let language = repository.language, !language.isEmpty {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(languageColor(language))
                            .frame(width: 12, height: 12)  // 这是视图宽高尺寸，控制组件显示的宽度和高度，单位是pt（点）；改大组件显示更大更占空间，改小组件显示更小更紧凑；还能改成.maxWidth/.infinity自适应或用GeometryReader动态计算
                        Text(language)
                            .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    }
                }

                // 开源协议
                HStack(spacing: 4) {
                    Image(systemName: "scroll")
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    Text(repository.协议名称)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }






                // 仓库大小
                HStack(spacing: 4) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    Text(repository.大小显示)
                        .font(.system(size: 12))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                }

                Spacer()
            }


            // 第六行：创建/更新时间
            HStack(spacing: 16) {
                if let createdAt = repository.createdAt {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        Text("创建于 \(日期工具.相对时间(fromISO: createdAt))")
                            .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    }
                }

                if let updatedAt = repository.updatedAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                        Text("更新于 \(日期工具.相对时间(fromISO: updatedAt))")
                            .font(.system(size: 11))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                            .foregroundColor(appState.isDarkMode ? .gray : .secondary)
                    }
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)  // 这是水平内边距，控制内容左右两侧与边缘的空白距离，单位是pt；改大左右留白更宽内容更居中，改小左右留白更窄内容更靠边；还能改成.leading/.trailing单独控制某一侧
        .padding(.vertical, 14)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
        .background(appState.isDarkMode ? Color(red: 0.08, green: 0.08, blue: 0.08) : Color(red: 0.98, green: 0.98, blue: 0.98))
    }

    // 数字格式化（大数字显示为k/M格式）
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000.0)
        } else if count >= 1000 {
            return String(format: "%.1fk", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }

    // 根据语言名称返回对应颜色（GitHub官方语言颜色）
    private func languageColor(_ language: String) -> Color {
        let colorMap: [String: Color] = [
            "Swift": Color(red: 0.97, green: 0.36, blue: 0.20),
            "Python": Color(red: 0.22, green: 0.45, blue: 0.70),
            "JavaScript": Color(red: 0.72, green: 0.72, blue: 0.22),
            "TypeScript": Color(red: 0.16, green: 0.42, blue: 0.80),
            "Java": Color(red: 0.72, green: 0.22, blue: 0.22),
            "Kotlin": Color(red: 0.56, green: 0.36, blue: 0.80),
            "Go": Color(red: 0.00, green: 0.68, blue: 0.72),
            "Rust": Color(red: 0.68, green: 0.36, blue: 0.20),
            "C++": Color(red: 0.36, green: 0.42, blue: 0.80),
            "C": Color(red: 0.36, green: 0.42, blue: 0.80),
            "Objective-C": Color(red: 0.26, green: 0.42, blue: 0.68),
            "Dart": Color(red: 0.00, green: 0.68, blue: 0.84),
            "HTML": Color(red: 0.80, green: 0.30, blue: 0.20),
            "CSS": Color(red: 0.36, green: 0.42, blue: 0.80),
            "Shell": Color(red: 0.56, green: 0.62, blue: 0.42),
            "Ruby": Color(red: 0.70, green: 0.22, blue: 0.22),
            "PHP": Color(red: 0.36, green: 0.36, blue: 0.60),
            "Vue": Color(red: 0.26, green: 0.68, blue: 0.56),
            "React": Color(red: 0.22, green: 0.68, blue: 0.80)
        ]
        return colorMap[language] ?? Color.gray
    }
}
