package com.precisionclock.crossplatform

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.net.NetworkInterface
import java.util.*

class MainActivity : ComponentActivity() {
    
    private val syncManager = TimeSyncManager()
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme()
            ) {
                CrossPlatformSyncScreen()
            }
        }
        
        // 设置状态监听器
        syncManager.stateListener = object : TimeSyncManager.StateListener {
            override fun onStateChanged(state: String) {
                runOnUiThread { /* UI will recompose */ }
            }
            
            override fun onConnected(remoteAddress: String) {
                runOnUiThread {
                    Toast.makeText(this@MainActivity, "已连接到 $remoteAddress", Toast.LENGTH_SHORT).show()
                }
            }
            
            override fun onDisconnected(reason: String) {
                runOnUiThread {
                    Toast.makeText(this@MainActivity, reason, Toast.LENGTH_SHORT).show()
                }
            }
            
            override fun onMeasurementResult(results: List<TimeSyncManager.SyncResult>, medianOffset: Double, medianRtt: Double) {
                runOnUiThread {
                    // UI will recompose via state
                }
            }
            
            override fun onLiveMeasurement(offset: Double, rtt: Double) {
                runOnUiThread {
                    // UI will recompose via state
                }
            }
        }
    }
    
    override fun onDestroy() {
        super.onDestroy()
        syncManager.destroy()
    }
    
    @Composable
    fun CrossPlatformSyncScreen() {
        var connectionStatus by remember { mutableStateOf("未连接") }
        var isConnected by remember { mutableStateOf(false) }
        var isListening by remember { mutableStateOf(false) }
        var role by remember { mutableStateOf(TimeSyncManager.Role.NONE) }
        var serverIp by remember { mutableStateOf("") }
        var medianOffset by remember { mutableStateOf(0.0) }
        var medianRtt by remember { mutableStateOf(0.0) }
        var isSyncing by remember { mutableStateOf(false) }
        var isMonitoring by remember { mutableStateOf(false) }
        var roundCount by remember { mutableIntStateOf(10) }
        var localIp by remember { mutableStateOf(getLocalIPAddress()) }
        
        // 更新监听器
        LaunchedEffect(Unit) {
            syncManager.stateListener = object : TimeSyncManager.StateListener {
                override fun onStateChanged(state: String) {
                    connectionStatus = state
                }
                
                override fun onConnected(remoteAddress: String) {
                    isConnected = true
                    connectionStatus = "已连接到 $remoteAddress"
                }
                
                override fun onDisconnected(reason: String) {
                    isConnected = false
                    isListening = false
                    isSyncing = false
                    isMonitoring = false
                    connectionStatus = reason
                }
                
                override fun onMeasurementResult(results: List<TimeSyncManager.SyncResult>, medianOffsetVal: Double, medianRttVal: Double) {
                    medianOffset = medianOffsetVal
                    medianRtt = medianRttVal
                    isSyncing = false
                }
                
                override fun onLiveMeasurement(offset: Double, rtt: Double) {
                    medianOffset = offset
                    medianRtt = rtt
                }
            }
        }
        
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .statusBarsPadding()
        ) {
            // 标题栏
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "跨平台对时",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = Color.White
                )
                
                Row {
                    if (isConnected || isListening) {
                        TextButton(onClick = {
                            syncManager.stopAll()
                            isConnected = false
                            isListening = false
                            role = TimeSyncManager.Role.NONE
                        }) {
                            Text("断开", color = Color.Red)
                        }
                    }
                }
            }
            
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // 连接状态卡片
                StatusCard(
                    connectionStatus = connectionStatus,
                    isConnected = isConnected,
                    role = role
                )
                
                if (!isConnected) {
                    // 角色选择
                    RoleSelectionCard(
                        role = role,
                        isListening = isListening,
                        onStartServer = {
                            syncManager.startServer()
                            role = TimeSyncManager.Role.SERVER
                            isListening = true
                        },
                        onStartClient = {
                            role = TimeSyncManager.Role.CLIENT
                        }
                    )
                    
                    // 服务端模式：显示 IP
                    if (role == TimeSyncManager.Role.SERVER && isListening) {
                        ServerInfoCard(
                            localIp = localIp,
                            onRefresh = { localIp = getLocalIPAddress() }
                        )
                    }
                    
                    // 客户端模式：输入 IP
                    if (role == TimeSyncManager.Role.CLIENT) {
                        ClientConnectCard(
                            serverIp = serverIp,
                            onIpChange = { serverIp = it },
                            onConnect = {
                                syncManager.startClient(serverIp)
                            }
                        )
                    }
                    
                    // 使用说明
                    InstructionsCard()
                }
                
                // 已连接：显示结果
                if (isConnected) {
                    OffsetResultCard(
                        medianOffset = medianOffset,
                        medianRtt = medianRtt,
                        isMonitoring = isMonitoring
                    )
                    
                    SyncControlCard(
                        isSyncing = isSyncing,
                        isMonitoring = isMonitoring,
                        isClient = role == TimeSyncManager.Role.CLIENT,
                        roundCount = roundCount,
                        onRoundCountChange = { roundCount = it },
                        onStartMeasurement = {
                            isSyncing = true
                            syncManager.startMeasurement(roundCount)
                        },
                        onToggleMonitoring = {
                            if (isMonitoring) {
                                syncManager.stopMonitoring()
                                isMonitoring = false
                            } else {
                                syncManager.startMonitoring()
                                isMonitoring = true
                            }
                        }
                    )
                    
                    HowItWorksCard()
                }
            }
        }
    }
    
    @Composable
    fun StatusCard(connectionStatus: String, isConnected: Boolean, role: TimeSyncManager.Role) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A1A)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // 状态指示灯
                Surface(
                    modifier = Modifier.size(10.dp),
                    shape = RoundedCornerShape(5.dp),
                    color = if (isConnected) Color.Green else Color.Gray
                ) {}
                
                Spacer(modifier = Modifier.width(8.dp))
                
                Text(
                    text = connectionStatus,
                    fontSize = 14.sp,
                    color = if (isConnected) Color.Green else Color.Gray
                )
                
                Spacer(modifier = Modifier.weight(1f))
                
                if (role != TimeSyncManager.Role.NONE) {
                    Surface(
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 3.dp),
                        shape = RoundedCornerShape(4.dp),
                        color = if (role == TimeSyncManager.Role.SERVER) Color(0x339B59B6) else Color(0x3300BCD4)
                    ) {
                        Text(
                            text = role.name,
                            fontSize = 12.sp,
                            color = if (role == TimeSyncManager.Role.SERVER) Color(0xFF9B59B6) else Color(0xFF00BCD4),
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                        )
                    }
                }
            }
        }
    }
    
    @Composable
    fun RoleSelectionCard(
        role: TimeSyncManager.Role,
        isListening: Boolean,
        onStartServer: () -> Unit,
        onStartClient: () -> Unit
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A1A)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("选择角色", fontSize = 14.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    // 服务端按钮
                    Button(
                        onClick = onStartServer,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isListening) Color(0xFF9B59B6) else Color(0x1A9B59B6)
                        ),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(vertical = 8.dp)
                        ) {
                            Text("🖥️", fontSize = 24.sp)
                            Text("服务端", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            Text("等待 iOS 连接", fontSize = 10.sp, color = Color.Gray)
                        }
                    }
                    
                    // 客户端按钮
                    Button(
                        onClick = onStartClient,
                        modifier = Modifier.weight(1f),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (role == TimeSyncManager.Role.CLIENT) Color(0xFF00BCD4) else Color(0x1A00BCD4)
                        ),
                        shape = RoundedCornerShape(10.dp)
                    ) {
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier.padding(vertical = 8.dp)
                        ) {
                            Text("📱", fontSize = 24.sp)
                            Text("客户端", fontSize = 14.sp, fontWeight = FontWeight.SemiBold)
                            Text("连接 iOS 服务端", fontSize = 10.sp, color = Color.Gray)
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "💡 两台设备需选择不同角色，确保在同一局域网内",
                    fontSize = 11.sp,
                    color = Color(0x80FFFFFF)
                )
            }
        }
    }
    
    @Composable
    fun ServerInfoCard(localIp: String, onRefresh: () -> Unit) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0x149B59B6)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("服务端信息", fontSize = 14.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column {
                        Text("本机 IP 地址", fontSize = 11.sp, color = Color.Gray)
                        Text(
                            localIp,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Medium,
                            fontFamily = FontFamily.Monospace,
                            color = Color.White
                        )
                    }
                    
                    Spacer(modifier = Modifier.weight(1f))
                    
                    TextButton(onClick = onRefresh) {
                        Text("🔄", fontSize = 16.sp)
                    }
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Row {
                    Text("端口", fontSize = 12.sp, color = Color.Gray)
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        "${TimeSyncManager.DEFAULT_PORT}",
                        fontSize = 14.sp,
                        fontFamily = FontFamily.Monospace,
                        color = Color.White
                    )
                }
            }
        }
    }
    
    @Composable
    fun ClientConnectCard(serverIp: String, onIpChange: (String) -> Unit, onConnect: () -> Unit) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0x1400BCD4)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("连接服务端", fontSize = 14.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("服务端 IP:", fontSize = 13.sp, color = Color.Gray)
                    Spacer(modifier = Modifier.width(8.dp))
                    
                    OutlinedTextField(
                        value = serverIp,
                        onValueChange = onIpChange,
                        placeholder = { Text("例如: 192.168.1.100", fontSize = 12.sp) },
                        modifier = Modifier.weight(1f),
                        singleLine = true,
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedBorderColor = Color(0xFF00BCD4),
                            unfocusedBorderColor = Color(0x33FFFFFF),
                            focusedTextColor = Color.White,
                            unfocusedTextColor = Color.White
                        ),
                        textStyle = LocalTextStyle.current.copy(
                            fontFamily = FontFamily.Monospace,
                            fontSize = 14.sp
                        )
                    )
                }
                
                Spacer(modifier = Modifier.height(12.dp))
                
                Button(
                    onClick = onConnect,
                    modifier = Modifier.fillMaxWidth(),
                    enabled = serverIp.isNotEmpty(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF00BCD4),
                        disabledContainerColor = Color.Gray
                    ),
                    shape = RoundedCornerShape(8.dp)
                ) {
                    Text("🔗 连接", fontSize = 14.sp, fontWeight = FontWeight.Medium)
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "💡 请确保 iOS 设备已启动服务端，并输入其显示的 IP 地址",
                    fontSize = 11.sp,
                    color = Color(0x80FFFFFF)
                )
            }
        }
    }
    
    @Composable
    fun OffsetResultCard(medianOffset: Double, medianRtt: Double, isMonitoring: Boolean) {
        val offsetMs = medianOffset * 1000
        val offsetText = if (offsetMs >= 0) "+%.2f ms".format(offsetMs) else "%.2f ms".format(offsetMs)
        val offsetColor = when {
            kotlin.math.abs(offsetMs) < 5 -> Color.Green
            kotlin.math.abs(offsetMs) < 20 -> Color.Yellow
            else -> Color.Red
        }
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A1A)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row {
                    Text("时间差", fontSize = 14.sp, color = Color.Gray)
                    Spacer(modifier = Modifier.weight(1f))
                    if (isMonitoring) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = Color(0x3300FF00)
                        ) {
                            Text(
                                "● 实时监测中",
                                fontSize = 11.sp,
                                color = Color.Green,
                                modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp)
                            )
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    text = offsetText,
                    fontSize = 48.sp,
                    fontWeight = FontWeight.Thin,
                    fontFamily = FontFamily.Monospace,
                    color = offsetColor
                )
                
                val description = when {
                    kotlin.math.abs(offsetMs) < 1 -> "两台设备时钟几乎完全同步 ✨"
                    offsetMs > 0 -> "Android 时钟比 iOS 快 %.2f 毫秒".format(offsetMs)
                    else -> "Android 时钟比 iOS 慢 %.2f 毫秒".format(kotlin.math.abs(offsetMs))
                }
                Text(description, fontSize = 13.sp, color = Color.Gray)
                
                Spacer(modifier = Modifier.height(12.dp))
                Divider(color = Color(0x33FFFFFF))
                Spacer(modifier = Modifier.height(12.dp))
                
                Row {
                    Column {
                        Text("往返延迟", fontSize = 10.sp, color = Color.Gray)
                        Text(
                            "%.1f ms".format(medianRtt * 1000),
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Light,
                            fontFamily = FontFamily.Monospace,
                            color = when {
                                medianRtt * 1000 < 10 -> Color.Green
                                medianRtt * 1000 < 50 -> Color.Yellow
                                else -> Color.Red
                            }
                        )
                    }
                    
                    Spacer(modifier = Modifier.weight(1f))
                    
                    Column(horizontalAlignment = Alignment.End) {
                        Text("精度评估", fontSize = 10.sp, color = Color.Gray)
                        val accuracy = when {
                            kotlin.math.abs(offsetMs) < 5 -> "极佳" to Color.Green
                            kotlin.math.abs(offsetMs) < 20 -> "良好" to Color.Yellow
                            kotlin.math.abs(offsetMs) < 50 -> "一般" to Color(0xFFFF9800)
                            else -> "较差" to Color.Red
                        }
                        Text(accuracy.first, fontSize = 16.sp, fontWeight = FontWeight.Medium, color = accuracy.second)
                    }
                }
            }
        }
    }
    
    @Composable
    fun SyncControlCard(
        isSyncing: Boolean,
        isMonitoring: Boolean,
        isClient: Boolean,
        roundCount: Int,
        onRoundCountChange: (Int) -> Unit,
        onStartMeasurement: () -> Unit,
        onToggleMonitoring: () -> Unit
    ) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0xFF1A1A1A)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("测量轮数", fontSize = 13.sp, color = Color.Gray)
                    Spacer(modifier = Modifier.weight(1f))
                    
                    // 简单的轮数选择
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        listOf(5, 10, 20, 50).forEach { count ->
                            TextButton(
                                onClick = { onRoundCountChange(count) },
                                modifier = Modifier
                                    .background(
                                        if (roundCount == count) Color(0xFF00BCD4) else Color(0x33FFFFFF),
                                        RoundedCornerShape(4.dp)
                                    )
                                    .padding(horizontal = 8.dp, vertical = 4.dp)
                            ) {
                                Text("$count", fontSize = 12.sp, color = Color.White)
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(12.dp))
                
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = onStartMeasurement,
                        modifier = Modifier.weight(1f),
                        enabled = !isSyncing && isClient,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Color(0xFF00BCD4),
                            disabledContainerColor = Color.Gray
                        ),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        if (isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(16.dp),
                                color = Color.White,
                                strokeWidth = 2.dp
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                        Text(if (isSyncing) "测量中..." else "📏 精确测量", fontSize = 14.sp)
                    }
                    
                    Button(
                        onClick = onToggleMonitoring,
                        modifier = Modifier.weight(1f),
                        enabled = isClient,
                        colors = ButtonDefaults.buttonColors(
                            containerColor = if (isMonitoring) Color.Red else Color(0xFF9B59B6)
                        ),
                        shape = RoundedCornerShape(8.dp)
                    ) {
                        Text(
                            if (isMonitoring) "⏹ 停止" else "📊 监测",
                            fontSize = 14.sp
                        )
                    }
                }
                
                if (!isClient) {
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        "💡 只有「客户端」可以主动发起测量",
                        fontSize = 11.sp,
                        color = Color(0x80FFFFFF)
                    )
                }
            }
        }
    }
    
    @Composable
    fun InstructionsCard() {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0x0FFFFFFF)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("使用方法", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Color.White)
                Spacer(modifier = Modifier.height(8.dp))
                
                Text("1️⃣  iOS 和 Android 连接到同一 Wi-Fi", fontSize = 12.sp, color = Color.Gray)
                Text("2️⃣  iOS 选择「服务端」，记录 IP 地址", fontSize = 12.sp, color = Color.Gray)
                Text("3️⃣  Android 选择「客户端」，输入 iOS 的 IP", fontSize = 12.sp, color = Color.Gray)
                Text("4️⃣  连接后点击「精确测量」查看时间差", fontSize = 12.sp, color = Color.Gray)
            }
        }
    }
    
    @Composable
    fun HowItWorksCard() {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor = Color(0x0FFFFFFF)),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp)) {
                Text("📐 测量原理", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = Color.White)
                Spacer(modifier = Modifier.height(8.dp))
                
                Text("使用类 NTP 算法，通过 TCP 在局域网内直接测量：", fontSize = 12.sp, color = Color.Gray)
                Spacer(modifier = Modifier.height(8.dp))
                
                Text(
                    "offset = t₂ − (t₁ + t₄) / 2",
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Color.White
                )
                Text(
                    "RTT = t₄ − t₁（往返延迟）",
                    fontSize = 12.sp,
                    fontFamily = FontFamily.Monospace,
                    color = Color(0xFFFF9800)
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    "💡 局域网内 RTT 通常 <5ms，精度可达 ±1~3ms",
                    fontSize = 11.sp,
                    color = Color(0xB3FFEB3B)
                )
            }
        }
    }
    
    /**
     * 获取本机局域网 IP 地址
     */
    private fun getLocalIPAddress(): String {
        try {
            val interfaces = NetworkInterface.getNetworkInterfaces()
            for (intf in interfaces) {
                if (intf.name.startsWith("wlan0") || intf.name.startsWith("eth0")) {
                    val addresses = intf.inetAddresses
                    for (addr in addresses) {
                        if (!addr.isLoopbackAddress && addr.hostAddress?.contains(":") == false) {
                            return addr.hostAddress ?: "无法获取"
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return "无法获取"
    }
}
