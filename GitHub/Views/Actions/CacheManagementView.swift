import SwiftUI

// MARK: - Actions缓存管理视图

struct CacheManagementView: View {
    let owner: String
    let repo: String

    @State private var caches: [ActionsCache] = []
    @State private var totalCount: Int = 0
    @State private var isLoading: Bool = true
    @State private var errorMessage: String?
    @State private var currentPage: Int = 1
    @State private var hasMore: Bool = true
    @State private var deletingCacheId: Int?
    @State private var showDeleteAlert: Bool = false
    @State private var cacheToDelete: ActionsCache?
    @State private var showClearAllAlert: Bool = false

    var body: some View {
        Group {
            if isLoading && caches.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("加载缓存列表中...")
                    Spacer()
                }
            } else if let error = errorMessage, caches.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadCaches()
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding()
            } else if caches.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "trash")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("暂无缓存")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    // 统计概览
                    Section {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("缓存总数")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(totalCount) 个")
                                    .font(.headline)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("总大小")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(totalSizeDisplay)
                                    .font(.headline)
                            }
                        }
                        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
                    }

                    // 缓存列表
                    Section("缓存列表") {
                        ForEach(caches) { cache in
                            cacheRow(cache: cache)
                                .onAppear {
                                    if cache.id == caches.last?.id && hasMore && !isLoading {
                                        loadMoreCaches()
                                    }
                                }
                        }

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .ios14HideListRowSeparator()
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .ios14Refreshable {
                    currentPage = 1
                    hasMore = true
                    await loadCachesAsync()
                }
            }
        }
        .navigationTitle("缓存管理")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            Button(action: {
                showClearAllAlert = true
            }) {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red)
            }
            .disabled(caches.isEmpty)
        )
        .alert("删除缓存", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) {
                if let cache = cacheToDelete {
                    deleteCache(cache)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let cache = cacheToDelete {
                Text("确定要删除缓存「\(cache.key)」吗？此操作不可恢复。")
            } else {
                Text("确定要删除此缓存吗？")
            }
        }
        .alert("清除所有缓存", isPresented: $showClearAllAlert) {
            Button("全部删除", role: .destructive) {
                clearAllCaches()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("确定要清除所有 \(totalCount) 个缓存吗？此操作不可恢复，可能会增加下次构建时间。")
        }
        .onAppear {
            if caches.isEmpty {
                loadCaches()
            }
        }
    }

    // MARK: - 缓存行视图

    private func cacheRow(cache: ActionsCache) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .foregroundColor(.blue)
                .frame(width: 24)  // 这是视图宽度尺寸，控制组件水平方向显示宽度，单位是pt；改大组件横向更宽，改小组件横向更窄；还能改成.maxWidth: .infinity占满父视图或用.minWidth设最小宽度

            VStack(alignment: .leading, spacing: 4) {
                Text(cache.key)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Image(systemName: "branch")
                        .font(.system(size: 10))  // 这是字体大小尺寸，控制文字显示的字号大小，单位是pt；改大文字更醒目易读但占空间，改小文字更精致节省空间但可能难读；还能配合.weight设粗体/设字重或用.design设字体风格（等宽/圆角/衬线）
                        .foregroundColor(.secondary)
                    Text(cache.branchName)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text("·")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Text(cache.sizeDisplay)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Text("最后访问: \(cache.lastAccessedDisplay)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            Spacer()

            // 删除按钮
            if deletingCacheId == cache.id {
                ProgressView()
                    .scaleEffect(0.8)  // 这是视图缩放比例，控制组件整体放大或缩小的倍数，单位是倍（相对原始尺寸）；改大组件放大更醒目，改小组件缩小更精致；还能配合.animation做缩放动画或用.anchorPoint设缩放锚点位置
            } else {
                Button(action: {
                    cacheToDelete = cache
                    showDeleteAlert = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 4)  // 这是垂直内边距，控制内容上下两侧与边缘的空白距离，单位是pt；改大上下留白更宽内容更透气，改小上下留白更窄内容更紧凑；还能改成.top/.bottom单独控制某一侧
    }

    // MARK: - 计算属性

    private var totalSizeDisplay: String {
        let totalBytes = caches.reduce(0) { $0 + $1.sizeInBytes }
        if totalBytes < 1024 {
            return "\(totalBytes) B"
        } else if totalBytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(totalBytes) / 1024)
        } else if totalBytes < 1024 * 1024 * 1024 {
            return String(format: "%.1f MB", Double(totalBytes) / (1024 * 1024))
        } else {
            return String(format: "%.1f GB", Double(totalBytes) / (1024 * 1024 * 1024))
        }
    }

    // MARK: - 数据加载

    private func loadCaches() {
        isLoading = true
        errorMessage = nil

        GitHubAPI.shared.getCaches(owner: owner, repo: repo, page: 1) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let data):
                    self.caches = data.caches
                    self.totalCount = data.totalCount
                    self.hasMore = data.caches.count >= 30
                case .failure(let error):
                    self.errorMessage = "加载缓存列表失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadMoreCaches() {
        currentPage += 1

        GitHubAPI.shared.getCaches(owner: owner, repo: repo, page: currentPage) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let data):
                    self.caches.append(contentsOf: data.caches)
                    self.hasMore = data.caches.count >= 30
                case .failure:
                    self.hasMore = false
                }
            }
        }
    }

    private func loadCachesAsync() async {
        await withCheckedContinuation { continuation in
            loadCaches()
            continuation.resume()
        }
    }

    // MARK: - 删除缓存

    private func deleteCache(_ cache: ActionsCache) {
        deletingCacheId = cache.id

        GitHubAPI.shared.deleteCache(owner: owner, repo: repo, cacheId: cache.id) { result in
            DispatchQueue.main.async {
                deletingCacheId = nil
                switch result {
                case .success:
                    caches.removeAll { $0.id == cache.id }
                    totalCount -= 1
                case .failure(let error):
                    errorMessage = "删除缓存失败: \(error.localizedDescription)"
                }
            }
        }
    }

    private func clearAllCaches() {
        // 逐个删除所有缓存
        let cachesToDelete = caches
        for cache in cachesToDelete {
            GitHubAPI.shared.deleteCache(owner: owner, repo: repo, cacheId: cache.id) { _ in }
        }
        // 清空列表并重新加载
        caches.removeAll()
        totalCount = 0
        currentPage = 1
        hasMore = true
        loadCaches()
    }
}
