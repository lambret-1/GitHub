import Foundation

// ==============================================================================
// HighlightCache 高亮缓存管理器
// 功能：缓存语法高亮结果，避免重复计算，提升大文件打开速度
// 位置：语法高亮系统的性能优化层
// 缓存策略：基于文件路径+内容哈希+语言+主题的复合键，LRU淘汰
// ==============================================================================

class HighlightCache {
    // MARK: - 共享实例

    static let shared = HighlightCache()

    private init() {}

    // MARK: - 缓存条目

    /// 缓存条目
    private struct CacheEntry {
        let attributedString: NSAttributedString  // 高亮结果
        let timestamp: TimeInterval                  // 缓存时间
        let size: Int                                 // 结果大小（用于内存统计）
    }

    // MARK: - 缓存存储

    /// 缓存字典：键 -> 缓存条目
    private var cache: [String: CacheEntry] = [:]

    /// 缓存访问顺序（用于LRU淘汰）
    private var accessOrder: [String] = []

    /// 最大缓存条目数
    private let maxCacheCount = 20

    /// 最大缓存内存（字节）
    private let maxCacheMemory = 50 * 1024 * 1024 // 50MB

    /// 缓存总内存
    private var totalMemory: Int = 0

    // MARK: - 缓存键生成

    /// 生成缓存键
    /// - Parameters:
    ///   - text: 文本内容
    ///   - language: 编程语言
    ///   - theme: 语法主题
    ///   - font: 字体
    /// - Returns: 缓存键
    func cacheKey(text: String, language: ProgrammingLanguage, theme: SyntaxTheme, font: UIFont) -> String {
        // 使用内容哈希+语言+主题+字体大小作为键
        let contentHash = text.hashValue
        let themeName = String(describing: type(of: theme))
        let fontKey = "\(font.fontName)_\(font.pointSize)"
        return "\(language.rawValue)_\(themeName)_\(fontKey)_\(contentHash)"
    }

    // MARK: - 缓存读取

    /// 获取缓存的高亮结果
    /// - Parameter key: 缓存键
    /// - Returns: 高亮结果（nil表示缓存未命中）
    func get(key: String) -> NSAttributedString? {
        guard let entry = cache[key] else {
            return nil
        }

        // 更新访问顺序（移到末尾表示最近使用）
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)

        return entry.attributedString
    }

    // MARK: - 缓存写入

    /// 保存高亮结果到缓存
    /// - Parameters:
    ///   - attributedString: 高亮结果
    ///   - key: 缓存键
    func set(attributedString: NSAttributedString, key: String) {
        // 计算结果大小
        let size = attributedString.length * 2 // 粗略估算：每个字符2字节

        // 如果已存在相同键，先移除旧条目
        if let oldEntry = cache.removeValue(forKey: key) {
            totalMemory -= oldEntry.size
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }

        // 添加新条目
        let entry = CacheEntry(
            attributedString: attributedString,
            timestamp: CFAbsoluteTimeGetCurrent(),
            size: size
        )
        cache[key] = entry
        accessOrder.append(key)
        totalMemory += size

        // 执行LRU淘汰
        evictIfNeeded()
    }

    // MARK: - LRU淘汰

    /// 执行LRU淘汰
    private func evictIfNeeded() {
        // 淘汰条件：超过最大条目数或超过最大内存
        while cache.count > maxCacheCount || totalMemory > maxCacheMemory {
            guard let oldestKey = accessOrder.first else {
                break
            }

            if let entry = cache.removeValue(forKey: oldestKey) {
                totalMemory -= entry.size
            }
            accessOrder.removeFirst()
        }
    }

    // MARK: - 缓存清理

    /// 清空所有缓存
    func clearAll() {
        cache.removeAll()
        accessOrder.removeAll()
        totalMemory = 0
    }

    /// 清空指定语言的缓存
    /// - Parameter language: 编程语言
    func clear(for language: ProgrammingLanguage) {
        let keysToRemove = cache.keys.filter { $0.hasPrefix(language.rawValue + "_") }
        for key in keysToRemove {
            if let entry = cache.removeValue(forKey: key) {
                totalMemory -= entry.size
            }
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        }
    }

    // MARK: - 缓存统计

    /// 缓存统计信息
    var stats: (count: Int, memory: Int, hitRate: Double) {
        return (cache.count, totalMemory, 0) // hitRate需要额外统计
    }

    /// 缓存命中率统计
    private var hitCount = 0
    private var missCount = 0

    /// 记录缓存命中
    func recordHit() {
        hitCount += 1
    }

    /// 记录缓存未命中
    func recordMiss() {
        missCount += 1
    }

    /// 获取缓存命中率
    var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }

    /// 重置命中率统计
    func resetHitRate() {
        hitCount = 0
        missCount = 0
    }
}

// ==============================================================================
// HighlightTaskManager 高亮任务管理器
// 功能：管理后台高亮任务，支持取消和优先级调度
// 位置：语法高亮系统的异步执行层
// ==============================================================================

class HighlightTaskManager {
    // MARK: - 共享实例

    static let shared = HighlightTaskManager()

    private init() {}

    // MARK: - 任务队列

    /// 高亮任务队列（串行队列，避免并发竞争）
    private let taskQueue = DispatchQueue(label: "com.github.highlight.queue", qos: .userInitiated)

    /// 当前运行的任务
    private var currentTask: DispatchWorkItem?

    /// 任务ID计数器
    private var taskIdCounter = 0

    // MARK: - 异步高亮

    /// 异步执行语法高亮
    /// - Parameters:
    ///   - text: 文本内容
    ///   - language: 编程语言
    ///   - font: 字体
    ///   - theme: 语法主题
    ///   - completion: 完成回调（在主线程调用）
    /// - Returns: 任务ID（可用于取消）
    @discardableResult
    func highlightAsync(
        text: String,
        language: ProgrammingLanguage,
        font: UIFont,
        theme: SyntaxTheme,
        completion: @escaping (NSAttributedString) -> Void
    ) -> Int {
        // 生成任务ID
        taskIdCounter += 1
        let taskId = taskIdCounter

        // 取消当前任务
        currentTask?.cancel()

        // 创建新任务
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // 检查任务是否被取消
            if workItem.isCancelled {
                return
            }

            // 生成缓存键
            let cacheKey = HighlightCache.shared.cacheKey(
                text: text,
                language: language,
                theme: theme,
                font: font
            )

            // 检查缓存
            if let cached = HighlightCache.shared.get(key: cacheKey) {
                HighlightCache.shared.recordHit()
                DispatchQueue.main.async {
                    completion(cached)
                }
                return
            }

            HighlightCache.shared.recordMiss()

            // 执行词法分析
            let tokenizer = SyntaxHighlighter.shared.getTokenizer(for: language)
            let tokens = tokenizer.tokenize(text)

            // 检查任务是否被取消
            if workItem.isCancelled {
                return
            }

            // 应用高亮
            let result = HighlightEngine.shared.applyHighlight(
                text: text,
                tokens: tokens,
                font: font,
                theme: theme
            )

            // 保存到缓存
            HighlightCache.shared.set(attributedString: result, key: cacheKey)

            // 检查任务是否被取消
            if workItem.isCancelled {
                return
            }

            // 在主线程回调
            DispatchQueue.main.async {
                completion(result)
            }
        }

        // 保存当前任务
        currentTask = workItem

        // 提交任务到队列
        taskQueue.async(execute: workItem)

        return taskId
    }

    // MARK: - 取消任务

    /// 取消当前高亮任务
    func cancelCurrent() {
        currentTask?.cancel()
        currentTask = nil
    }

    /// 取消所有任务
    func cancelAll() {
        currentTask?.cancel()
        currentTask = nil
        taskQueue.sync {} // 等待队列清空
    }
}
