import Foundation
import MultipeerConnectivity
import Combine

// MARK: - 消息协议
struct SyncMessage: Codable {
    let type: MessageType
    let t1: TimeInterval?   // 发起方发送时间
    let t2: TimeInterval?   // 响应方接收时间
    let offset: Double?     // 计算出的偏差
    let rtt: Double?        // 往返延迟
    let round: Int?         // 当前轮次

    enum MessageType: String, Codable {
        case syncRequest    // Master → Slave: 请求时间同步
        case syncResponse   // Slave → Master: 响应时间同步
        case syncResult     // Master → Slave: 发送最终结果
        case heartbeat      // 心跳
    }

    static func request(t1: TimeInterval, round: Int) -> SyncMessage {
        SyncMessage(type: .syncRequest, t1: t1, t2: nil, offset: nil, rtt: nil, round: round)
    }

    static func response(t1: TimeInterval, t2: TimeInterval) -> SyncMessage {
        SyncMessage(type: .syncResponse, t1: t1, t2: t2, offset: nil, rtt: nil, round: nil)
    }

    static func result(offset: Double, rtt: Double) -> SyncMessage {
        SyncMessage(type: .syncResult, t1: nil, t2: nil, offset: offset, rtt: rtt, round: nil)
    }
}

// MARK: - 单次测量结果
struct DeviceSyncResult: Identifiable {
    let id = UUID()
    let round: Int
    let offset: Double      // 偏差（秒）：正值表示对方时钟偏快
    let rtt: Double         // 往返延迟（秒）
    let timestamp: Date

    var offsetMs: Double { offset * 1000 }
    var rttMs: Double { rtt * 1000 }
}

// MARK: - 设备角色
enum SyncRole: String {
    case master = "发起方"
    case slave = "响应方"
    case none = "未连接"
}

// MARK: - 设备同步管理器
class DeviceSyncManager: NSObject, ObservableObject {
    // MARK: - Published 属性
    @Published var peerID: MCPeerID
    @Published var role: SyncRole = .none
    @Published var isAdvertising = false
    @Published var isBrowsing = false
    @Published var connectedPeerName: String?
    @Published var isConnected = false
    @Published var isSyncing = false

    // 测量结果
    @Published var currentResults: [DeviceSyncResult] = []
    @Published var medianOffset: Double = 0
    @Published var medianRTT: Double = 0
    @Published var currentRound: Int = 0
    @Published var totalRounds: Int = 10

    // 持续监测
    @Published var isMonitoring = false
    @Published var liveOffset: Double = 0
    @Published var liveRTT: Double = 0

    // 发现的设备
    @Published var discoveredPeers: [MCPeerID] = []

    // MARK: - 私有属性
    private var session: MCSession!
    private var advertiser: MCAdvertiserAssistant?
    private var browser: MCNearbyServiceBrowser?
    private let serviceType = "pclock-sync"

    // 测量状态
    private var pendingRequests: [TimeInterval: Date] = [:]  // t1 -> sendDate
    private var measurementCompletions: (([DeviceSyncResult]) -> Void)?
    private var monitorTimer: Timer?

    // MARK: - 初始化
    override init() {
        #if os(iOS)
        let deviceName = UIDevice.current.name
        #else
        let deviceName = Host.current().localizedName ?? "Mac"
        #endif
        self.peerID = MCPeerID(displayName: deviceName)
        super.init()
        setupSession()
    }

    private func setupSession() {
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    // MARK: - 发现与连接

    /// 开始广播（作为响应方/Slave）
    func startAdvertising() {
        stopBrowsing()
        advertiser = MCAdvertiserAssistant(serviceType: serviceType, discoveryInfo: nil, session: session)
        advertiser?.delegate = self
        advertiser?.start()
        isAdvertising = true
        role = .slave
    }

    /// 开始搜索（作为发起方/Master）
    func startBrowsing() {
        stopAdvertising()
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        isBrowsing = true
        role = .master
    }

    /// 连接到指定设备
    func connect(to peer: MCPeerID) {
        browser?.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }

    /// 停止所有发现
    func stopAll() {
        stopAdvertising()
        stopBrowsing()
        disconnect()
    }

    private func stopAdvertising() {
        advertiser?.stop()
        advertiser = nil
        isAdvertising = false
    }

    private func stopBrowsing() {
        browser?.stopBrowsingForPeers()
        browser = nil
        isBrowsing = false
        discoveredPeers.removeAll()
    }

    private func disconnect() {
        session.disconnect()
        isConnected = false
        connectedPeerName = nil
        role = .none
        isSyncing = false
        isMonitoring = false
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    // MARK: - 时间同步测量

    /// 开始一轮测量（多轮取中位数）
    func startSyncMeasurement(rounds: Int = 10, completion: (([DeviceSyncResult]) -> Void)? = nil) {
        guard isConnected, role == .master else { return }

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

        // 发送同步请求
        let t1 = Date().timeIntervalSince1970
        let message = SyncMessage.request(t1: t1, round: currentRound)

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            pendingRequests[t1] = Date()
        } catch {
            print("发送同步请求失败: \(error)")
        }

        // 延迟后发送下一轮
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.performNextRound()
        }
    }

    private func finishMeasurement() {
        isSyncing = false

        guard !currentResults.isEmpty else { return }

        // 计算中位数
        let sortedOffsets = currentResults.map { $0.offset }.sorted()
        medianOffset = sortedOffsets[sortedOffsets.count / 2]

        let sortedRTTs = currentResults.map { $0.rtt }.sorted()
        medianRTT = sortedRTTs[sortedRTTs.count / 2]

        // 发送最终结果给对方
        if let data = try? JSONEncoder().encode(SyncMessage.result(offset: medianOffset, rtt: medianRTT)) {
            try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
        }

        measurementCompletions?(currentResults)
    }

    /// 开始持续监测（每秒测量一次）
    func startMonitoring() {
        guard isConnected, role == .master else { return }
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
        guard isConnected, role == .master else { return }

        let t1 = Date().timeIntervalSince1970
        let message = SyncMessage.request(t1: t1, round: -1)  // round=-1 表示监测模式

        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            pendingRequests[t1] = Date()
        } catch {
            print("监测发送失败: \(error)")
        }
    }

    // MARK: - 消息处理

    private func handleMessage(_ message: SyncMessage, from peer: MCPeerID) {
        switch message.type {
        case .syncRequest:
            handleSyncRequest(message)
        case .syncResponse:
            handleSyncResponse(message)
        case .syncResult:
            handleSyncResult(message)
        case .heartbeat:
            break
        }
    }

    /// Slave: 收到请求，立即回复
    private func handleSyncRequest(_ message: SyncMessage) {
        guard let t1 = message.t1 else { return }

        // 立即记录接收时间并回复
        let t2 = Date().timeIntervalSince1970
        let response = SyncMessage.response(t1: t1, t2: t2)

        do {
            let data = try JSONEncoder().encode(response)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("回复同步请求失败: \(error)")
        }
    }

    /// Master: 收到响应，计算偏差
    private func handleSyncResponse(_ message: SyncMessage) {
        guard let t1 = message.t1, let t2 = message.t2 else { return }

        let t4 = Date().timeIntervalSince1970

        // NTP 算法（简化版，假设 t2 ≈ t3）
        let rtt = t4 - t1
        let offset = t2 - (t1 + t4) / 2.0

        // 过滤异常值（RTT > 500ms 的测量不可靠）
        guard rtt < 0.5, rtt > 0 else { return }

        let result = DeviceSyncResult(
            round: currentRound,
            offset: offset,
            rtt: rtt,
            timestamp: Date()
        )

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.isMonitoring {
                // 监测模式：直接更新实时值
                self.liveOffset = offset
                self.liveRTT = rtt
            } else {
                // 测量模式：累积结果
                self.currentResults.append(result)
            }
        }
    }

    /// Slave: 收到最终结果
    private func handleSyncResult(_ message: SyncMessage) {
        guard let offset = message.offset, let rtt = message.rtt else { return }
        DispatchQueue.main.async { [weak self] in
            // Slave 端显示对方计算的结果（符号取反，因为是从对方视角计算的）
            self?.medianOffset = -offset
            self?.medianRTT = rtt
        }
    }
}

// MARK: - MCSessionDelegate
extension DeviceSyncManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .connected:
                self?.isConnected = true
                self?.connectedPeerName = peerID.displayName
                self?.isSyncing = false
                self?.currentResults = []
                self?.medianOffset = 0
                self?.medianRTT = 0
            case .notConnected:
                self?.isConnected = false
                self?.connectedPeerName = nil
                self?.isSyncing = false
                self?.isMonitoring = false
                self?.monitorTimer?.invalidate()
            case .connecting:
                break
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(SyncMessage.self, from: data) {
            handleMessage(message, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // 不使用流
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // 不使用资源传输
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // 不使用资源传输
    }
}

// MARK: - MCAdvertiserAssistantDelegate
extension DeviceSyncManager: MCAdvertiserAssistantDelegate {
    func advertiserAssistant(_ advertiserAssistant: MCAdvertiserAssistant, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受连接
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension DeviceSyncManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if !self.discoveredPeers.contains(peerID) {
                self.discoveredPeers.append(peerID)
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredPeers.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("浏览失败: \(error.localizedDescription)")
    }
}
