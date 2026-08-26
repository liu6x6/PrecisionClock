import SwiftUI

struct AnalogClockView: View {
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // 模拟时钟表盘
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = size / 2 - 10

                ZStack {
                    // 表盘背景
                    ClockFace(radius: radius)
                        .position(center)

                    // 刻度
                    ClockTicks(center: center, radius: radius)

                    // 小时数字
                    ClockNumbers(center: center, radius: radius)

                    // 时针
                    ClockHand(
                        angle: hourAngle,
                        length: radius * 0.5,
                        width: 5,
                        color: .white,
                        tail: radius * 0.08
                    )
                    .position(center)
                    .shadow(color: .white.opacity(0.3), radius: 2)

                    // 分针
                    ClockHand(
                        angle: minuteAngle,
                        length: radius * 0.72,
                        width: 3.5,
                        color: .white.opacity(0.9),
                        tail: radius * 0.1
                    )
                    .position(center)
                    .shadow(color: .white.opacity(0.2), radius: 2)

                    // 秒针
                    SecondHand(
                        angle: secondAngle,
                        length: radius * 0.85,
                        tail: radius * 0.18,
                        color: .red
                    )
                    .position(center)
                    .shadow(color: .red.opacity(0.4), radius: 3)

                    // 中心圆
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .position(center)
                        .shadow(color: .red, radius: 4)

                    Circle()
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .position(center)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(20)

            // 数字毫秒显示
            VStack(spacing: 2) {
                Text(digitalTime)
                    .font(.system(size: 28, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                Text(millisecondTime)
                    .font(.system(size: 20, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.cyan)
                    .monospacedDigit()
            }

            // 日期
            Text(dateString)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundColor(.gray)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }

    // MARK: - 角度计算

    private var hourAngle: Double {
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .nanosecond], from: currentDate)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let nano = Double(components.nanosecond ?? 0)
        let totalSeconds = minute * 60 + second + nano / 1_000_000_000
        return (hour / 12) * 360 + (totalSeconds / 3600) * 30
    }

    private var minuteAngle: Double {
        let components = Calendar.current.dateComponents([.minute, .second, .nanosecond], from: currentDate)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        let nano = Double(components.nanosecond ?? 0)
        return (minute / 60) * 360 + ((second + nano / 1_000_000_000) / 60) * 6
    }

    private var secondAngle: Double {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: currentDate)
        let second = Double(components.second ?? 0)
        let nano = Double(components.nanosecond ?? 0)
        return (second + nano / 1_000_000_000) / 60 * 360
    }

    private var digitalTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentDate)
    }

    private var millisecondTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = ".SSS"
        return formatter.string(from: currentDate)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: currentDate)
    }
}

// MARK: - 表盘背景
struct ClockFace: View {
    let radius: CGFloat

    var body: some View {
        ZStack {
            // 外圈
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.12), Color(white: 0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    )
                )
                .frame(width: radius * 2, height: radius * 2)

            // 外边框
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.gray, .white.opacity(0.3), .gray],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: radius * 2, height: radius * 2)

            // 内圈装饰
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                .frame(width: radius * 1.8, height: radius * 1.8)
        }
    }
}

// MARK: - 刻度
struct ClockTicks: View {
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        ZStack {
            // 60个秒刻度
            ForEach(0..<60, id: \.self) { i in
                let angle = Double(i) / 60 * 360
                let isHour = i % 5 == 0
                let isQuarter = i % 15 == 0

                TickMark(
                    length: tickLength(isHour: isHour, isQuarter: isQuarter),
                    width: tickWidth(isHour: isHour, isQuarter: isQuarter),
                    color: tickColor(isHour: isHour, isQuarter: isQuarter)
                )
                .rotationEffect(.degrees(angle))
                .position(center)
            }

            // 分钟小刻度（每5秒之间4个更小的刻度）
            ForEach(0..<300, id: \.self) { i in
                if i % 5 != 0 {
                    let angle = Double(i) / 300 * 360
                    MiniTickMark(length: 3, width: 0.3)
                        .rotationEffect(.degrees(angle))
                        .position(center)
                }
            }
        }
    }

    private func tickLength(isHour: Bool, isQuarter: Bool) -> CGFloat {
        if isQuarter { return 16 }
        if isHour { return 12 }
        return 7
    }

    private func tickWidth(isHour: Bool, isQuarter: Bool) -> CGFloat {
        if isQuarter { return 3 }
        if isHour { return 2 }
        return 1
    }

    private func tickColor(isHour: Bool, isQuarter: Bool) -> Color {
        if isQuarter { return .white }
        if isHour { return .white.opacity(0.8) }
        return .gray.opacity(0.6)
    }
}

// 刻度线（从12点方向向外延伸）
struct TickMark: View {
    let length: CGFloat
    let width: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            Rectangle()
                .fill(color)
                .frame(width: width, height: length)
                .position(x: centerX, y: centerY - geometry.size.height / 2 + length / 2)
        }
        .frame(width: 1, height: 1)
    }
}

struct MiniTickMark: View {
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: width, height: length)
                .position(x: centerX, y: centerY - geometry.size.height / 2 + length / 2)
        }
        .frame(width: 1, height: 1)
    }
}

// MARK: - 小时数字
struct ClockNumbers: View {
    let center: CGPoint
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(1...12, id: \.self) { hour in
                let angle = Double(hour) / 12 * 360 - 90 // -90 让12在顶部
                let radian = angle * .pi / 180
                let numberRadius = radius * 0.78
                let x = center.x + cos(radian) * numberRadius
                let y = center.y + sin(radian) * numberRadius

                Text("\(hour)")
                    .font(.system(size: radius * 0.1, weight: .light, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .position(x: x, y: y)
            }
        }
    }
}

// MARK: - 时针/分针
struct ClockHand: View {
    let angle: Double
    let length: CGFloat
    let width: CGFloat
    let color: Color
    let tail: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2

            // 指针形状（带尾部）
            Path { path in
                // 尾部（圆形）
                path.move(to: CGPoint(x: centerX, y: centerY + tail))
                // 左侧
                path.addLine(to: CGPoint(x: centerX - width / 3, y: centerY))
                // 尖端
                path.addLine(to: CGPoint(x: centerX, y: centerY - length))
                // 右侧
                path.addLine(to: CGPoint(x: centerX + width / 3, y: centerY))
                path.closeSubpath()
            }
            .fill(color)
            .rotationEffect(.degrees(angle))
        }
        .frame(width: 1, height: 1)
    }
}

// MARK: - 秒针
struct SecondHand: View {
    let angle: Double
    let length: CGFloat
    let tail: CGFloat
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let centerX = geometry.size.width / 2
            let centerY = geometry.size.height / 2

            ZStack {
                // 秒针主体
                Path { path in
                    path.move(to: CGPoint(x: centerX, y: centerY + tail))
                    path.addLine(to: CGPoint(x: centerX, y: centerY - length))
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(angle))

                // 秒针圆形配重
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                    .offset(y: tail - 3)
                    .rotationEffect(.degrees(angle))
            }
        }
        .frame(width: 1, height: 1)
    }
}

struct AnalogClockView_Previews: PreviewProvider {
    static var previews: some View {
        AnalogClockView()
    }
}
