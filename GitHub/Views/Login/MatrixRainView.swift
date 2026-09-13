import SwiftUI

// MARK: - 矩阵雨动画视图（黑客帝国风格）
/// 黑客/码农暗黑风格的字符雨动画效果
/// 用于登录页面头像背景，营造科技感和黑客氛围
struct MatrixRainView: View {
    // 动画计时器，驱动字符下落
    @State private var animatableData: Double = 0
    // 字符列数（减少到12列，降低性能开销）
    private let columns = 12
    // 字符集：只使用ASCII字符，避免日文字体渲染开销
    private let characters = Array("01<>/\\|{}[]=+*#$%&@")
    // 定时器，每100毫秒更新一次（降低频率，减少CPU使用）
    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            let columnWidth = geometry.size.width / CGFloat(columns)
            let rowHeight: CGFloat = 20

            ZStack {
                // 黑色背景
                Color.black.opacity(0.85)

                // 矩阵字符雨（减少到10行）
                ForEach(0..<columns, id: \.self) { column in
                    MatrixColumnView(
                        column: column,
                        columnWidth: columnWidth,
                        rowHeight: rowHeight,
                        characters: characters,
                        animatableData: animatableData
                    )
                }
            }
            // 顶部渐变遮罩，让字符从顶部淡入
            .mask(
                LinearGradient(
                    gradient: Gradient(colors: [
                        .black.opacity(0.3),
                        .black.opacity(0.8),
                        .black.opacity(0.95),
                        .black.opacity(0.8),
                        .black.opacity(0.3)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .onReceive(timer) { _ in
            // 更新动画数据，驱动字符下落
            animatableData += 1
        }
    }
}

// MARK: - 单列矩阵字符视图
/// 每一列的字符下落动画
struct MatrixColumnView: View {
    let column: Int
    let columnWidth: CGFloat
    let rowHeight: CGFloat
    let characters: [Character]
    let animatableData: Double

    // 每列的随机速度和偏移量，确保动画自然
    private var speed: Double {
        Double((column * 7 + 13) % 3 + 1)
    }

    private var offset: Double {
        Double((column * 17 + 29) % 20)
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<10, id: \.self) { row in
                Text(String(characterAt(row: row)))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(colorFor(row: row))
                    .frame(width: columnWidth, height: rowHeight)
            }
        }
        .offset(y: CGFloat((animatableData * speed + offset).truncatingRemainder(dividingBy: Double(rowHeight * 10))))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, CGFloat(column) * columnWidth)
    }

    /// 根据行和列计算字符
    private func characterAt(row: Int) -> Character {
        let index = Int((animatableData * speed + offset + Double(row * 3 + column)).truncatingRemainder(dividingBy: Double(characters.count)))
        return characters[abs(index) % characters.count]
    }

    /// 根据行计算颜色，头部亮绿色，尾部渐变暗
    private func colorFor(row: Int) -> Color {
        let brightness = Double(10 - row) / 10.0
        if row == 0 {
            // 头部字符：亮白色带绿色光晕
            return Color(red: 0.8, green: 1.0, blue: 0.8)
        } else {
            // 尾部字符：渐变绿色
            return Color(red: 0.0, green: brightness * 0.8, blue: 0.0)
        }
    }
}

// MARK: - 头像发光脉冲效果
/// 黑客风格的头像发光脉冲动画
struct GlowingAvatarView: View {
    let imageName: String
    let size: CGFloat

    // 脉冲动画状态
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 0.6

    var body: some View {
        ZStack {
            // 外层发光圆环
            Circle()
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.green.opacity(0.8),
                            Color.green.opacity(0.2),
                            Color.green.opacity(0.8)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: size + 20, height: size + 20)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)

            // 中层扫描线
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(Color.green, lineWidth: 3)
                .frame(width: size + 14, height: size + 14)
                .rotationEffect(.degrees(pulseScale * 360))

            // 头像
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .cornerRadius(size / 5)
                .overlay(
                    // 头像边框
                    RoundedRectangle(cornerRadius: size / 5)
                        .stroke(Color.green.opacity(0.6), lineWidth: 1.5)
                )
                .shadow(color: Color.green.opacity(0.5), radius: 8, x: 0, y: 0)
        }
        .onAppear {
            // 启动脉冲动画
            withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
                pulseOpacity = 0.2
            }
        }
    }
}

// MARK: - 扫描线覆盖层
/// 老式CRT显示器扫描线效果（优化：使用渐变替代大量Rectangle视图）
struct ScanlineOverlayView: View {
    var body: some View {
        // 使用线性渐变模拟扫描线效果，避免创建数百个Rectangle视图
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.15), location: 0.0),
                .init(color: Color.clear, location: 0.5),
                .init(color: Color.black.opacity(0.15), location: 1.0)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .allowsHitTesting(false)
    }
}
