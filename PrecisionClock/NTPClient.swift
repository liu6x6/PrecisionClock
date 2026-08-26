import Foundation
import Network
import Combine

// MARK: - NTP 服务器定义
struct NTPServer: Identifiable, Hashable {
    let id: String
    let name: String
    let host: String
    let flag: String
    let region: String

    static let allServers: [NTPServer] = [
        NTPServer(id: "apple",     name: "Apple",        host: "time.apple.com",        flag: "🍎", region: "美国"),
        NTPServer(id: "google",    name: "Google",       host: "time.google.com",       flag: "🔵", region: "全球"),
        NTPServer(id: "cloudflare",name: "Cloudflare",   host: "time.cloudflare.com",   flag: "🟠", region: "全球"),
        NTPServer(id: "ntp.aliyun",name: "阿里云",       host: "ntp.aliyun.com",        flag: "🟡", region: "中国"),
        NTPServer(id: "ntp.tencent",name: "腾讯云",      host: "ntp.tencent.com",       flag: "🔷", region: "中国"),
        NTPServer(id: "pool_asia", name: "Pool Asia",    host: "asia.pool.ntp.org",     flag: "🌏", region: "亚洲"),
        NTPServer(id: "pool_cn",   name: "Pool China",   host: "cn.pool.ntp.org",       flag: "🇨🇳", region: "中国"),
        NTPServer(id: "usno",      name: "US Naval Obs", host: "time.nist.gov",         flag: "🇺🇸", region: "美国"),
        NTPServer(id: "ptb",       name: "PTB 德国",     host: "ptbtime1.ptb.de",       flag: "🇩🇪", region: "德国"),
        NTPServer(id: "nict",      name: "NICT 日本",    host: "ntp.nict.jp",           flag: "🇯🇵", region: "日本"),
    ]
}

// MARK: - NTP 测量结果
struct NTPMeasurement: Identifiable {
    let id = UUID()
    let server: NTPServer
    let offset: TimeInterval      // 本机 - NTP 的偏差（秒）
    let rtt: TimeInterval         // 往返延迟（秒）
    let ntpTime: Date             // 校准后的NTP时间
    let timestamp: Date           // 测量时间
    let success: Bool
    let error: String?

    var offsetMs: Double { offset * 1000 }
    var rttMs: Double { rtt * 1000 }
}

// MARK: - NTP 客户端
class NTPClient {
    /// 使用 UDP 发送 NTP 请求
    /// NTP 协议: 48字节报文, 时间戳在末尾8字节 (秒数自1900-01-01)
    static func query(server: NTPServer, timeout: TimeInterval = 3.0) async throws -> (offset: TimeInterval, rtt: TimeInterval, transmitTime: Date) {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                to: NWEndpoint.hostPort(host: .init(server.host), port: .init(rawValue: 123)! ),
                using: .udp
            )

            var hasResumed = false

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    // 构造 NTP 请求包 (48 bytes)
                    var packet = [UInt8](repeating: 0, count: 48)
                    // LI=0, VN=4, Mode=3 (client)
                    packet[0] = 0x23

                    // 记录发送时间 (t1)
                    let t1 = Date()

                    connection.send(content: Data(packet), completion: .contentProcessed { error in
                        if let error = error {
                            if !hasResumed {
                                hasResumed = true
                                continuation.resume(throwing: NTPError.sendFailed(error))
                            }
                            return
                        }
                    })

                    connection.receive(minimumIncompleteLength: 48, maximumLength: 48) { content, _, _, error in
                        guard !hasResumed else { return }

                        if let error = error {
                            hasResumed = true
                            continuation.resume(throwing: NTPError.receiveFailed(error))
                            return
                        }

                        guard let data = content, data.count >= 48 else {
                            hasResumed = true
                            continuation.resume(throwing: NTPError.invalidResponse)
                            return
                        }

                        // t4 = 收到响应的时间
                        let t4 = Date()

                        // 解析 NTP 响应
                        // Transmit Timestamp 在 bytes 40-47
                        let transmitTimestamp = Self.extractTimestamp(from: data, offset: 40)

                        // NTP epoch: 1900-01-01, Unix epoch: 1970-01-01
                        // 差值: 70 years = 2208988800 seconds
                        let ntpEpochDiff: UInt64 = 2208988800

                        let seconds = transmitTimestamp - ntpEpochDiff
                        let transmitDate = Date(timeIntervalSince1970: Double(seconds))

                        // NTP 算法:
                        // offset = ((t2 - t1) + (t3 - t4)) / 2
                        // rtt = (t4 - t1) - (t3 - t2)
                        // 简化: 假设 t2 ≈ t3 (服务器处理时间极短)
                        // offset ≈ (transmitDate - t1 + transmitDate - t4) / 2

                        let rtt = t4.timeIntervalSince(t1)
                        let offset = (transmitDate.timeIntervalSince(t1) + transmitDate.timeIntervalSince(t4)) / 2

                        hasResumed = true
                        continuation.resume(returning: (offset, rtt, transmitDate))
                    }

                case .failed(let error):
                    if !hasResumed {
                        hasResumed = true
                        continuation.resume(throwing: NTPError.connectionFailed(error))
                    }
                default:
                    break
                }
            }

            // 超时处理
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                if !hasResumed {
                    hasResumed = true
                    connection.cancel()
                    continuation.resume(throwing: NTPError.timeout)
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }

    /// 从 NTP 报文中提取 64-bit 时间戳（秒部分，前32位）
    private static func extractTimestamp(from data: Data, offset: Int) -> UInt64 {
        var seconds: UInt64 = 0
        for i in 0..<4 {
            seconds = (seconds << 8) | UInt64(data[offset + i])
        }
        return seconds
    }

    /// 多次测量取中位数，更准确
    static func measure(server: NTPServer, rounds: Int = 5) async -> NTPMeasurement {
        var offsets: [TimeInterval] = []
        var rtts: [TimeInterval] = []
        var lastNtpTime = Date()

        for _ in 0..<rounds {
            do {
                let result = try await query(server: server)
                offsets.append(result.offset)
                rtts.append(result.rtt)
                lastNtpTime = Date().addingTimeInterval(-result.offset)
            } catch {
                // 跳过失败的轮次
            }
        }

        guard !offsets.isEmpty else {
            return NTPMeasurement(
                server: server,
                offset: 0,
                rtt: 0,
                ntpTime: Date(),
                timestamp: Date(),
                success: false,
                error: "无法连接到 \(server.host)"
            )
        }

        // 取中位数
        let sortedOffsets = offsets.sorted()
        let medianOffset = sortedOffsets[sortedOffsets.count / 2]

        let sortedRtts = rtts.sorted()
        let medianRtt = sortedRtts[sortedRtts.count / 2]

        let correctedTime = Date().addingTimeInterval(-medianOffset)

        return NTPMeasurement(
            server: server,
            offset: medianOffset,
            rtt: medianRtt,
            ntpTime: correctedTime,
            timestamp: Date(),
            success: true,
            error: nil
        )
    }
}

// MARK: - NTP 错误
enum NTPError: LocalizedError {
    case timeout
    case sendFailed(Error)
    case receiveFailed(Error)
    case invalidResponse
    case connectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .timeout: return "连接超时"
        case .sendFailed(let e): return "发送失败: \(e.localizedDescription)"
        case .receiveFailed(let e): return "接收失败: \(e.localizedDescription)"
        case .invalidResponse: return "无效的NTP响应"
        case .connectionFailed(let e): return "连接失败: \(e.localizedDescription)"
        }
    }
}

// MARK: - NTP 管理器
class NTPManager: ObservableObject {
    @Published var measurements: [String: NTPMeasurement] = [:]  // serverId -> measurement
    @Published var selectedServerId: String = "apple"
    @Published var isMeasuring: Bool = false
    @Published var correctedOffset: TimeInterval = 0  // 选中服务器的偏差

    var selectedServer: NTPServer {
        NTPServer.allServers.first { $0.id == selectedServerId } ?? NTPServer.allServers[0]
    }

    var correctedDate: Date {
        Date().addingTimeInterval(-correctedOffset)
    }

    func measure(server: NTPServer) async {
        await MainActor.run { isMeasuring = true }

        let measurement = await NTPClient.measure(server: server, rounds: 5)

        await MainActor.run {
            self.measurements[server.id] = measurement
            self.isMeasuring = false

            // 如果测量的是当前选中的服务器，更新偏差
            if server.id == self.selectedServerId {
                self.correctedOffset = measurement.offset
            }
        }
    }

    func measureAll() async {
        await MainActor.run { isMeasuring = true }

        await withTaskGroup(of: NTPMeasurement.self) { group in
            for server in NTPServer.allServers {
                group.addTask {
                    await NTPClient.measure(server: server, rounds: 3)
                }
            }

            for await measurement in group {
                await MainActor.run {
                    self.measurements[measurement.server.id] = measurement
                }
            }
        }

        // 更新选中服务器的偏差
        if let selected = measurements[selectedServerId] {
            await MainActor.run {
                self.correctedOffset = selected.offset
                self.isMeasuring = false
            }
        } else {
            await MainActor.run { isMeasuring = false }
        }
    }

    func selectServer(_ serverId: String) {
        selectedServerId = serverId
        if let measurement = measurements[serverId] {
            correctedOffset = measurement.offset
        }
    }
}
