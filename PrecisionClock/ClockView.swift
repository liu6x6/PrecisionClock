import SwiftUI

struct ClockView: View {
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 6) {
            Spacer()

            // 主时间显示 - 时:分:秒
            Text(mainTime)
                .font(.system(size: 64, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()

            // 毫秒显示
            Text(milliseconds)
                .font(.system(size: 48, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.cyan)
                .monospacedDigit()

            // 毫秒进度条
            MicrosecondBar(currentDate: currentDate)
                .frame(height: 30)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            // 精细刻度视图（带数字标签）
            FineScaleView(currentDate: currentDate)
                .frame(height: 80)
                .padding(.horizontal, 10)

            // 日期信息
            Text(dateString)
                .font(.system(size: 16, weight: .light, design: .monospaced))
                .foregroundColor(.gray)
                .padding(.top, 10)

            Spacer()
        }
        .background(Color.black.ignoresSafeArea())
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }

    private var mainTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentDate)
    }

    private var milliseconds: String {
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

// MARK: - 毫秒级进度条
struct MicrosecondBar: View {
    let currentDate: Date

    var body: some View {
        GeometryReader { geometry in
            let progress = millisecondProgress
            ZStack(alignment: .leading) {
                // 背景轨道
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 6)

                // 进度条
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geometry.size.width * progress), height: 6)

                // 游标
                Circle()
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .offset(x: geometry.size.width * progress - 5)
                    .shadow(color: .cyan, radius: 4)
            }
        }
    }

    private var millisecondProgress: Double {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: currentDate)
        let ns = Double(components.nanosecond ?? 0)
        return ns / 1_000_000_000.0
    }
}

// MARK: - 精细刻度视图（带数字标签）
struct FineScaleView: View {
    let currentDate: Date

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let position = currentPosition(in: width)

            ZStack(alignment: .topLeading) {
                // 刻度线 + 数字标签
                ForEach(0..<201, id: \.self) { i in
                    let x = CGFloat(i) / 200.0 * width
                    let isMajor = (i % 100 == 0)
                    let isMid = (i % 50 == 0) && !isMajor
                    let isMinor10 = (i % 10 == 0) && !isMajor && !isMid

                    // 刻度线
                    Rectangle()
                        .fill(scaleColor(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10))
                        .frame(width: lineWidth(isMajor: isMajor, isMid: isMid), height: lineHeight(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10))
                        .position(x: x, y: lineHeight(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10) / 2)

                    // 数字标签 - 只在主要和中间刻度显示
                    if isMajor || isMid {
                        Text("\(i * 5)")
                            .font(.system(size: 9, weight: .light, design: .monospaced))
                            .foregroundColor(isMajor ? .white : .gray)
                            .position(x: x, y: 48)
                    } else if isMinor10 {
                        // 小刻度也显示但更小
                        Text("\(i * 5)")
                            .font(.system(size: 7, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.6))
                            .position(x: x, y: 48)
                    }
                }

                // 单位标签
                Text("ms")
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .position(x: width - 10, y: 48)

                // 当前位置指示器（三角）
                    Triangle()
                        .fill(.cyan)
                        .frame(width: 8, height: 6)
                        .position(x: position, y: 62)

                // 当前值
                Text("\(currentMs)ms")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.cyan)
                    .position(x: min(max(position, 20), width - 20), y: 73)
            }
        }
    }

    private var currentMs: Int {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: currentDate)
        return (components.nanosecond ?? 0) / 1_000_000
    }

    private func currentPosition(in width: CGFloat) -> CGFloat {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: currentDate)
        let ns = Double(components.nanosecond ?? 0)
        let fraction = ns / 1_000_000_000.0
        return CGFloat(fraction) * width
    }

    private func scaleColor(isMajor: Bool, isMid: Bool, isMinor10: Bool) -> Color {
        if isMajor { return .white }
        if isMid { return .gray }
        if isMinor10 { return .gray.opacity(0.6) }
        return .gray.opacity(0.25)
    }

    private func lineWidth(isMajor: Bool, isMid: Bool) -> CGFloat {
        if isMajor { return 1.5 }
        if isMid { return 1 }
        return 0.5
    }

    private func lineHeight(isMajor: Bool, isMid: Bool, isMinor10: Bool) -> CGFloat {
        if isMajor { return 28 }
        if isMid { return 20 }
        if isMinor10 { return 12 }
        return 6
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ClockView_Previews: PreviewProvider {
    static var previews: some View {
        ClockView()
    }
}
