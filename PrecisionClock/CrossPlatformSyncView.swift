import SwiftUI

struct CrossPlatformSyncView: View {
    @StateObject private var syncManager = CrossPlatformSyncManager()
    @State private var serverIPInput: String = ""
    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            ScrollView {
                VStack(spacing: 16) {
                    // 连接状态
                    CPConnectionStatusCard(syncManager: syncManager)

                    if !syncManager.isConnected {
                        // 角色选择
                        CPRoleSelectionCard(syncManager: syncManager)

                        // Server 模式：显示 IP
                        if syncManager.role == .server && syncManager.isListening {
                            ServerInfoCard(syncManager: syncManager)
                        }

                        // Client 模式：输入 IP
                        if syncManager.role == .client {
                            ClientConnectCard(
                                syncManager: syncManager,
                                serverIP: $serverIPInput
                            )
                        }

                        // 使用说明
                        CrossPlatformInstructionsCard()
                    }

                    // 已连接：显示结果
                    if syncManager.isConnected {
                        CrossPlatformOffsetResultCard(syncManager: syncManager)
                        CrossPlatformSyncControlCard(syncManager: syncManager)

                        if !syncManager.currentResults.isEmpty {
                            CrossPlatformMeasurementDetailCard(syncManager: syncManager)
                        }

                        CrossPlatformHowItWorksCard()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black.ignoresSafeArea())
        }
        .preferredColorScheme(.dark)
        .onAppear {
            syncManager.updateLocalIPAddress()
        }
    }

    private var headerBar: some View {
        HStack {
            Text("跨平台对时")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: { showInfo = true }) {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundColor(.cyan.opacity(0.8))
            }

            if syncManager.isConnected || syncManager.isListening {
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
            CrossPlatformInfoView()
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - 连接状态卡片
struct CPConnectionStatusCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Circle()
                    .fill(syncManager.isConnected ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 10, height: 10)
                    .shadow(color: syncManager.isConnected ? .green : .clear, radius: 4)

                Text(syncManager.connectionStatus)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(syncManager.isConnected ? .green : .gray)

                Spacer()

                if syncManager.role != .none {
                    Text(syncManager.role.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(syncManager.role == .server ? .purple : .cyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(syncManager.role == .server ? Color.purple.opacity(0.2) : Color.cyan.opacity(0.2))
                        )
                }
            }

            if let error = syncManager.lastError {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
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
struct CPRoleSelectionCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择角色")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            HStack(spacing: 12) {
                RoleButton(
                    title: "服务端",
                    subtitle: "等待 Android 连接",
                    icon: "server.rack",
                    color: .purple,
                    isActive: syncManager.isListening,
                    action: { syncManager.startServer() }
                )

                RoleButton(
                    title: "客户端",
                    subtitle: "连接 Android 服务端",
                    icon: "antenna.radiowaves.left.and.right",
                    color: .cyan,
                    isActive: syncManager.role == .client && !syncManager.isConnected,
                    action: { /* 需要输入 IP 后才能启动 */ }
                )
            }

            Text("💡 两台设备需选择不同角色，确保在同一局域网内")
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

// MARK: - Server 信息卡片
struct ServerInfoCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("服务端信息")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            // IP 地址
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本机 IP 地址")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                    Text(syncManager.localIPAddress)
                        .font(.system(size: 24, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .monospacedDigit()
                }

                Spacer()

                // 刷新按钮
                Button(action: { syncManager.updateLocalIPAddress() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 16))
                        .foregroundColor(.cyan)
                }
            }

            // 端口
            HStack {
                Text("端口")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                Spacer()
                Text("\(syncManager.port)")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }

            Divider().background(Color.gray.opacity(0.2))

            // 提示
            VStack(alignment: .leading, spacing: 6) {
                Text("Android 端操作：")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.purple)
                Text("1. 打开 Android 对时 APP")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text("2. 选择「客户端」角色")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text("3. 输入上面的 IP 地址")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                Text("4. 点击「连接」")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Client 连接卡片
struct ClientConnectCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager
    @Binding var serverIP: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("连接服务端")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            // IP 输入
            HStack {
                Text("服务端 IP:")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                TextField("例如: 192.168.1.100", text: $serverIP)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.1))
                    )
            }

            // 连接按钮
            Button(action: {
                syncManager.startClient(serverIP: serverIP)
            }) {
                HStack {
                    Image(systemName: "link")
                    Text("连接")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(serverIP.isEmpty ? Color.gray : Color.cyan)
                )
            }
            .disabled(serverIP.isEmpty)

            Divider().background(Color.gray.opacity(0.2))

            Text("💡 请确保 Android 设备已启动服务端，并输入其显示的 IP 地址")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.8))
                .lineSpacing(2)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 偏差结果卡片
struct CrossPlatformOffsetResultCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager
    @State private var currentDate = Date()
    private let timer = Timer.publish(every: 0.01, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("时间差")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                Spacer()
                if syncManager.isMonitoring {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 6, height: 6)
                        Text("实时监测中")
                            .font(.system(size: 11))
                            .foregroundColor(.green)
                    }
                }
            }

            Text(offsetText)
                .font(.system(size: 48, weight: .thin, design: .monospaced))
                .foregroundColor(offsetColor)
                .monospacedDigit()

            Text(offsetDescription)
                .font(.system(size: 13))
                .foregroundColor(.gray)

            Divider().background(Color.gray.opacity(0.2))

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

                VStack {
                    Text("精度评估")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                    Text(accuracyText)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(accuracyColor)
                }
            }

            if syncManager.isConnected {
                Divider().background(Color.gray.opacity(0.2))

                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("iOS 时间")
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

                    VStack(spacing: 4) {
                        Text("Android 时间")
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
            return String(format: "Android 时钟比 iOS 快 %.2f 毫秒", ms)
        } else {
            return String(format: "Android 时钟比 iOS 慢 %.2f 毫秒", abs(ms))
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
struct CrossPlatformSyncControlCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager
    @State private var roundCount: Int = 10

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("测量轮数")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)

                Spacer()

                Picker("", selection: $roundCount) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("20").tag(20)
                    Text("50").tag(50)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .disabled(syncManager.isSyncing || syncManager.isMonitoring)
            }

            HStack(spacing: 12) {
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
                .disabled(syncManager.isSyncing || syncManager.role != .client)

                Button(action: {
                    if syncManager.isMonitoring {
                        syncManager.stopMonitoring()
                    } else {
                        syncManager.startMonitoring()
                    }
                }) {
                    HStack {
                        Image(systemName: syncManager.isMonitoring ? "stop.circle" : "waveform.path.ecg")
                        Text(syncManager.isMonitoring ? "停止" : "监测")
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
                .disabled(syncManager.role != .client)
            }

            if syncManager.role != .client {
                Text("💡 只有「客户端」可以主动发起测量")
                    .font(.system(size: 11))
                    .foregroundColor(.gray.opacity(0.8))
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
struct CrossPlatformMeasurementDetailCard: View {
    @ObservedObject var syncManager: CrossPlatformSyncManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("测量详情（\(syncManager.currentResults.count) 轮）")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)

            HStack(spacing: 16) {
                StatItem(label: "最小", value: String(format: "%.1fms", minOffsetMs), color: .green)
                StatItem(label: "最大", value: String(format: "%.1fms", maxOffsetMs), color: .red)
                StatItem(label: "平均", value: String(format: "%.1fms", avgOffsetMs), color: .yellow)
                StatItem(label: "中位数", value: String(format: "%.1fms", syncManager.medianOffset * 1000), color: .cyan)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(syncManager.currentResults.suffix(20)) { result in
                        CPResultDot(result: result)
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

// MARK: - 使用说明
struct CrossPlatformInstructionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("使用方法")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Label("iOS 和 Android 设备连接到同一 Wi-Fi", systemImage: "wifi")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("iOS 选择「服务端」，记录显示的 IP 地址", systemImage: "1.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("Android 选择「客户端」，输入 iOS 的 IP", systemImage: "2.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)
            Label("连接后，Android 端点击「精确测量」", systemImage: "3.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(.gray)

            Divider().background(Color.gray.opacity(0.2))

            Text("通信协议")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
            HStack(spacing: 12) {
                Label("TCP", systemImage: "cable.connector")
                Label("端口 12345", systemImage: "number")
            }
            .font(.system(size: 10))
            .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.06))
        )
    }
}

// MARK: - 原理说明
struct CrossPlatformHowItWorksCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "function")
                    .foregroundColor(.cyan)
                Text("测量原理")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            Text("使用类 NTP 算法，通过 TCP 在局域网内直接测量：")
                .font(.system(size: 12))
                .foregroundColor(.gray)

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

            Text("💡 局域网内 RTT 通常 <5ms，精度可达 ±1~3ms")
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

// MARK: - 信息页
struct CrossPlatformInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
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

                    Image(systemName: "apple.logo")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Image(systemName: "android.logo")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }

                InfoCard(title: "跨平台对时", icon: "arrow.left.arrow.right", color: .cyan) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("通过局域网 TCP Socket 实现 iOS 与 Android 设备之间的时钟偏差测量，精度可达毫秒级。")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.85))
                            .lineSpacing(4)

                        Divider().background(Color.gray.opacity(0.3))

                        BulletRow(text: "使用 TCP Socket 通信（端口 12345）")
                        BulletRow(text: "类 NTP 算法，多轮测量取中位数")
                        BulletRow(text: "局域网内精度 ±1~5ms")
                        BulletRow(text: "支持 iOS ↔ Android 双向测量")
                    }
                }

                InfoCard(title: "通信协议", icon: "doc.text", color: .orange) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("消息格式（JSON，换行符分隔）：")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)

                        CodeBlock(text: """
                        // 请求 (Client → Server)
                        {"type":"syncRequest","t1":1234567890.123}

                        // 响应 (Server → Client)
                        {"type":"syncResponse","t1":...,"t2":...}

                        // 结果 (Client → Server)
                        {"type":"syncResult","offset":0.001}
                        """)
                    }
                }

                InfoCard(title: "Android 端实现", icon: "android.logo", color: .green) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Android 端需要：")
                            .font(.system(size: 13))
                            .foregroundColor(.white)

                        BulletRow(text: "使用 Kotlin + ServerSocket/Socket")
                        BulletRow(text: "实现相同的 JSON 协议")
                        BulletRow(text: "显示本机 IP 和连接状态")
                        BulletRow(text: "支持服务端/客户端两种角色")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct CodeBlock: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.green.opacity(0.8))
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.5))
            )
    }
}

// MARK: - 跨平台结果点
struct CPResultDot: View {
    let result: CrossPlatformSyncResult

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

struct CrossPlatformSyncView_Previews: PreviewProvider {
    static var previews: some View {
        CrossPlatformSyncView()
    }
}
