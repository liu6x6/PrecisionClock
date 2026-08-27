import Foundation
import Network
import Combine

// MARK: - 跨平台消息协议
struct CrossPlatformMessage: Codable {
    let type: MessageType
    let t1: Double?
    let t2: Double?
    let offset: Double?
    let rtt: Double?
    let round: Int?

    enum MessageType: String, Codable {
        case syncRequest
        case syncResponse
        case syncResult
    }

    static func request(t1: Double, round: Int) -> CrossPlatformMessage {
        CrossPlatformMessage(type: .syncRequest, t1: t1, t2: nil, offset: nil, rtt: nil, round: round)
    }

    static func response(t1: Double, t2: Double) -> CrossPlatformMessage {
        CrossPlatformMessage(type: .syncResponse, t1: t1, t2: t2, offset: nil, rtt: nil, round: nil)
    }

    static func result(offset: Double, rtt: Double) -> CrossPlatformMessage {
        CrossPlatformMessage(type: .syncResult, t1: nil, t2: nil, offset: offset, rtt: rtt, round: nil)
    }
}

// MARK: - 测量结果
struct CrossPlatformSyncResult: Identifiable {
    let id = UUID()
    let round: Int
    let offset: Double
    let rtt: Double
    let timestamp: Date

    var offsetMs: Double { offset * 1000 }
    var rttMs: Double { rtt * 1000 }
}

// MARK: - 角色
enum CrossPlatformRole: String {
    case server = "服务端"
    case client = "客户端"
    case none = "未启动"
}

// MARK: - 跨平台同步管理器
class CrossPlatformSyncManager: ObservableObject {
    @Published var role: CrossPlatformRole = .none
    @Published var isListening = false
    @Published var isConnected = false
    @Published var isSyncing = false
    @Published var isMonitoring = false

    @Published var localIPAddress: String = "获取中..."
    @Published var remoteAddress: String = ""
    @Published var port: UInt16 = 12345

    @Published var currentResults: [CrossPlatformSyncResult] = []
    @Published var medianOffset: Double = 0
    @Published var medianRTT: Double = 0
    @Published var currentRound: Int = 0
    @Published var totalRounds: Int = 10

    @Published var liveOffset: Double = 0
    @Published var liveRTT: Double = 0

    @Published var connectionStatus: String = "未连接"
    @Published var lastError: String?

    private var listener: NWListener?
    private var tcpConnection: NWConnection?
    private let ioQueue = DispatchQueue(label: "CrossPlatformSync.IO", qos: .userInitiated)

    private var pendingRequests: [Double: Date] = [:]
    private var measurementCompletions: (([CrossPlatformSyncResult]) -> Void)?
    private var monitorTimer: Timer?

    // 用于 TCP 接收的 buffer
    private var receiveBuffer = Data()

    init() {
        updateLocalIPAddress()
    }

    // MARK: - 网络信息
    func updateLocalIPAddress() {
        localIPAddress = getLocalIPAddress() ?? "无法获取"
    }

    private func getLocalIPAddress() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var wifiAddress: String?
        var cellularAddress: String?

        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(
                    interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST
                )
                let addr = String(cString: hostname)
                if name == "en0" {
                    wifiAddress = addr
                } else if name.hasPrefix("pdp_ip") {
                    cellularAddress = addr
                }
            }
        }

        return wifiAddress ?? cellularAddress
    }

    // MARK: - Server 模式
    func startServer() {
        stopAll()

        do {
            let parameters = NWParameters(tls: nil)
            parameters.acceptLocalOnly = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            listener?.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.isListening = true
                        self?.role = .server
                        self?.connectionStatus = "等待连接..."
                    case .failed(let error):
                        self?.isListening = false
                        self?.connectionStatus = "启动失败"
                        self?.lastError = error.localizedDescription
                    default:
                        break
                    }
                }
            }

            listener?.newConnectionHandler = { [weak self] newConn in
                self?.acceptConnection(newConn)
            }

            listener?.start(queue: ioQueue)
        } catch {
            connectionStatus = "启动失败"
            lastError = error.localizedDescription
        }
    }

    private func acceptConnection(_ newConn: NWConnection) {
        // 如果已有连接，拒绝新连接
        if tcpConnection != nil {
            newConn.cancel()
            return
        }

        tcpConnection = newConn

        newConn.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectionStatus = "已连接"
                case .failed(let error):
                    self?.handleDisconnect("连接失败: \(error.localizedDescription)")
                case .cancelled:
                    self?.handleDisconnect("连接已断开")
                default:
                    break
                }
            }
        }

        newConn.start(queue: ioQueue)
        startReceiving(from: newConn)
    }

    // MARK: - Client 模式
    func startClient(serverIP: String) {
        stopAll()

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(serverIP),
            port: NWEndpoint.Port(rawValue: port)!
        )

        tcpConnection = NWConnection(to: endpoint, using: .tcp)

        tcpConnection?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.role = .client
                    self?.connectionStatus = "已连接到 \(serverIP)"
                    self?.remoteAddress = serverIP
                case .failed(let error):
                    self?.isConnected = false
                    self?.connectionStatus = "连接失败"
                    self?.lastError = error.localizedDescription
                case .cancelled:
                    self?.handleDisconnect("连接已断开")
                default:
                    break
                }
            }
        }

        tcpConnection?.start(queue: ioQueue)
        startReceiving(from: tcpConnection!)
    }

    // MARK: - TCP 接收
    private func startReceiving(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let data = content, !data.isEmpty {
                self.receiveBuffer.append(data)
                self.processReceiveBuffer()
            }

            if isComplete {
                DispatchQueue.main.async {
                    self.handleDisconnect("连接已断开")
                }
                return
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.handleDisconnect("接收错误: \(error.localizedDescription)")
                }
                return
            }

            // 继续接收
            self.startReceiving(from: connection)
        }
    }

    /// 处理接收缓冲区，提取完整的 JSON 消息
    private func processReceiveBuffer() {
        // 尝试解析消息（以换行符分隔）
        while let newlineRange = receiveBuffer.range(of: Data([0x0A])) {
            let messageData = Data(receiveBuffer[receiveBuffer.startIndex..<newlineRange.lowerBound])
            receiveBuffer = Data(receiveBuffer[newlineRange.upperBound...])

            guard !messageData.isEmpty,
                  let message = try? JSONDecoder().decode(CrossPlatformMessage.self, from: messageData) else {
                continue
            }

            handleIncomingMessage(message)
        }
    }

    private func handleIncomingMessage(_ message: CrossPlatformMessage) {
        switch message.type {
        case .syncRequest:
            // Server: 收到请求，立即回复
            let t2 = Date().timeIntervalSince1970
            if let t1 = message.t1 {
                let response = CrossPlatformMessage.response(t1: t1, t2: t2)
                sendMessage(response)
            }

        case .syncResponse:
            // Client: 收到响应，计算偏差
            handleSyncResponse(message)

        case .syncResult:
            // Server: 收到最终结果
            if let offset = message.offset, let rtt = message.rtt {
                DispatchQueue.main.async { [weak self] in
                    self?.medianOffset = -offset
                    self?.medianRTT = rtt
                }
            }
        }
    }

    private func handleSyncResponse(_ message: CrossPlatformMessage) {
        guard let t1 = message.t1, let t2 = message.t2 else { return }

        let t4 = Date().timeIntervalSince1970
        let rtt = t4 - t1
        let offset = t2 - (t1 + t4) / 2.0

        guard rtt < 0.5, rtt > 0 else { return }

        let result = CrossPlatformSyncResult(
            round: currentRound,
            offset: offset,
            rtt: rtt,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isMonitoring {
                self.liveOffset = offset
                self.liveRTT = rtt
            } else {
                self.currentResults.append(result)
            }
        }
    }

    // MARK: - 发送消息
    private func sendMessage(_ message: CrossPlatformMessage) {
        guard let connection = tcpConnection,
              let data = try? JSONEncoder().encode(message) else { return }

        // 追加换行符作为消息分隔
        var sendData = data
        sendData.append(0x0A)

        connection.send(content: sendData, completion: .contentProcessed { error in
            if let error = error {
                print("发送失败: \(error)")
            }
        })
    }

    // MARK: - 测量控制
    func startSyncMeasurement(rounds: Int = 10, completion: (([CrossPlatformSyncResult]) -> Void)? = nil) {
        guard isConnected, role == .client else { return }

        isSyncing = true
        currentResults = []
        currentRound = 0
        totalRounds = rounds
        measurementCompletions = completion

        performNextRound()
    }

    private func performNextRound() {
        guard currentRound < totalRounds else {
            finishMeasurement()
            return
        }

        currentRound += 1

        let t1 = Date().timeIntervalSince1970
        let message = CrossPlatformMessage.request(t1: t1, round: currentRound)
        sendMessage(message)
        pendingRequests[t1] = Date()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.performNextRound()
        }
    }

    private func finishMeasurement() {
        isSyncing = false

        guard !currentResults.isEmpty else { return }

        let sortedOffsets = currentResults.map { $0.offset }.sorted()
        medianOffset = sortedOffsets[sortedOffsets.count / 2]

        let sortedRTTs = currentResults.map { $0.rtt }.sorted()
        medianRTT = sortedRTTs[sortedRTTs.count / 2]

        // 发送最终结果给 Server
        let result = CrossPlatformMessage.result(offset: medianOffset, rtt: medianRTT)
        sendMessage(result)

        measurementCompletions?(currentResults)
    }

    func startMonitoring() {
        guard isConnected, role == .client else { return }
        isMonitoring = true

        monitorTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.performSingleMeasurement()
        }
    }

    func stopMonitoring() {
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func performSingleMeasurement() {
        guard isConnected, role == .client else { return }

        let t1 = Date().timeIntervalSince1970
        let message = CrossPlatformMessage.request(t1: t1, round: -1)
        sendMessage(message)
        pendingRequests[t1] = Date()
    }

    // MARK: - 断开处理
    private func handleDisconnect(_ reason: String) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = false
            self?.isListening = false
            self?.isSyncing = false
            self?.isMonitoring = false
            self?.connectionStatus = reason
            self?.monitorTimer?.invalidate()
            self?.monitorTimer = nil
            self?.tcpConnection = nil
        }
    }

    // MARK: - 停止
    func stopAll() {
        listener?.cancel()
        listener = nil
        tcpConnection?.cancel()
        tcpConnection = nil
        isListening = false
        isConnected = false
        isSyncing = false
        isMonitoring = false
        role = .none
        currentResults = []
        medianOffset = 0
        medianRTT = 0
        monitorTimer?.invalidate()
        monitorTimer = nil
        receiveBuffer = Data()
    }
}
