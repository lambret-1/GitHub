import Foundation
import SwiftUI
import UIKit

// ==============================================================================
// DraftManager 草稿管理器
// 功能：自动保存编辑中的文件草稿，意外退出后可恢复
// 位置：文件编辑器的草稿持久化层
// 设计原则：定时保存+编辑暂停保存，内存警告时强制保存，提交成功后清除
// ==============================================================================

class DraftManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = DraftManager()

    private init() {
        // 监听内存警告
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        // 监听应用进入后台
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timer?.invalidate()
    }

    // MARK: - 草稿数据模型

    struct Draft: Codable, Identifiable {
        let id: String
        let filePath: String
        let branch: String
        var content: String
        var lastModified: Date
        let fileSha: String?

        enum CodingKeys: String, CodingKey {
            case id, filePath, branch, content, lastModified, fileSha
        }
    }

    // MARK: - 私有属性

    /// 草稿存储目录
    private let draftsDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let draftsDir = paths[0].appendingPathComponent("EditorDrafts", isDirectory: true)
        if !FileManager.default.fileExists(atPath: draftsDir.path) {
            try? FileManager.default.createDirectory(at: draftsDir, withIntermediateDirectories: true)
        }
        return draftsDir
    }()

    /// 自动保存定时器
    private var timer: Timer?

    /// 当前编辑的草稿
    private var currentDraft: Draft?

    /// 编辑暂停计时器（编辑停止2秒后自动保存）
    private var editPauseTimer: Timer?

    // MARK: - 发布属性

    /// 是否有未保存的草稿
    @Published private(set) var hasUnsavedDraft: Bool = false

    /// 最后保存时间
    @Published private(set) var lastSavedTime: Date?

    /// 所有草稿列表
    @Published private(set) var allDrafts: [Draft] = []

    // MARK: - 配置常量

    /// 自动保存间隔（秒）
    private let autoSaveInterval: TimeInterval = 5.0

    /// 编辑暂停后保存延迟（秒）
    private let editPauseSaveDelay: TimeInterval = 2.0

    /// 草稿最大保留数量
    private let maxDraftsCount: Int = 50

    // MARK: - 公开方法

    /// 开始编辑一个文件（初始化草稿）
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    ///   - content: 当前文件内容
    ///   - fileSha: 文件SHA（用于提交时验证）
    func startEditing(filePath: String, branch: String, content: String, fileSha: String?) {
        // 检查是否有已存在的草稿
        if let existingDraft = loadDraft(for: filePath, branch: branch) {
            currentDraft = existingDraft
            hasUnsavedDraft = true
        } else {
            // 创建新草稿
            currentDraft = Draft(
                id: UUID().uuidString,
                filePath: filePath,
                branch: branch,
                content: content,
                lastModified: Date(),
                fileSha: fileSha
            )
            hasUnsavedDraft = false
        }

        // 启动自动保存定时器
        startAutoSaveTimer()

        // 加载所有草稿列表
        loadAllDrafts()
    }

    /// 更新草稿内容（编辑时调用）
    /// - Parameter content: 新内容
    func updateDraftContent(_ content: String) {
        guard var draft = currentDraft else { return }

        // 内容未变化则不更新
        guard draft.content != content else { return }

        draft.content = content
        draft.lastModified = Date()
        currentDraft = draft
        hasUnsavedDraft = true

        // 重置编辑暂停计时器
        resetEditPauseTimer()
    }

    /// 获取当前草稿内容
    /// - Returns: 草稿内容
    func getCurrentDraftContent() -> String? {
        return currentDraft?.content
    }

    /// 检查指定文件是否有草稿
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    /// - Returns: 是否有草稿
    func hasDraft(for filePath: String, branch: String) -> Bool {
        return loadDraft(for: filePath, branch: branch) != nil
    }

    /// 获取指定文件的草稿
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    /// - Returns: 草稿
    func getDraft(for filePath: String, branch: String) -> Draft? {
        return loadDraft(for: filePath, branch: branch)
    }

    /// 手动保存草稿
    func saveDraft() {
        guard let draft = currentDraft else { return }
        saveDraftToDisk(draft)
        hasUnsavedDraft = false
        lastSavedTime = Date()
    }

    /// 提交成功后清除草稿
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    func clearDraft(for filePath: String, branch: String) {
        deleteDraft(for: filePath, branch: branch)
        if currentDraft?.filePath == filePath && currentDraft?.branch == branch {
            currentDraft = nil
            hasUnsavedDraft = false
        }
        loadAllDrafts()
    }

    /// 结束编辑（停止定时器，保存草稿）
    func endEditing() {
        // 停止定时器
        timer?.invalidate()
        timer = nil
        editPauseTimer?.invalidate()
        editPauseTimer = nil

        // 保存草稿
        if hasUnsavedDraft {
            saveDraft()
        }

        currentDraft = nil
    }

    /// 恢复草稿（返回草稿内容，用于提示用户恢复）
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    /// - Returns: 草稿内容
    func restoreDraft(for filePath: String, branch: String) -> String? {
        guard let draft = loadDraft(for: filePath, branch: branch) else { return nil }
        currentDraft = draft
        hasUnsavedDraft = true
        return draft.content
    }

    /// 删除所有草稿（清理缓存时调用）
    func clearAllDrafts() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: draftsDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try? FileManager.default.removeItem(at: file)
            }
            currentDraft = nil
            hasUnsavedDraft = false
            allDrafts = []
        } catch {
            print("清除草稿失败: \(error)")
        }
    }

    /// 获取草稿存储大小
    /// - Returns: 大小（字节）
    func getDraftsSize() -> Int64 {
        var totalSize: Int64 = 0
        do {
            let files = try FileManager.default.contentsOfDirectory(at: draftsDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for file in files {
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
        } catch {
            print("获取草稿大小失败: \(error)")
        }
        return totalSize
    }

    // MARK: - 私有方法

    /// 启动自动保存定时器
    private func startAutoSaveTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: autoSaveInterval, repeats: true) { [weak self] _ in
            self?.autoSave()
        }
    }

    /// 自动保存
    private func autoSave() {
        if hasUnsavedDraft {
            saveDraft()
        }
    }

    /// 重置编辑暂停计时器
    private func resetEditPauseTimer() {
        editPauseTimer?.invalidate()
        editPauseTimer = Timer.scheduledTimer(withTimeInterval: editPauseSaveDelay, repeats: false) { [weak self] _ in
            self?.saveDraft()
        }
    }

    /// 处理内存警告
    @objc private func handleMemoryWarning() {
        // 内存警告时强制保存草稿
        if hasUnsavedDraft {
            saveDraft()
        }
    }

    /// 处理应用进入后台
    @objc private func handleAppDidEnterBackground() {
        // 进入后台时保存草稿
        if hasUnsavedDraft {
            saveDraft()
        }
    }

    /// 生成草稿文件名
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    /// - Returns: 文件名
    private func draftFileName(for filePath: String, branch: String) -> String {
        let encodedPath = filePath.replacingOccurrences(of: "/", with: "_")
        let encodedBranch = branch.replacingOccurrences(of: "/", with: "_")
        return "\(encodedBranch)_\(encodedPath).draft"
    }

    /// 保存草稿到磁盘
    /// - Parameter draft: 草稿
    private func saveDraftToDisk(_ draft: Draft) {
        do {
            let fileName = draftFileName(for: draft.filePath, branch: draft.branch)
            let fileURL = draftsDirectory.appendingPathComponent(fileName)
            let data = try JSONEncoder().encode(draft)
            try data.write(to: fileURL)

            // 检查草稿数量，超过上限则删除最旧的
            cleanupOldDraftsIfNeeded()
        } catch {
            print("保存草稿失败: \(error)")
        }
    }

    /// 从磁盘加载草稿
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    /// - Returns: 草稿
    private func loadDraft(for filePath: String, branch: String) -> Draft? {
        do {
            let fileName = draftFileName(for: filePath, branch: branch)
            let fileURL = draftsDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
            let data = try Data(contentsOf: fileURL)
            let draft = try JSONDecoder().decode(Draft.self, from: data)
            return draft
        } catch {
            print("加载草稿失败: \(error)")
            return nil
        }
    }

    /// 删除草稿
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    private func deleteDraft(for filePath: String, branch: String) {
        do {
            let fileName = draftFileName(for: filePath, branch: branch)
            let fileURL = draftsDirectory.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("删除草稿失败: \(error)")
        }
    }

    /// 加载所有草稿列表
    private func loadAllDrafts() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: draftsDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            var drafts: [Draft] = []
            for file in files {
                if file.pathExtension == "draft" {
                    if let data = try? Data(contentsOf: file),
                       let draft = try? JSONDecoder().decode(Draft.self, from: data) {
                        drafts.append(draft)
                    }
                }
            }
            // 按最后修改时间排序（最新的在前）
            drafts.sort { $0.lastModified > $1.lastModified }
            allDrafts = drafts
        } catch {
            print("加载草稿列表失败: \(error)")
        }
    }

    /// 清理旧草稿（超过最大数量时删除最旧的）
    private func cleanupOldDraftsIfNeeded() {
        loadAllDrafts()
        guard allDrafts.count > maxDraftsCount else { return }

        // 删除最旧的草稿
        let draftsToDelete = allDrafts.suffix(allDrafts.count - maxDraftsCount)
        for draft in draftsToDelete {
            deleteDraft(for: draft.filePath, branch: draft.branch)
        }
        loadAllDrafts()
    }
}

// ==============================================================================
// DraftManagerViewModifier 草稿管理视图修饰符
// 功能：为SwiftUI视图添加草稿恢复提示
// ==============================================================================

struct DraftRecoveryModifier: ViewModifier {
    @ObservedObject var draftManager = DraftManager.shared
    var filePath: String
    var branch: String
    var onRestore: ((String) -> Void)?

    @State private var showRecoveryAlert: Bool = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                // 检查是否有未保存的草稿
                if draftManager.hasDraft(for: filePath, branch: branch) {
                    showRecoveryAlert = true
                }
            }
            .alert("恢复未保存的修改", isPresented: $showRecoveryAlert) {
                Button("恢复", role: .destructive) {
                    if let content = draftManager.restoreDraft(for: filePath, branch: branch) {
                        onRestore?(content)
                    }
                }
                Button("放弃", role: .cancel) {
                    draftManager.clearDraft(for: filePath, branch: branch)
                }
            } message: {
                Text("检测到上次编辑未保存的修改，是否恢复？")
            }
    }
}

extension View {
    /// 添加草稿恢复支持
    /// - Parameters:
    ///   - filePath: 文件路径
    ///   - branch: 分支名
    ///   - onRestore: 恢复回调
    /// - Returns: 修饰后的视图
    func draftRecovery(filePath: String, branch: String, onRestore: ((String) -> Void)? = nil) -> some View {
        modifier(DraftRecoveryModifier(filePath: filePath, branch: branch, onRestore: onRestore))
    }
}
