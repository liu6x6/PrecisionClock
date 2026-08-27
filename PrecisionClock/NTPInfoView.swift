import SwiftUI

struct NTPInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 标题
                headerSection

                // 1. 什么是 NTP
                whatIsNTPSection

                // 2. 工作原理（时序图）
                howItWorksSection

                // 3. 报文结构
                packetStructureSection

                // 4. 时间偏差计算
                calculationSection

                // 5. Stratum 层级
                stratumSection

                // 6. 优点
                prosSection

                // 7. 缺点
                consSection

                // 8. 在本应用中的使用
                inThisAppSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Header
    private var headerSection: some View {
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

            Image(systemName: "globe")
                .font(.system(size: 20))
                .foregroundColor(.cyan)
        }
        .padding(.bottom, 4)
    }

    // MARK: - 1. 什么是 NTP
    private var whatIsNTPSection: some View {
        InfoCard(title: "什么是 NTP？", icon: "globe", color: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                Text("NTP（Network Time Protocol，网络时间协议）是一种用于在计算机网络中同步时钟的协议。它于 1985 年由 David Mills 博士设计，是互联网上最古老、使用最广泛的协议之一。")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                Divider().background(Color.gray.opacity(0.3))

                HStack(spacing: 16) {
                    InfoBadge(text: "RFC 5905", color: .cyan)
                    InfoBadge(text: "UDP 端口 123", color: .orange)
                    InfoBadge(text: "NTP v4", color: .green)
                }

                Divider().background(Color.gray.opacity(0.3))

                Text("NTP 的核心目标")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                BulletRow(text: "将客户端时钟与标准时间源同步")
                BulletRow(text: "精度可达毫秒级（局域网内 <1ms，互联网 <50ms）")
                BulletRow(text: "全球数十亿设备依赖 NTP 进行时间同步")
            }
        }
    }

    // MARK: - 2. 工作原理
    private var howItWorksSection: some View {
        InfoCard(title: "工作原理", icon: "arrow.triangle.2.circlepath", color: .cyan) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NTP 采用客户端-服务器模型，通过交换时间戳报文来计算时间偏差。一次完整的 NTP 查询包含 4 个关键时间点：")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                // 时序图
                NTPSequenceDiagram()
                    .frame(height: 320)
                    .padding(.vertical, 8)

                // 四个时间点说明
                VStack(spacing: 8) {
                    TimestampRow(label: "t₁", desc: "客户端发送请求的时间", color: .cyan)
                    TimestampRow(label: "t₂", desc: "服务器收到请求的时间", color: .green)
                    TimestampRow(label: "t₃", desc: "服务器发送响应的时间", color: .green)
                    TimestampRow(label: "t₄", desc: "客户端收到响应的时间", color: .cyan)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 3. 报文结构
    private var packetStructureSection: some View {
        InfoCard(title: "NTP 报文结构", icon: "doc.text", color: .orange) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NTP 报文固定 48 字节（NTP v4），通过 UDP 传输：")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                // 报文结构图
                NTPPacketDiagram()
                    .frame(height: 200)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 6) {
                    FieldRow(bytes: "0", bits: "LI|VN|Mode", desc: "LI=0, VN=4, Mode=3(客户端)", highlight: true)
                    FieldRow(bytes: "1", bits: "Stratum", desc: "层级（1=主时钟, 2=从时钟...）")
                    FieldRow(bytes: "2", bits: "Poll", desc: "轮询间隔（2的幂次秒）")
                    FieldRow(bytes: "3", bits: "Precision", desc: "时钟精度")
                    FieldRow(bytes: "4-7", bits: "Root Delay", desc: "到参考源的总往返延迟")
                    FieldRow(bytes: "8-11", bits: "Root Dispersion", desc: "到参考源的总色散")
                    FieldRow(bytes: "12-15", bits: "Reference ID", desc: "参考时钟标识符")
                    FieldRow(bytes: "16-23", bits: "Reference Timestamp", desc: "参考时钟最后设置时间")
                    FieldRow(bytes: "24-31", bits: "Origin Timestamp", desc: " originate 时间戳")
                    FieldRow(bytes: "32-39", bits: "Receive Timestamp", desc: "接收时间戳 (t₂)")
                    FieldRow(bytes: "40-47", bits: "Transmit Timestamp", desc: "发送时间戳 (t₃)", highlight: true)
                }
            }
        }
    }

    // MARK: - 4. 时间偏差计算
    private var calculationSection: some View {
        InfoCard(title: "时间偏差计算", icon: "function", color: .green) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NTP 使用经典算法，通过 4 个时间戳计算时钟偏差和网络延迟：")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                // 计算公式图
                FormulaCard(
                    title: "时钟偏差 (Offset)",
                    formula: "θ = ((t₂ − t₁) + (t₃ − t₄)) / 2",
                    explanation: "正值表示客户端时钟偏慢，负值表示偏快"
                )

                FormulaCard(
                    title: "往返延迟 (RTT)",
                    formula: "δ = (t₄ − t₁) − (t₃ − t₂)",
                    explanation: "报文在网络中的总传输时间"
                )

                // 可视化解释
                OffsetVisualization()
                    .frame(height: 160)
                    .padding(.vertical, 4)

                Text("💡 为了提高精度，本应用对每个时钟源进行多次测量，取偏移量的中位数作为最终结果，有效减少网络抖动的影响。")
                    .font(.system(size: 13))
                    .foregroundColor(.yellow.opacity(0.8))
                    .lineSpacing(3)
            }
        }
    }

    // MARK: - 5. Stratum 层级
    private var stratumSection: some View {
        InfoCard(title: "Stratum 层级体系", icon: "layer", color: .purple) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NTP 使用分层（Stratum）体系组织时间源，层级数字越小精度越高：")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                // Stratum 层级图
                StratumDiagram()
                    .frame(height: 340)
                    .padding(.vertical, 4)

                VStack(spacing: 6) {
                    StratumRow(stratum: "0", name: "参考源", desc: "原子钟、GPS 卫星等物理设备", color: .yellow)
                    StratumRow(stratum: "1", name: "主时钟", desc: "直接连接参考源，如 time.apple.com", color: .green)
                    StratumRow(stratum: "2", name: "从时钟", desc: "同步自 Stratum 1，如 pool.ntp.org", color: .cyan)
                    StratumRow(stratum: "3+", name: "下级时钟", desc: "逐级同步，精度递减", color: .gray)
                }
            }
        }
    }

    // MARK: - 6. 优点
    private var prosSection: some View {
        InfoCard(title: "NTP 的优点", icon: "checkmark.circle", color: .green) {
            VStack(alignment: .leading, spacing: 10) {
                ProItem(icon: "network", title: "广泛部署", desc: "互联网基础设施，几乎所有操作系统和设备都内置支持")
                ProItem(icon: "globe", title: "全球覆盖", desc: "全球数万个公共 NTP 服务器，随时随地可用")
                ProItem(icon: "bolt", title: "轻量高效", desc: "仅 48 字节 UDP 报文，网络开销极小")
                ProItem(icon: "arrow.triangle.2.circlepath", title: "持续同步", desc: "支持周期性自动同步，时钟漂移持续校正")
                ProItem(icon: "shield", title: "成熟可靠", desc: "30+ 年历史，经过充分验证和优化的协议")
                ProItem(icon: "clock", title: "毫秒级精度", desc: "互联网环境下通常可达 ±10~50ms 精度")
                ProItem(icon: "arrow.branch", title: "容错性强", desc: "支持多个时间源，自动选择最优路径")
            }
        }
    }

    // MARK: - 7. 缺点
    private var consSection: some View {
        InfoCard(title: "NTP 的缺点", icon: "exclamationmark.triangle", color: .red) {
            VStack(alignment: .leading, spacing: 10) {
                ConItem(icon: "wifi.slash", title: "网络依赖", desc: "精度受网络延迟影响大，高延迟/不稳定网络下精度显著下降")
                ConItem(icon: "lock.open", title: "安全风险", desc: "传统 NTP 无认证机制，易受中间人攻击和时间欺骗攻击（NTPsec 可缓解）")
                ConItem(icon: "antenna.radiowaves.left.and.right", title: "UDP 端口封锁", desc: "部分企业网络或防火墙封锁 UDP 123 端口，导致无法使用")
                ConItem(icon: "timer", title: "精度有限", desc: "互联网环境下精度通常在 10~100ms，不适合微秒级需求")
                ConItem(icon: "arrow.left.arrow.right", title: "非对称延迟", desc: "上下行网络延迟不对称时，偏移计算会产生误差")
                ConItem(icon: "server.rack", title: "服务器负载", desc: "公共 NTP 服务器高峰期可能响应慢或拒绝服务")
                ConItem(icon: "iphone.slash", title: "移动端限制", desc: "iOS/macOS 对后台网络请求有限制，影响持续同步")
            }
        }
    }

    // MARK: - 8. 在本应用中的使用
    private var inThisAppSection: some View {
        InfoCard(title: "在本应用中的使用", icon: "app", color: .cyan) {
            VStack(alignment: .leading, spacing: 10) {
                Text("PrecisionClock 实现了简化的 NTP v4 客户端：")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(4)

                BulletRow(text: "使用 Network.framework 的 NWConnection 发送 UDP 报文")
                BulletRow(text: "提供 21 个全球时钟源（Apple、Google、AWS、Android、阿里云等）")
                BulletRow(text: "每个时钟源进行 3~5 轮测量，取中位数提高精度")
                BulletRow(text: "计算时间偏差后，校准显示时间 = Date() − offset")
                BulletRow(text: "偏差可视化：绿色 <10ms / 黄色 <50ms / 红色 >50ms")

                Divider().background(Color.gray.opacity(0.3))

                Text("💡 提示：两台设备选择相同且偏差最小的时钟源，即可获得最佳同步效果。")
                    .font(.system(size: 13))
                    .foregroundColor(.yellow.opacity(0.8))
                    .lineSpacing(3)
            }
        }
    }
}

// MARK: - NTP 时序图
struct NTPSequenceDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let leftX = w * 0.25
            let rightX = w * 0.75
            let topY: CGFloat = 40
            let bottomY = h - 20

            ZStack {
                // 客户端标签
                VStack(spacing: 4) {
                    Image(systemName: "iphone")
                        .font(.system(size: 20))
                        .foregroundColor(.cyan)
                    Text("客户端")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.cyan)
                }
                .position(x: leftX, y: 18)

                // 服务器标签
                VStack(spacing: 4) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 20))
                        .foregroundColor(.green)
                    Text("NTP 服务器")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.green)
                }
                .position(x: rightX, y: 18)

                // 客户端生命线
                Rectangle()
                    .fill(Color.cyan.opacity(0.3))
                    .frame(width: 2, height: bottomY - topY)
                    .position(x: leftX, y: (topY + bottomY) / 2)

                // 服务器生命线
                Rectangle()
                    .fill(Color.green.opacity(0.3))
                    .frame(width: 2, height: bottomY - topY)
                    .position(x: rightX, y: (topY + bottomY) / 2)

                // t1: 客户端发送请求
                let y1 = topY + (bottomY - topY) * 0.15
                ArrowLine(
                    from: CGPoint(x: leftX + 4, y: y1),
                    to: CGPoint(x: rightX - 4, y: y1 + 50),
                    color: .cyan,
                    dashed: false
                )
                LabelTag(text: "t₁  发送请求", position: CGPoint(x: leftX + 10, y: y1 - 12), color: .cyan)

                // t2: 服务器收到
                let y2 = y1 + 50
                LabelTag(text: "t₂  收到请求", position: CGPoint(x: rightX - 90, y: y2 - 12), color: .green)

                // t3: 服务器发送响应
                let y3 = y2 + 40
                ArrowLine(
                    from: CGPoint(x: rightX - 4, y: y3),
                    to: CGPoint(x: leftX + 4, y: y3 + 50),
                    color: .green,
                    dashed: false
                )
                LabelTag(text: "t₃  发送响应", position: CGPoint(x: rightX + 6, y: y3 - 12), color: .green)

                // t4: 客户端收到响应
                let y4 = y3 + 50
                LabelTag(text: "t₄  收到响应", position: CGPoint(x: leftX - 10, y: y4 - 12), color: .cyan)

                // 网络延迟标注
                let midY = (y1 + y2) / 2
                Text("网络延迟 →")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))
                    .position(x: (leftX + rightX) / 2, y: midY + 18)

                let midY2 = (y3 + y4) / 2
                Text("← 网络延迟")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))
                    .position(x: (leftX + rightX) / 2, y: midY2 + 18)
            }
        }
    }
}

// MARK: - 箭头线
struct ArrowLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    let dashed: Bool

    var body: some View {
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowSize: CGFloat = 8

        ZStack {
            Path { path in
                path.move(to: from)
                path.addLine(to: to)
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, dash: dashed ? [4, 3] : []))

            // 箭头
            Path { path in
                path.move(to: to)
                path.addLine(to: CGPoint(
                    x: to.x - arrowSize * cos(angle - .pi / 6),
                    y: to.y - arrowSize * sin(angle - .pi / 6)
                ))
                path.move(to: to)
                path.addLine(to: CGPoint(
                    x: to.x - arrowSize * cos(angle + .pi / 6),
                    y: to.y - arrowSize * sin(angle + .pi / 6)
                ))
            }
            .stroke(color, lineWidth: 1.5)
        }
    }
}

// MARK: - 标签
struct LabelTag: View {
    let text: String
    let position: CGPoint
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .position(x: position.x, y: position.y)
    }
}

// MARK: - NTP 报文结构图
struct NTPPacketDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let cellH: CGFloat = 22
            let labelW: CGFloat = 50

            VStack(alignment: .leading, spacing: 2) {
                // 字节 0
                PacketRow(label: "Byte 0", bits: "LI(2) | VN(3) | Mode(3)", color: .cyan, width: w)
                // 字节 1-3
                PacketRow(label: "Byte 1-3", bits: "Stratum | Poll | Precision", color: .orange, width: w)
                // 字节 4-15
                PacketRow(label: "Byte 4-15", bits: "Root Delay | Root Dispersion | Ref ID", color: .gray, width: w)
                // 字节 16-23
                PacketRow(label: "Byte 16-23", bits: "Reference Timestamp", color: .gray, width: w)
                // 字节 24-31
                PacketRow(label: "Byte 24-31", bits: "Origin Timestamp (t₁)", color: .gray, width: w)
                // 字节 32-39
                PacketRow(label: "Byte 32-39", bits: "Receive Timestamp (t₂)", color: .green, width: w)
                // 字节 40-47
                PacketRow(label: "Byte 40-47", bits: "Transmit Timestamp (t₃)", color: .cyan, width: w)
            }
        }
    }
}

struct PacketRow: View {
    let label: String
    let bits: String
    let color: Color
    let width: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 60, alignment: .trailing)

            RoundedRectangle(cornerRadius: 3)
                .fill(color.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(color.opacity(0.5), lineWidth: 1)
                )
                .overlay(
                    Text(bits)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(color)
                        .padding(.horizontal, 8)
                )
                .frame(height: 22)
        }
    }
}

// MARK: - 偏移量可视化
struct OffsetVisualization: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w / 2

            ZStack {
                // 时间轴
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: w, height: 1)
                    .position(x: centerX, y: h * 0.5)

                // 客户端时间线
                VStack(spacing: 4) {
                    Text("客户端时钟")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.cyan)
                    Rectangle()
                        .fill(Color.cyan.opacity(0.3))
                        .frame(width: w * 0.35, height: 20)
                        .overlay(
                            Text("t₁ ─────────── t₄")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                        )
                }
                .position(x: centerX, y: h * 0.22)

                // 服务器时间线
                VStack(spacing: 4) {
                    Text("服务器时钟")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.green)
                    Rectangle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: w * 0.25, height: 20)
                        .overlay(
                            Text("t₂ ──── t₃")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.green)
                        )
                }
                .position(x: centerX, y: h * 0.55)

                // 公式
                VStack(spacing: 2) {
                    Text("offset = ((t₂−t₁) + (t₃−t₄)) / 2")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                    Text("rtt = (t₄−t₁) − (t₃−t₂)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                }
                .position(x: centerX, y: h * 0.82)
            }
        }
    }
}

// MARK: - Stratum 层级图
struct StratumDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let centerX = w / 2
            let layerH: CGFloat = 56
            let startY: CGFloat = 10

            ZStack {
                // Stratum 0
                StratumBox(
                    level: 0,
                    title: "Stratum 0 — 参考源",
                    items: "🛰️ GPS  ·  ⚛️ 原子钟  ·  📡 射电钟",
                    color: .yellow,
                    width: w * 0.5
                )
                .position(x: centerX, y: startY + layerH * 0.5)

                // 连接线 0→1
                ConnectionLine(from: CGPoint(x: centerX, y: startY + layerH),
                               to: CGPoint(x: centerX, y: startY + layerH + 16))

                // Stratum 1
                StratumBox(
                    level: 1,
                    title: "Stratum 1 — 主时钟",
                    items: "🍎 Apple  ·  🇺🇸 NIST  ·  🇩🇪 PTB  ·  🇯🇵 NICT",
                    color: .green,
                    width: w * 0.65
                )
                .position(x: centerX, y: startY + layerH + 16 + layerH * 0.5)

                // 连接线 1→2
                ConnectionLine(from: CGPoint(x: centerX, y: startY + layerH * 2 + 16),
                               to: CGPoint(x: centerX, y: startY + layerH * 2 + 32))

                // Stratum 2
                StratumBox(
                    level: 2,
                    title: "Stratum 2 — 从时钟",
                    items: "🟡 阿里云  ·  🔷 腾讯云  ·  🌏 Pool NTP",
                    color: .cyan,
                    width: w * 0.8
                )
                .position(x: centerX, y: startY + layerH * 2 + 32 + layerH * 0.5)

                // 连接线 2→3
                ConnectionLine(from: CGPoint(x: centerX, y: startY + layerH * 3 + 32),
                               to: CGPoint(x: centerX, y: startY + layerH * 3 + 48))

                // Stratum 3+
                StratumBox(
                    level: 3,
                    title: "Stratum 3+ — 下级时钟",
                    items: "📱 你的设备  ·  🖥️ 企业服务器  ·  🏠 家用路由器",
                    color: .gray,
                    width: w * 0.95
                )
                .position(x: centerX, y: startY + layerH * 3 + 48 + layerH * 0.5)

                // 精度标注
                VStack {
                    Spacer()
                    HStack {
                        Text("精度最高 ↑")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow)
                        Spacer()
                        Text("↓ 精度递减")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: h)
            }
        }
    }
}

struct StratumBox: View {
    let level: Int
    let title: String
    let items: String
    let color: Color
    let width: CGFloat

    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
            Text(items)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(width: width)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.4), lineWidth: 1)
        )
    }
}

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint

    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(Color.gray.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
    }
}

// MARK: - 通用组件

struct InfoCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}

struct InfoBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.15))
            )
    }
}

struct BulletRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.cyan)
                .frame(width: 5, height: 5)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(2)
        }
    }
}

struct TimestampRow: View {
    let label: String
    let desc: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 24)

            Rectangle()
                .fill(color.opacity(0.5))
                .frame(width: 2, height: 16)

            Text(desc)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

struct FieldRow: View {
    let bytes: String
    let bits: String
    let desc: String
    var highlight: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(bytes)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(highlight ? .cyan : .gray)
                .frame(width: 55, alignment: .trailing)

            Text(bits)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(highlight ? .white : .white.opacity(0.6))
                .frame(width: 110, alignment: .leading)

            Text(desc)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
        .padding(.vertical, 1)
    }
}

struct FormulaCard: View {
    let title: String
    let formula: String
    let explanation: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)

            Text(formula)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.05))
                )

            Text(explanation)
                .font(.system(size: 11))
                .foregroundColor(.gray)
        }
    }
}

struct ProItem: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.green)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
    }
}

struct ConItem: View {
    let icon: String
    let title: String
    let desc: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.red)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
            }
        }
    }
}

struct StratumRow: View {
    let stratum: String
    let name: String
    let desc: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text("S\(stratum)")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(color)
                .frame(width: 30)

            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 50, alignment: .leading)

            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
    }
}

struct NTPInfoView_Previews: PreviewProvider {
    static var previews: some View {
        NTPInfoView()
    }
}
