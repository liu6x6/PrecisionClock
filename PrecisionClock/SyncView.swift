import SwiftUI

struct SyncView: View {
    @StateObject private var ntpManager = NTPManager()
    @State private var showServerPicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 自定义标题栏（iOS / macOS 通用）
            HStack {
                Text("NTP 对时")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                refreshButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black)

            ScrollView {
                VStack(spacing: 16) {
                    // 当前选中的时钟源
                    SelectedServerCard(
                        server: ntpManager.selectedServer,
                        measurement: ntpManager.measurements[ntpManager.selectedServerId],
                        correctedOffset: ntpManager.correctedOffset
                    )

                    // 本机精确时间（已校准）
                    CorrectedClockCard(offset: ntpManager.correctedOffset)

                    // 选择时钟源
                    ServerListSection(
                        ntpManager: ntpManager,
                        selectedId: $ntpManager.selectedServerId
                    )

                    // 全部测量结果
                    MeasurementResultsSection(measurements: ntpManager.measurements)

                    // 操作说明
                    InstructionsCard()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    private var refreshButton: some View {
        Button(action: {
            Task { await ntpManager.measureAll() }
        }) {
            if ntpManager.isMeasuring {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.cyan)
            }
        }
    }
}

// MARK: - 选中服务器卡片
struct SelectedServerCard: View {
    let server: NTPServer
    let measurement: NTPMeasurement?
    let correctedOffset: TimeInterval

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(server.flag)
                    .font(.system(size: 24))
                VStack(alignment: .leading) {
                    Text(server.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    Text(server.host)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.gray)
                }
                Spacer()
                if let m = measurement {
                    StatusDot(success: m.success)
                }
            }

            if let m = measurement, m.success {
                HStack(spacing: 20) {
                    VStack {
                        Text("偏差")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%+.1f ms", m.offsetMs))
                            .font(.system(size: 22, weight: .light, design: .monospaced))
                            .foregroundColor(offsetColor(m.offsetMs))
                            .monospacedDigit()
                    }
                    VStack {
                        Text("延迟")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f ms", m.rttMs))
                            .font(.system(size: 22, weight: .light, design: .monospaced))
                            .foregroundColor(.orange)
                            .monospacedDigit()
                    }
                    VStack {
                        Text("状态")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Text(abs(m.offsetMs) < 10 ? "精准" : abs(m.offsetMs) < 50 ? "良好" : "偏差大")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(offsetColor(m.offsetMs))
                    }
                }
                .padding(.top, 4)
            } else if let m = measurement, !m.success {
                Text(m.error ?? "连接失败")
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.top, 4)
            } else {
                Text("点击右侧按钮测量所有时钟源")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func offsetColor(_ ms: Double) -> Color {
        let absMs = abs(ms)
        if absMs < 10 { return .green }
        if absMs < 50 { return .yellow }
        return .red
    }
}

// MARK: - 校准后的时钟
struct CorrectedClockCard: View {
    let offset: TimeInterval
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 4) {
            Text("校准后时间")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(.gray)

            Text(mainTime)
                .font(.system(size: 40, weight: .thin, design: .monospaced))
                .foregroundColor(.white)
                .monospacedDigit()

            Text(milliseconds)
                .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                .foregroundColor(.yellow)
                .monospacedDigit()

            // 微型刻度
            MiniScale(currentDate: correctedDate)
                .frame(height: 12)
                .padding(.horizontal, 10)
                .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }

    private var correctedDate: Date {
        currentDate.addingTimeInterval(-offset)
    }

    private var mainTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: correctedDate)
    }

    private var milliseconds: String {
        let formatter = DateFormatter()
        formatter.dateFormat = ".SSS"
        return formatter.string(from: correctedDate)
    }
}

// MARK: - 服务器列表
struct ServerListSection: View {
    @ObservedObject var ntpManager: NTPManager
    @Binding var selectedId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择时钟源")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
                .padding(.leading, 4)

            ForEach(NTPServer.allServers) { server in
                ServerRow(
                    server: server,
                    measurement: ntpManager.measurements[server.id],
                    isSelected: server.id == selectedId,
                    onTap: {
                        selectedId = server.id
                        ntpManager.selectServer(server.id)
                    },
                    onMeasure: {
                        Task { await ntpManager.measure(server: server) }
                    }
                )
            }
        }
    }
}

struct ServerRow: View {
    let server: NTPServer
    let measurement: NTPMeasurement?
    let isSelected: Bool
    let onTap: () -> Void
    let onMeasure: () -> Void

    var body: some View {
        HStack {
            // 选择按钮
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Text(server.flag)
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.name)
                            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                            .foregroundColor(isSelected ? .cyan : .white)
                        Text("\(server.host) · \(server.region)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.cyan)
                            .font(.system(size: 16))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // 测量结果
            if let m = measurement {
                VStack(alignment: .trailing, spacing: 1) {
                    if m.success {
                        Text(String(format: "%+.1fms", m.offsetMs))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(offsetColor(m.offsetMs))
                            .monospacedDigit()
                        Text(String(format: "RTT %.0fms", m.rttMs))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.gray)
                            .monospacedDigit()
                    } else {
                        Text("失败")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }
            }

            // 单独测量按钮
            Button(action: onMeasure) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.cyan.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.cyan.opacity(0.1) : Color.gray.opacity(0.08))
        )
    }

    private func offsetColor(_ ms: Double) -> Color {
        let absMs = abs(ms)
        if absMs < 10 { return .green }
        if absMs < 50 { return .yellow }
        return .red
    }
}

// MARK: - 测量结果汇总
struct MeasurementResultsSection: View {
    let measurements: [String: NTPMeasurement]

    var body: some View {
        let successMeasurements = measurements.values.filter { $0.success }.sorted { abs($0.offsetMs) < abs($1.offsetMs) }

        if !successMeasurements.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("偏差排名（越小越准）")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.leading, 4)

                ForEach(Array(successMeasurements.enumerated()), id: \.element.id) { index, m in
                    HStack {
                        Text("\(index + 1)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(index == 0 ? .green : .gray)
                            .frame(width: 20)

                        Text(m.server.flag)
                            .font(.system(size: 16))

                        Text(m.server.name)
                            .font(.system(size: 14))
                            .foregroundColor(.white)

                        Spacer()

                        // 偏差条
                        OffsetBar(offsetMs: m.offsetMs, maxOffset: 200)
                            .frame(width: 80, height: 6)

                        Text(String(format: "%+.1fms", m.offsetMs))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(offsetColor(m.offsetMs))
                            .monospacedDigit()
                            .frame(width: 70, alignment: .trailing)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
            }
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.06))
            )
        }
    }

    private func offsetColor(_ ms: Double) -> Color {
        let absMs = abs(ms)
        if absMs < 10 { return .green }
        if absMs < 50 { return .yellow }
        return .red
    }
}

// MARK: - 偏差条
struct OffsetBar: View {
    let offsetMs: Double
    let maxOffset: Double

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let center = width / 2
            let barWidth = min(width / 2, CGFloat(abs(offsetMs) / maxOffset) * center)

            ZStack {
                // 中心线
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: 6)
                    .position(x: center, y: 3)

                // 偏差条
                RoundedRectangle(cornerRadius: 2)
                    .fill(offsetColor)
                    .frame(width: barWidth, height: 4)
                    .offset(x: offsetMs >= 0 ? barWidth / 2 : -barWidth / 2)
            }
        }
    }

    private var offsetColor: Color {
        let absMs = abs(offsetMs)
        if absMs < 10 { return .green }
        if absMs < 50 { return .yellow }
        return .red
    }
}

// MARK: - 操作说明
struct InstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("对时方法")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Label("点击右上角按钮一键测量所有时钟源", systemImage: "1.circle")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("选择偏差最小的时钟源作为主时钟", systemImage: "2.circle")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("两台手机选同一时钟源，对比校准时间", systemImage: "3.circle")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("绿色 = 偏差<10ms  黄色 = <50ms  红色 = >50ms", systemImage: "info.circle")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - 状态点
struct StatusDot: View {
    let success: Bool
    var body: some View {
        Circle()
            .fill(success ? Color.green : Color.red)
            .frame(width: 8, height: 8)
            .shadow(color: success ? .green : .red, radius: 3)
    }
}

// MARK: - 微型刻度条
struct MiniScale: View {
    let currentDate: Date

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let position = currentPosition(in: width)

            ZStack(alignment: .leading) {
                ForEach(0..<100, id: \.self) { i in
                    let x = CGFloat(i) / 100.0 * width
                    Rectangle()
                        .fill(i % 10 == 0 ? Color.white.opacity(0.5) : Color.gray.opacity(0.3))
                        .frame(width: 0.5, height: i % 10 == 0 ? 10 : 5)
                        .offset(x: x, y: (12 - (i % 10 == 0 ? 10 : 5)) / 2)
                }

                Rectangle()
                    .fill(.yellow)
                    .frame(width: 1.5, height: 12)
                    .offset(x: position)
            }
        }
    }

    private func currentPosition(in width: CGFloat) -> CGFloat {
        let components = Calendar.current.dateComponents([.second, .nanosecond], from: currentDate)
        let ns = Double(components.nanosecond ?? 0)
        let fraction = ns / 1_000_000_000.0
        return CGFloat(fraction) * width
    }
}

struct SyncView_Previews: PreviewProvider {
    static var previews: some View {
        SyncView()
    }
}
