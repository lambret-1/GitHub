import UIKit
import Combine

// ==============================================================================
// KeyboardManager 键盘状态管理器
// 功能：统一监听键盘弹出/收起事件，提供键盘高度、动画时长、动画曲线等信息
// 位置：文件编辑器的键盘管理核心层
// 设计原则：单例模式，Combine发布者，所有键盘相关状态统一来源
// ==============================================================================

class KeyboardManager: ObservableObject {
    // MARK: - 共享实例

    static let shared = KeyboardManager()

    private init() {
        // 监听键盘事件
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 键盘状态发布者

    /// 键盘是否可见
    @Published private(set) var isKeyboardVisible: Bool = false

    /// 键盘高度（包括安全区域）
    @Published private(set) var keyboardHeight: CGFloat = 0

    /// 键盘高度（不包括安全区域，用于内容偏移计算）
    @Published private(set) var keyboardHeightWithoutSafeArea: CGFloat = 0

    /// 键盘动画时长
    @Published private(set) var animationDuration: TimeInterval = 0.25

    /// 键盘动画曲线
    @Published private(set) var animationCurve: UIView.AnimationCurve = .easeInOut

    /// 键盘结束帧
    @Published private(set) var keyboardEndFrame: CGRect = .zero

    /// 键盘开始帧
    @Published private(set) var keyboardBeginFrame: CGRect = .zero

    // MARK: - 键盘事件处理

    @objc private func keyboardWillShow(_ notification: Notification) {
        updateKeyboardState(from: notification, willShow: true)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        updateKeyboardState(from: notification, willShow: false)
    }

    @objc private func keyboardDidShow(_ notification: Notification) {
        isKeyboardVisible = true
    }

    @objc private func keyboardDidHide(_ notification: Notification) {
        isKeyboardVisible = false
        keyboardHeight = 0
        keyboardHeightWithoutSafeArea = 0
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        updateKeyboardState(from: notification, willShow: nil)
    }

    // MARK: - 统一更新键盘状态

    /// 从通知中提取键盘信息并更新状态
    /// - Parameters:
    ///   - notification: 键盘通知
    ///   - willShow: 是否将要显示（nil表示不改变可见状态，仅更新帧）
    private func updateKeyboardState(from notification: Notification, willShow: Bool?) {
        guard let userInfo = notification.userInfo else { return }

        // 获取键盘结束帧
        if let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardEndFrame = endFrame

            // 计算键盘高度（基于屏幕高度 - 键盘y坐标）
            let screenHeight = UIScreen.main.bounds.height
            let calculatedHeight = max(0, screenHeight - endFrame.origin.y)
            keyboardHeight = calculatedHeight

            // 计算不包括安全区域的键盘高度
            let safeAreaBottom = getSafeAreaBottom()
            keyboardHeightWithoutSafeArea = max(0, calculatedHeight - safeAreaBottom)
        }

        // 获取键盘开始帧
        if let beginFrame = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardBeginFrame = beginFrame
        }

        // 获取动画时长
        if let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue {
            animationDuration = duration
        }

        // 获取动画曲线
        if let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.intValue,
           let curve = UIView.AnimationCurve(rawValue: curveRaw) {
            animationCurve = curve
        }

        // 更新可见状态
        if let willShow = willShow {
            // 不立即更新isKeyboardVisible，等didShow/didHide再更新，避免状态闪烁
        }
    }

    // MARK: - 安全区域获取

    /// 获取底部安全区域高度
    /// - Returns: 底部安全区域高度
    private func getSafeAreaBottom() -> CGFloat {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return 0
        }
        return window.safeAreaInsets.bottom
    }

    // MARK: - 工具方法

    /// 获取键盘动画选项（用于UIView.animate）
    var animationOptions: UIView.AnimationOptions {
        return UIView.AnimationOptions(rawValue: UInt(animationCurve.rawValue << 16))
    }

    /// 执行键盘动画（统一动画参数）
    /// - Parameter animations: 动画闭包
    func animate(with animations: @escaping () -> Void) {
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: animationOptions,
            animations: animations,
            completion: nil
        )
    }

    /// 重置键盘状态（用于页面消失时清理）
    func reset() {
        isKeyboardVisible = false
        keyboardHeight = 0
        keyboardHeightWithoutSafeArea = 0
    }
}

// ==============================================================================
// KeyboardAvoidingView 键盘避让视图修饰符
// 功能：SwiftUI视图修饰符，自动避让键盘
// 使用方式：.keyboardAvoiding()
// ==============================================================================

struct KeyboardAvoidingModifier: ViewModifier {
    @ObservedObject private var keyboardManager = KeyboardManager.shared
    var extraPadding: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardManager.isKeyboardVisible ? keyboardManager.keyboardHeightWithoutSafeArea + extraPadding : 0)
            .animation(.easeOut(duration: keyboardManager.animationDuration), value: keyboardManager.keyboardHeight)
    }
}

extension View {
    /// 键盘避让修饰符
    /// - Parameter extraPadding: 额外底部间距
    /// - Returns: 修饰后的视图
    func keyboardAvoiding(extraPadding: CGFloat = 0) -> some View {
        modifier(KeyboardAvoidingModifier(extraPadding: extraPadding))
    }
}

// ==============================================================================
// KeyboardAccessoryView 键盘附件视图（用于底部工具栏）
// 功能：作为UITextView的inputAccessoryView，确保工具栏始终在键盘顶部
// ==============================================================================

class KeyboardAccessoryView: UIView {
    /// 工具栏内容视图
    private var contentView: UIView?

    /// 初始化
    /// - Parameter contentView: 工具栏内容视图
    init(contentView: UIView) {
        self.contentView = contentView
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 50))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupView() {
        guard let contentView = contentView else { return }
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // 设置自动布局尺寸
        autoresizingMask = .flexibleHeight
    }

    /// 更新内容视图高度
    /// - Parameter height: 新高度
    func updateHeight(_ height: CGFloat) {
        frame.size.height = height
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: frame.height)
    }
}
