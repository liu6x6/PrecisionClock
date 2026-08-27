package com.precisionclock.crossplatform

import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.ServerSocket
import java.net.Socket
import kotlinx.coroutines.*
import org.json.JSONObject

/**
 * 跨平台时间同步管理器
 * 实现 iOS 和 Android 之间的时间差测量
 */
class TimeSyncManager {
    
    companion object {
        const val DEFAULT_PORT = 12345
        const val MESSAGE_DELIMITER = "\n"
    }
    
    enum class Role {
        NONE, SERVER, CLIENT
    }
    
    enum class MessageType {
        SYNC_REQUEST, SYNC_RESPONSE, SYNC_RESULT
    }
    
    data class SyncResult(
        val round: Int,
        val offset: Double,  // 偏差（秒）
        val rtt: Double,     // 往返延迟（秒）
        val timestamp: Long
    ) {
        val offsetMs: Double get() = offset * 1000
        val rttMs: Double get() = rtt * 1000
    }
    
    // 状态监听器
    interface StateListener {
        fun onStateChanged(state: String)
        fun onConnected(remoteAddress: String)
        fun onDisconnected(reason: String)
        fun onMeasurementResult(results: List<SyncResult>, medianOffset: Double, medianRtt: Double)
        fun onLiveMeasurement(offset: Double, rtt: Double)
    }
    
    var role = Role.NONE
        private set
    
    var isConnected = false
        private set
    
    var isSyncing = false
        private set
    
    var isMonitoring = false
        private set
    
    private var serverSocket: ServerSocket? = null
    private var clientSocket: Socket? = null
    private var printWriter: PrintWriter? = null
    private var bufferedReader: BufferedReader? = null
    
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var monitorJob: Job? = null
    
    private var currentResults = mutableListOf<SyncResult>()
    private var currentRound = 0
    private var totalRounds = 10
    
    var stateListener: StateListener? = null
    
    /**
     * 启动服务端模式
     */
    fun startServer(port: Int = DEFAULT_PORT) {
        stopAll()
        role = Role.SERVER
        
        scope.launch {
            try {
                serverSocket = ServerSocket(port)
                stateListener?.onStateChanged("等待连接... (端口: $port)")
                
                while (!serverSocket!!.isClosed) {
                    val socket = serverSocket!!.accept()
                    handleClientConnection(socket)
                    break  // 只接受一个连接
                }
            } catch (e: Exception) {
                stateListener?.onDisconnected("服务端错误: ${e.message}")
            }
        }
    }
    
    /**
     * 处理客户端连接
     */
    private fun handleClientConnection(socket: Socket) {
        clientSocket = socket
        isConnected = true
        
        val remoteAddress = socket.inetAddress.hostAddress
        stateListener?.onConnected(remoteAddress ?: "未知")
        stateListener?.onStateChanged("已连接")
        
        try {
            printWriter = PrintWriter(socket.getOutputStream(), true)
            bufferedReader = BufferedReader(InputStreamReader(socket.getInputStream()))
            
            // 持续接收消息
            while (isConnected && !socket.isClosed) {
                val line = bufferedReader?.readLine() ?: break
                handleMessage(line)
            }
        } catch (e: Exception) {
            stateListener?.onDisconnected("连接断开: ${e.message}")
        } finally {
            cleanup()
        }
    }
    
    /**
     * 启动客户端模式
     */
    fun startClient(serverIp: String, port: Int = DEFAULT_PORT) {
        stopAll()
        role = Role.CLIENT
        
        scope.launch {
            try {
                stateListener?.onStateChanged("正在连接 $serverIp:$port ...")
                clientSocket = Socket(serverIp, port)
                isConnected = true
                
                val remoteAddress = clientSocket!!.inetAddress.hostAddress
                stateListener?.onConnected(remoteAddress ?: serverIp)
                stateListener?.onStateChanged("已连接")
                
                printWriter = PrintWriter(clientSocket!!.getOutputStream(), true)
                bufferedReader = BufferedReader(InputStreamReader(clientSocket!!.getInputStream()))
                
                // 持续接收消息
                while (isConnected && !clientSocket!!.isClosed) {
                    val line = bufferedReader?.readLine() ?: break
                    handleMessage(line)
                }
            } catch (e: Exception) {
                stateListener?.onDisconnected("连接失败: ${e.message}")
                cleanup()
            }
        }
    }
    
    /**
     * 处理接收到的消息
     */
    private fun handleMessage(message: String) {
        try {
            val json = JSONObject(message)
            val type = MessageType.valueOf(json.getString("type"))
            
            when (type) {
                MessageType.SYNC_REQUEST -> {
                    // 服务端：收到请求，立即回复
                    val t1 = json.getDouble("t1")
                    val t2 = System.currentTimeMillis() / 1000.0
                    
                    val response = JSONObject().apply {
                        put("type", MessageType.SYNC_RESPONSE.name)
                        put("t1", t1)
                        put("t2", t2)
                    }
                    sendMessage(response.toString())
                }
                
                MessageType.SYNC_RESPONSE -> {
                    // 客户端：收到响应，计算偏差
                    val t1 = json.getDouble("t1")
                    val t2 = json.getDouble("t2")
                    val t4 = System.currentTimeMillis() / 1000.0
                    
                    val rtt = t4 - t1
                    val offset = t2 - (t1 + t4) / 2.0
                    
                    // 过滤异常值
                    if (rtt < 0.5 && rtt > 0) {
                        val result = SyncResult(
                            round = currentRound,
                            offset = offset,
                            rtt = rtt,
                            timestamp = System.currentTimeMillis()
                        )
                        
                        if (isMonitoring) {
                            stateListener?.onLiveMeasurement(offset, rtt)
                        } else {
                            currentResults.add(result)
                        }
                    }
                }
                
                MessageType.SYNC_RESULT -> {
                    // 服务端：收到最终结果
                    val offset = json.getDouble("offset")
                    val rtt = json.getDouble("rtt")
                    stateListener?.onMeasurementResult(emptyList(), -offset, rtt)
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    /**
     * 发送消息
     */
    private fun sendMessage(message: String) {
        try {
            printWriter?.println(message)
        } catch (e: Exception) {
            stateListener?.onDisconnected("发送失败: ${e.message}")
        }
    }
    
    /**
     * 开始测量
     */
    fun startMeasurement(rounds: Int = 10) {
        if (!isConnected || role != Role.CLIENT) return
        
        isSyncing = true
        currentResults.clear()
        currentRound = 0
        totalRounds = rounds
        
        scope.launch {
            performNextRound()
        }
    }
    
    /**
     * 执行下一轮测量
     */
    private suspend fun performNextRound() {
        if (currentRound >= totalRounds) {
            finishMeasurement()
            return
        }
        
        currentRound++
        
        val t1 = System.currentTimeMillis() / 1000.0
        val request = JSONObject().apply {
            put("type", MessageType.SYNC_REQUEST.name)
            put("t1", t1)
            put("round", currentRound)
        }
        sendMessage(request.toString())
        
        delay(300)  // 等待 300ms 后发送下一轮
        performNextRound()
    }
    
    /**
     * 完成测量
     */
    private fun finishMeasurement() {
        isSyncing = false
        
        if (currentResults.isEmpty()) return
        
        // 计算中位数
        val sortedOffsets = currentResults.map { it.offset }.sorted()
        val medianOffset = sortedOffsets[sortedOffsets.size / 2]
        
        val sortedRtts = currentResults.map { it.rtt }.sorted()
        val medianRtt = sortedRtts[sortedRtts.size / 2]
        
        // 发送最终结果给服务端
        val result = JSONObject().apply {
            put("type", MessageType.SYNC_RESULT.name)
            put("offset", medianOffset)
            put("rtt", medianRtt)
        }
        sendMessage(result.toString())
        
        stateListener?.onMeasurementResult(currentResults.toList(), medianOffset, medianRtt)
    }
    
    /**
     * 开始持续监测
     */
    fun startMonitoring() {
        if (!isConnected || role != Role.CLIENT) return
        
        isMonitoring = true
        monitorJob = scope.launch {
            while (isMonitoring) {
                val t1 = System.currentTimeMillis() / 1000.0
                val request = JSONObject().apply {
                    put("type", MessageType.SYNC_REQUEST.name)
                    put("t1", t1)
                    put("round", -1)
                }
                sendMessage(request.toString())
                delay(1000)  // 每秒测量一次
            }
        }
    }
    
    /**
     * 停止监测
     */
    fun stopMonitoring() {
        isMonitoring = false
        monitorJob?.cancel()
    }
    
    /**
     * 停止所有
     */
    fun stopAll() {
        stopMonitoring()
        cleanup()
        role = Role.NONE
        isConnected = false
        isSyncing = false
        currentResults.clear()
    }
    
    /**
     * 清理资源
     */
    private fun cleanup() {
        isConnected = false
        try {
            bufferedReader?.close()
            printWriter?.close()
            clientSocket?.close()
            serverSocket?.close()
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            bufferedReader = null
            printWriter = null
            clientSocket = null
            serverSocket = null
        }
    }
    
    /**
     * 释放资源
     */
    fun destroy() {
        stopAll()
        scope.cancel()
    }
}
