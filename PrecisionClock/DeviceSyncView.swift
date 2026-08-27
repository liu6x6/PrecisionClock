import SwiftUI
import MultipeerConnectivity

struct DeviceSyncView: View {
    @StateObject private var syncManager = DeviceSyncManager()
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            headerBar

            ScrollView {
                VStack(spacing: 16) {
                    // 连接状态卡片
                    ConnectionStatusCard(syncManager: syncManager)

                    // 未连接时：显示角色选择
                    if !syncManager.isConnected {
                        RoleSelectionCard(syncManager: syncManager)

                        // 发现的设备列表
                        if syncManager.isBrowsing && !syncManager.discoveredPeers.isEmpty {
                            DiscoveredPeersCard(syncManager: syncManager)
                        }

                        // 使用说明
                        DeviceSyncInstructionsCard()
                    }

                    // 已连接时：显示测量结果
                    if syncManager.isConnected {
                        // 偏差结果卡片
                        OffsetResultCard(syncManager: syncManager)

                        // 操作按钮
                        SyncControlCard(syncManager: syncManager)

                        // 测量详情
                        if !syncManager.currentResults.isEmpty {
                            MeasurementDetailCard(syncManager: syncManager)
                        }

                        // 原理说明
                        HowItWorksCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
    }

    private var headerBar: some View {
        HStack {
            Text("设备对时")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { showInfo = true }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan.opacity(0.8))
            }

            if syncManager.isConnected {
                Button(action: { syncManager.stopAll() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
        .sheet(isPresented: $showInfo) {
            DeviceSyncInfoView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 连接状态卡片
struct ConnectionStatusCard: View {
    @ObservedObject var syncManager: DeviceSyncManager

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // 连接状态指示灯
                Circle()
                    .fill(syncManager.isConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .shadow(color: syncManager.isConnected ? .green : .clear, radius: 4)

                Text(syncManager.isConnected ? "已连接" : "未连接")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(syncManager.isConnected ? .green : .gray)

                Spacer()

                if syncManager.isConnected {
                    Text(syncManager.connectedPeerName ?? "")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            if syncManager.isConnected {
                // 本机名称
                HStack {
                    Text("本机")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(syncManager.peerID.displayName)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.cyan)
                }

                // 角色
                HStack {
                    Text("角色")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(syncManager.role.rawValue)
                        .font(.system(size: 13))
                        .foregroundColor(syncManager.role == .master ? .orange : .purple)
                }
            } else {
                // 本机名称
                HStack {
                    Text("本机名称")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    Spacer()
                    Text(syncManager.peerID.displayName)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }

                if syncManager.isAdvertising {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                            .scaleEffect(0.7)
                        Text("等待对方连接...")
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                } else if syncManager.isBrowsing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                            .scaleEffect(0.7)
                        Text("正在搜索附近设备...")
                            .font(.system(size: 12))
                            .foregroundColor(.cyan)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

// MARK: - 角色选择
struct RoleSelectionCard: View {
    @ObservedObject var syncManager: DeviceSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择角色")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                // 发起方
                RoleButton(
                    title: "发起方",
                    subtitle: "搜索并连接对方",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .cyan,
                    isActive: syncManager.isBrowsing,
                    action: { syncManager.startBrowsing() }
                )

                // 响应方
                RoleButton(
                    title: "响应方",
                    subtitle: "等待对方连接",
                    icon: "dot.radiowaves.up.forward",
                    color: .purple,
                    isActive: syncManager.isAdvertising,
                    action: { syncManager.startAdvertising() }
                )
            }

            Text("💡 两台设备需要分别选择不同角色，一台发起、一台响应")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.8))
                .lineSpacing(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

struct RoleButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? .white : color)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(isActive ? .white : color)

                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(isActive ? .white.opacity(0.8) : .gray)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? color : color.opacity(0.1))
            )
        }
        .disabled(isActive)
    }
}

// MARK: - 发现的设备
struct DiscoveredPeersCard: View {
    @ObservedObject var syncManager: DeviceSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("发现的设备（\(syncManager.discoveredPeers.count)）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            ForEach(syncManager.discoveredPeers, id: \.self) { peer in
                HStack {
                    Image(systemName: "iphone")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)

                    VStack(alignment: .leading) {
                        Text(peer.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text("点击连接")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Button(action: { syncManager.connect(to: peer) }) {
                        Text("连接")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.cyan)
                            )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.08))
                )
            }
        }
    }
}

// MARK: - 偏差结果卡片
struct OffsetResultCard: View {
    @ObservedObject var syncManager: DeviceSyncManager
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            // 大数字显示偏差
            HStack {
                Text("时间差")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                if syncManager.isMonitoring {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("实时监测中")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }

            // 偏差值
            Text(offsetText)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundColor(offsetColor)
                .monospacedDigit()

            Text(offsetDescription)
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Divider().background(Color.gray.opacity(0.2))

            // RTT
            HStack {
                VStack {
                    Text("往返延迟")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f ms", currentRTT * 1000))
                        .font(.system(size: 20, weight: .light, design: .monospaced))
                        .foregroundColor(rttColor)
                        .monospacedDigit()
                }

                Spacer()

                // 精度评估
                VStack {
                    Text("精度评估")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(accuracyText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accuracyColor)
                }
            }

            // 两台设备时间对比
            if syncManager.isConnected {
                Divider().background(Color.gray.opacity(0.2))

                HStack(spacing: 20) {
                    // 本机时间
                    VStack(spacing: 4) {
                        Text("本机时间")
                            .font(.system(size: 10))
                            .foregroundColor(.cyan)
                        Text(localTimeString)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        Text(millisecondString(currentDate))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.cyan)
                            .monospacedDigit()
                    }

                    // 对方时间（估算）
                    VStack(spacing: 4) {
                        Text("对方时间")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text(remoteTimeString)
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .monospacedDigit()
                        Text(millisecondString(remoteDate))
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.purple)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
        .onReceive(timer) { _ in
            currentDate = Date()
        }
    }

    private var currentOffset: Double {
        syncManager.isMonitoring ? syncManager.liveOffset : syncManager.medianOffset
    }

    private var currentRTT: Double {
        syncManager.isMonitoring ? syncManager.liveRTT : syncManager.medianRTT
    }

    private var offsetText: String {
        let ms = currentOffset * 1000
        let sign = ms >= 0 ? "+" : ""
        return String(format: "%@%.2f ms", sign, ms)
    }

    private var offsetColor: Color {
        let absMs = abs(currentOffset * 1000)
        if absMs < 5 { return .green }
        if absMs < 20 { return .yellow }
        return .red
    }

    private var offsetDescription: String {
        let ms = currentOffset * 1000
        if abs(ms) < 1 {
            return "两台设备时钟几乎完全同步 ✨"
        } else if ms > 0 {
            return String(format: "对方时钟比本机快 %.2f 毫秒", ms)
        } else {
            return String(format: "对方时钟比本机慢 %.2f 毫秒", abs(ms))
        }
    }

    private var rttColor: Color {
        let ms = currentRTT * 1000
        if ms < 10 { return .green }
        if ms < 50 { return .yellow }
        return .red
    }

    private var accuracyText: String {
        let absMs = abs(currentOffset * 1000)
        if absMs < 5 { return "极佳" }
        if absMs < 20 { return "良好" }
        if absMs < 50 { return "一般" }
        return "较差"
    }

    private var accuracyColor: Color {
        let absMs = abs(currentOffset * 1000)
        if absMs < 5 { return .green }
        if absMs < 20 { return .yellow }
        if absMs < 50 { return .orange }
        return .red
    }

    private var localTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: currentDate)
    }

    private var remoteDate: Date {
        // 对方时间 = 本机时间 + 偏差（对方时钟偏快则加正值）
        currentDate.addingTimeInterval(currentOffset)
    }

    private var remoteTimeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: remoteDate)
    }

    private func millisecondString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = ".SSS"
        return f.string(from: date)
    }
}

// MARK: - 操作控制
struct SyncControlCard: View {
    @ObservedObject var syncManager: DeviceSyncManager
    @State private var roundCount: Int = 10

    var body: some View {
        VStack(spacing: 12) {
            // 测量轮数选择
            HStack {
                Text("测量轮数")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                Spacer()

                Picker("", selection: $roundCount) {
                    Text("5 轮").tag(5)
                    Text("10 轮").tag(10)
                    Text("20 轮").tag(20)
                    Text("50 轮").tag(50)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(syncManager.isSyncing || syncManager.isMonitoring)
            }

            HStack(spacing: 12) {
                // 单次测量
                Button(action: {
                    syncManager.startSyncMeasurement(rounds: roundCount)
                }) {
                    HStack {
                        if syncManager.isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "ruler")
                        }
                        Text(syncManager.isSyncing ? "测量中..." : "精确测量")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(syncManager.isSyncing ? Color.gray : Color.cyan)
                    )
                }
                .disabled(syncManager.isSyncing || syncManager.role != .master)

                // 持续监测
                Button(action: {
                    if syncManager.isMonitoring {
                        syncManager.stopMonitoring()
                    } else {
                        syncManager.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: syncManager.isMonitoring ? "stop.circle" : "waveform.path.ecg")
                        Text(syncManager.isMonitoring ? "停止监测" : "持续监测")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(syncManager.isMonitoring ? Color.red : Color.purple)
                    )
                }
                .disabled(syncManager.role != .master)
            }

            if syncManager.role != .master {
                Text("💡 只有「发起方」可以主动测量，「响应方」会自动显示结果")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.8))
                    .lineSpacing(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

// MARK: - 测量详情
struct MeasurementDetailCard: View {
    @ObservedObject var syncManager: DeviceSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("测量详情（共 \(syncManager.currentResults.count) 轮）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            // 偏差分布图
            OffsetDistributionChart(results: syncManager.currentResults, medianOffset: syncManager.medianOffset)
                .frame(height: 60)
                .padding(.vertical, 4)

            // 统计信息
            HStack(spacing: 20) {
                StatItem(label: "最小偏差", value: String(format: "%.1fms", minOffsetMs), color: .green)
                StatItem(label: "最大偏差", value: String(format: "%.1fms", maxOffsetMs), color: .red)
                StatItem(label: "平均偏差", value: String(format: "%.1fms", avgOffsetMs), color: .yellow)
                StatItem(label: "中位数", value: String(format: "%.1fms", syncManager.medianOffset * 1000), color: .cyan)
            }

            // 最近几轮结果
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(syncManager.currentResults.suffix(20)) { result in
                        ResultDot(result: result)
                    }
                }
            }
            .frame(height: 30)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }

    private var minOffsetMs: Double {
        syncManager.currentResults.map { abs($0.offsetMs) }.min() ?? 0
    }

    private var maxOffsetMs: Double {
        syncManager.currentResults.map { abs($0.offsetMs) }.max() ?? 0
    }

    private var avgOffsetMs: Double {
        let values = syncManager.currentResults.map { abs($0.offsetMs) }
        return values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(color)
                .monospacedDigit()
        }
    }
}

struct ResultDot: View {
    let result: DeviceSyncResult

    var body: some View {
        let absMs = abs(result.offsetMs)
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(dotColor)
                .frame(width: 4, height: max(4, min(24, CGFloat(absMs) / 2)))
            Text("\(result.round)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    private var dotColor: Color {
        let absMs = abs(result.offsetMs)
        if absMs < 5 { return .green }
        if absMs < 20 { return .yellow }
        return .red
    }
}

// MARK: - 偏差分布图
struct OffsetDistributionChart: View {
    let results: [DeviceSyncResult]
    let medianOffset: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let maxMs = max(results.map { abs($0.offsetMs) }.max() ?? 50, 10)
            let centerX = w / 2

            ZStack {
                // 中心线
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 1, height: h)
                    .position(x: centerX, y: h / 2)

                // 每个测量点
                ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                    let xOffset = CGFloat(result.offsetMs / maxMs) * (w / 2 - 10)
                    let yPosition = CGFloat(index) / CGFloat(max(results.count - 1, 1)) * (h - 8) + 4

                    Circle()
                        .fill(dotColor(result.offsetMs))
                        .frame(width: 6, height: 6)
                        .position(x: centerX + xOffset, y: yPosition)
                }

                // 中位数线
                let medianX = CGFloat(medianOffset * 1000 / maxMs) * (w / 2 - 10)
                Rectangle()
                    .fill(Color.cyan)
                    .frame(width: 2, height: h)
                    .position(x: centerX + medianX, y: h / 2)
            }
        }
    }

    private func dotColor(_ offsetMs: Double) -> Color {
        let absMs = abs(offsetMs)
        if absMs < 5 { return .green }
        if absMs < 20 { return .yellow }
        return .red
    }
}

// MARK: - 使用说明
struct DeviceSyncInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用方法")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Label("两台设备都打开此页面", systemImage: "1.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("一台选「发起方」，另一台选「响应方」", systemImage: "2.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("发起方搜索到对方后点击「连接」", systemImage: "3.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("连接后点击「精确测量」查看时间差", systemImage: "4.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Divider().background(Color.gray.opacity(0.2))

            VStack(alignment: .leading, spacing: 4) {
                Text("连接方式（自动选择）")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 16) {
                    Label("Wi-Fi 直连", systemImage: "wifi")
                    Label("蓝牙", systemImage: "wave.3.right")
                    Label("同一局域网", systemImage: "network")
                }
                .font(.system(size: 10))
                .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - 原理说明
struct HowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.cyan)
                Text("测量原理")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            Text("使用类似 NTP 的算法，通过多次测量取中位数：")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            // 简化的时序图
            MiniSequenceDiagram()
                .frame(height: 100)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text("offset = t₂ − (t₁ + t₄) / 2")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.white)
                Text("RTT = t₄ − t₁（往返延迟）")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.05)))

            Text("💡 RTT 越小，测量越精确。建议在 Wi-Fi 直连下使用。")
                .font(.system(size: 11))
                .foregroundColor(.yellow.opacity(0.7))
                .lineSpacing(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

struct MiniSequenceDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let leftX = w * 0.2
            let rightX = w * 0.8
            let topY: CGFloat = 10
            let bottomY = h - 10

            ZStack {
                // 标签
                Text("发起方")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.cyan)
                    .position(x: leftX, y: 5)

                Text("响应方")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.purple)
                    .position(x: rightX, y: 5)

                // 生命线
                Rectangle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 1, height: bottomY - topY - 10)
                    .position(x: leftX, y: (topY + bottomY) / 2 + 5)

                Rectangle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 1, height: bottomY - topY - 10)
                    .position(x: rightX, y: (topY + bottomY) / 2 + 5)

                // 请求箭头 t1 → t2
                let y1 = topY + 20
                Path { p in
                    p.move(to: CGPoint(x: leftX + 3, y: y1))
                    p.addLine(to: CGPoint(x: rightX - 3, y: y1 + 15))
                }
                .stroke(Color.cyan, lineWidth: 1)

                Text("t₁ →")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                    .position(x: leftX + 20, y: y1 - 6)

                // 响应箭头 t2 → t4
                let y2 = y1 + 25
                Path { p in
                    p.move(to: CGPoint(x: rightX - 3, y: y2))
                    p.addLine(to: CGPoint(x: leftX + 3, y: y2 + 15))
                }
                .stroke(Color.purple, lineWidth: 1)

                Text("← t₂")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.purple)
                    .position(x: rightX - 20, y: y2 - 6)

                Text("t₄ 收到")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                    .position(x: leftX + 25, y: y2 + 20)
            }
        }
    }
}

// MARK: - 设备对时介绍页
struct DeviceSyncInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 标题
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("返回")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Image(systemName: "two.iphones")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                }

                // 什么是设备对时
                InfoCard(title: "什么是设备对时？", icon: "two.iphones", color: .cyan) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("设备对时功能允许两台 Apple 设备（iPhone、iPad、Mac）通过 Wi-Fi 或蓝牙直接比较各自的系统时钟差异，精度可达毫秒级。")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(4)

                        Divider().background(Color.gray.opacity(0.3))

                        BulletRow(text: "无需 NTP 服务器，两台设备直接通信")
                        BulletRow(text: "使用 Apple MultipeerConnectivity 框架")
                        BulletRow(text: "自动选择 Wi-Fi 直连、蓝牙或同一局域网")
                        BulletRow(text: "精度取决于网络延迟，Wi-Fi 直连可达 ±1~5ms")
                    }
                }

                // 工作原理
                InfoCard(title: "工作原理", icon: "arrow.triangle.2.circlepath", color: .purple) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("采用类似 NTP 的算法，但直接在两台设备间进行：")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(4)

                        // 时序图
                        DeviceSyncSequenceDiagram()
                            .frame(height: 200)
                            .padding(.vertical, 8)

                        VStack(spacing: 6) {
                            TimestampRow(label: "t₁", desc: "发起方发送请求的时间", color: .cyan)
                            TimestampRow(label: "t₂", desc: "响应方收到请求的时间", color: .purple)
                            TimestampRow(label: "t₄", desc: "发起方收到回复的时间", color: .cyan)
                        }

                        Divider().background(Color.gray.opacity(0.3))

                        FormulaCard(
                            title: "时钟偏差",
                            formula: "offset = t₂ − (t₁ + t₄) / 2",
                            explanation: "正值 = 对方时钟偏快，负值 = 对方时钟偏慢"
                        )

                        FormulaCard(
                            title: "往返延迟",
                            formula: "RTT = t₄ − t₁",
                            explanation: "RTT 越小，测量结果越可靠"
                        )
                    }
                }

                // 影响精度的因素
                InfoCard(title: "影响精度的因素", icon: "gauge", color: .orange) {
                    VStack(alignment: .leading, spacing: 10) {
                        ProItem(icon: "wifi", title: "Wi-Fi 直连（最佳）", desc: "两台设备在同一房间，RTT 通常 <5ms，精度 ±1~3ms")
                        ProItem(icon: "wave.3.right", title: "蓝牙连接", desc: "RTT 约 20~50ms，精度 ±10~20ms")
                        ProItem(icon: "network", title: "同一局域网", desc: "通过路由器中转，RTT 约 5~20ms，精度 ±3~10ms")
                        ConItem(icon: "globe", title: "互联网连接", desc: "不支持，MultipeerConnectivity 仅限本地通信")
                    }
                }

                // 与 NTP 对时的区别
                InfoCard(title: "与 NTP 对时的区别", icon: "arrow.left.arrow.right", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        ComparisonRow(item: "NTP 对时", desc: "各自与远程服务器对比，精度受网络影响", color: .cyan)
                        ComparisonRow(item: "设备对时", desc: "两台设备直接对比，精度取决于本地网络", color: .purple)
                        Divider().background(Color.gray.opacity(0.3))
                        Text("💡 最佳实践：先用 NTP 对时校准两台设备到同一标准时间，再用设备对时验证精度。")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow.opacity(0.8))
                            .lineSpacing(3)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct DeviceSyncSequenceDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let leftX = w * 0.22
            let rightX = w * 0.78
            let topY: CGFloat = 30
            let bottomY = h - 10

            ZStack {
                // 设备标签
                VStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 18))
                        .foregroundColor(.cyan)
                    Text("发起方 (Master)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                }
                .position(x: leftX, y: 14)

                VStack(spacing: 4) {
                    Image(systemName: "macbook")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                    Text("响应方 (Slave)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.purple)
                }
                .position(x: rightX, y: 14)

                // 生命线
                Rectangle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 2, height: bottomY - topY)
                    .position(x: leftX, y: (topY + bottomY) / 2)

                Rectangle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 2, height: bottomY - topY)
                    .position(x: rightX, y: (topY + bottomY) / 2)

                // t1: 发送请求
                let y1 = topY + 20
                Path { p in
                    p.move(to: CGPoint(x: leftX + 3, y: y1))
                    p.addLine(to: CGPoint(x: rightX - 3, y: y1 + 30))
                }
                .stroke(Color.cyan, style: StrokeStyle(lineWidth: 1.5))

                Text("t₁  发送请求")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
                    .position(x: leftX + 40, y: y1 - 8)

                // t2: 收到并立即回复
                let y2 = y1 + 30
                Path { p in
                    p.move(to: CGPoint(x: rightX - 3, y: y2 + 10))
                    p.addLine(to: CGPoint(x: leftX + 3, y: y2 + 40))
                }
                .stroke(Color.purple, style: StrokeStyle(lineWidth: 1.5))

                Text("t₂  收到 → 立即回复")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.purple)
                    .position(x: rightX - 50, y: y2 + 2)

                // t4: 收到回复
                let y4 = y2 + 40
                Text("t₄  收到回复 → 计算偏差")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
                    .position(x: leftX + 60, y: y4 + 10)

                // RTT 标注
                let midY = (y1 + y4) / 2
                Text("RTT = t₄ − t₁")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.orange)
                    .position(x: w / 2, y: midY + 15)
            }
        }
    }
}

struct ComparisonRow: View {
    let item: String
    let desc: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 2) {
                Text(item)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(color)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

struct DeviceSyncView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceSyncView()
    }
}
