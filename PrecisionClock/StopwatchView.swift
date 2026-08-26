import SwiftUI

struct StopwatchView: View {
    @ObservedObject var timer: PrecisionTimer

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            // 主显示区域
            VStack(spacing: 2) {
                // 分:秒
                Text(minutesSeconds)
                    .font(.system(size: 72, weight: .thin, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()

                // 毫秒
                Text(millisecondsPart)
                    .font(.system(size: 40, weight: .ultraLight, design: .monospaced))
                    .foregroundColor(.green)
                    .monospacedDigit()
            }

            // 秒表精细刻度（带数字标签）
            StopwatchScale(elapsedTime: timer.elapsedTime)
                .frame(height: 75)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            // 纳米级进度环
            NanoProgressRing(elapsedTime: timer.elapsedTime)
                .frame(width: 100, height: 100)
                .padding(.top, 4)

            Spacer()

            // 计圈列表
            if !timer.laps.isEmpty {
                LapListView(laps: timer.laps)
                    .frame(maxHeight: 180)
            }

            // 控制按钮
            HStack(spacing: 40) {
                Button(action: {
                    if timer.isRunning {
                        timer.lap()
                    } else {
                        timer.reset()
                    }
                }) {
                    Text(timer.isRunning ? "计圈" : "重置")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.gray.opacity(0.3)))
                }

                Button(action: {
                    if timer.isRunning {
                        timer.stop()
                    } else {
                        timer.start()
                    }
                }) {
                    Text(timer.isRunning ? "暂停" : "开始")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(timer.isRunning ? Color.orange : Color.green))
                }
            }
            .padding(.bottom, 30)
        }
        .background(Color.black.ignoresSafeArea())
    }

    private var minutesSeconds: String {
        let totalSeconds = Int(timer.elapsedTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var millisecondsPart: String {
        let ms = Int((timer.elapsedTime.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: ".%03d", ms)
    }
}

// MARK: - 秒表精细刻度（带数字标签）
struct StopwatchScale: View {
    let elapsedTime: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let position = currentPosition(in: width)

            ZStack(alignment: .topLeading) {
                // 背景
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.08))

                // 刻度线 + 标签
                ForEach(0..<501, id: \.self) { i in
                    let x = CGFloat(i) / 500.0 * width
                    let isMajor = (i % 100 == 0)    // 每 200ms
                    let isMid = (i % 50 == 0) && !isMajor    // 每 100ms
                    let isMinor10 = (i % 10 == 0) && !isMajor && !isMid  // 每 20ms

                    // 刻度线
                    Rectangle()
                        .fill(swScaleColor(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10))
                        .frame(
                            width: swLineWidth(isMajor: isMajor, isMid: isMid),
                            height: swLineHeight(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10)
                        )
                        .position(x: x, y: swLineHeight(isMajor: isMajor, isMid: isMid, isMinor10: isMinor10) / 2)

                    // 数字标签
                    if isMajor {
                        Text("\(i * 2)")
                            .font(.system(size: 9, weight: .light, design: .monospaced))
                            .foregroundColor(.white)
                            .position(x: x, y: 42)
                    } else if isMid {
                        Text("\(i * 2)")
                            .font(.system(size: 8, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.gray)
                            .position(x: x, y: 42)
                    } else if isMinor10 {
                        Text("\(i * 2)")
                            .font(.system(size: 7, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.gray.opacity(0.5))
                            .position(x: x, y: 42)
                    }
                }

                // 单位
                Text("ms")
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .foregroundColor(.gray.opacity(0.5))
                    .position(x: width - 10, y: 42)

                // 当前位置标记（竖线 + 三角）
                Rectangle()
                    .fill(.green)
                    .frame(width: 2, height: 35)
                    .position(x: position, y: 17)
                    .shadow(color: .green, radius: 3)

                Triangle()
                    .fill(.green)
                    .frame(width: 8, height: 6)
                    .position(x: position, y: 55)

                // 当前值
                Text(String(format: "%dms", Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 1000)))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.green)
                    .position(x: min(max(position, 20), width - 20), y: 67)
            }
        }
    }

    private func currentPosition(in width: CGFloat) -> CGFloat {
        let fraction = elapsedTime.truncatingRemainder(dividingBy: 1)
        return CGFloat(fraction) * width
    }

    private func swScaleColor(isMajor: Bool, isMid: Bool, isMinor10: Bool) -> Color {
        if isMajor { return .white }
        if isMid { return .gray }
        if isMinor10 { return .gray.opacity(0.5) }
        return .gray.opacity(0.2)
    }

    private func swLineWidth(isMajor: Bool, isMid: Bool) -> CGFloat {
        if isMajor { return 1.5 }
        if isMid { return 1 }
        return 0.5
    }

    private func swLineHeight(isMajor: Bool, isMid: Bool, isMinor10: Bool) -> CGFloat {
        if isMajor { return 26 }
        if isMid { return 18 }
        if isMinor10 { return 11 }
        return 5
    }
}

// MARK: - 纳米级进度环
struct NanoProgressRing: View {
    let elapsedTime: TimeInterval

    var body: some View {
        ZStack {
            // 外圈 - 秒
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: secondProgress)
                .stroke(
                    AngularGradient(colors: [.green, .cyan, .blue, .green], center: .center),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // 中圈 - 10毫秒
            Circle()
                .stroke(Color.gray.opacity(0.15), lineWidth: 2)
                .padding(8)

            Circle()
                .trim(from: 0, to: tenMsProgress)
                .stroke(Color.green.opacity(0.7), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(8)

            // 内圈 - 毫秒
            Circle()
                .stroke(Color.gray.opacity(0.1), lineWidth: 1.5)
                .padding(16)

            Circle()
                .trim(from: 0, to: msProgress)
                .stroke(Color.cyan.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(16)

            // 中心文字
            VStack(spacing: 0) {
                Text(centralText)
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
        }
    }

    private var secondProgress: CGFloat {
        CGFloat(elapsedTime.truncatingRemainder(dividingBy: 1))
    }

    private var tenMsProgress: CGFloat {
        let ms = (elapsedTime * 100).truncatingRemainder(dividingBy: 100)
        return CGFloat(ms / 100)
    }

    private var msProgress: CGFloat {
        let us = (elapsedTime * 1000).truncatingRemainder(dividingBy: 1000)
        return CGFloat(us / 1000)
    }

    private var centralText: String {
        let ms = Int((elapsedTime.truncatingRemainder(dividingBy: 1)) * 1000)
        return "\(ms)ms"
    }
}

// MARK: - 计圈列表
struct LapListView: View {
    let laps: [TimeInterval]

    var body: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(Array(laps.enumerated()), id: \.offset) { index, lap in
                    HStack {
                        Text("圈 \(index + 1)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)

                        Spacer()

                        Text(formatTime(lap))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()

                        if index > 0 {
                            Text("+\(formatTime(lap - laps[index - 1]))")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.yellow)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, ms)
    }
}

struct StopwatchView_Previews: PreviewProvider {
    static var previews: some View {
        StopwatchView(timer: PrecisionTimer())
    }
}
