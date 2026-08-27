# 跨平台设备对时 - 实施指南

## 📋 概述

本方案实现了 **iOS 和 Android 设备之间的毫秒级时间差测量**，使用局域网 TCP Socket 通信，采用类 NTP 算法。

---

## ✅ iOS 端（已完成）

### 已完成的工作

1. **核心文件**
   - `CrossPlatformSyncManager.swift` - TCP 连接管理和测量算法
   - `CrossPlatformSyncView.swift` - UI 界面

2. **功能特性**
   - ✅ TCP Server（NWListener）
   - ✅ TCP Client（NWConnection）
   - ✅ 显示本机 IP 地址
   - ✅ 多轮测量取中位数（5/10/20/50 轮可选）
   - ✅ 持续监测模式（每秒测量一次）
   - ✅ 偏差可视化（大号数字 + 颜色编码）
   - ✅ 测量详情（最小/最大/平均/中位数）

3. **UI 集成**
   - ✅ 新增第 6 个 Tab "跨平台"
   - ✅ 深色主题，与现有界面一致
   - ✅ 跨平台兼容（iOS + macOS）

### 文件位置

```
PrecisionClock/
├── PrecisionClock/
│   ├── CrossPlatformSyncManager.swift  (14KB)
│   ├── CrossPlatformSyncView.swift     (30KB)
│   └── ContentView.swift               (已更新，添加新 Tab)
```

---

## 🤖 Android 端（已完成）

### 已完成的工作

1. **项目结构**
   ```
   Android/
   ├── app/
   │   ├── build.gradle
   │   └── src/main/
   │       ├── AndroidManifest.xml
   │       └── java/com/precisionclock/crossplatform/
   │           ├── MainActivity.kt          (29KB)
   │           └── TimeSyncManager.kt       (10KB)
   ├── build.gradle
   └── settings.gradle
   ```

2. **核心功能**
   - ✅ TCP Server（ServerSocket）
   - ✅ TCP Client（Socket）
   - ✅ 显示本机 IP 地址
   - ✅ 多轮测量取中位数
   - ✅ 持续监测模式
   - ✅ Jetpack Compose UI
   - ✅ Kotlin Coroutines 异步处理

3. **技术栈**
   - Kotlin 1.9+
   - Jetpack Compose
   - Kotlin Coroutines
   - 最低版本：Android 8.0 (API 26)

### 如何运行

1. 用 Android Studio 打开 `Android/` 目录
2. Sync Gradle
3. 运行到 Android 设备

---

## 🔄 通信协议

### 消息格式

**传输层**：TCP，端口 12345  
**消息格式**：JSON，以换行符 `\n` 分隔

#### 1. 请求（客户端 → 服务端）

```json
{
  "type": "syncRequest",
  "t1": 1234567890.123456,
  "round": 1
}
```

- `t1`: 客户端发送时间（Unix timestamp，秒，浮点数）
- `round`: 当前轮次

#### 2. 响应（服务端 → 客户端）

```json
{
  "type": "syncResponse",
  "t1": 1234567890.123456,
  "t2": 1234567890.234567
}
```

- `t1`: 原始请求时间
- `t2`: 服务端接收时间

#### 3. 结果（客户端 → 服务端）

```json
{
  "type": "syncResult",
  "offset": 0.001234,
  "rtt": 0.005678
}
```

- `offset`: 中位数偏差（秒）
- `rtt`: 中位数往返延迟（秒）

### 测量算法

采用类 NTP 算法：

```
客户端 (iOS)                    服务端 (Android)
    │                               │
    │──── t1 发送请求 ─────────────►│
    │                               │ t2 收到请求
    │                               │ (立即回复)
    │◄──── t2 回复 ─────────────────│
    │ t4 收到回复                    │
    │                               │
    │  计算:                         │
    │  offset = t2 - (t1+t4)/2      │
    │  RTT = t4 - t1                │
```

**多轮测量取中位数**，消除网络抖动影响。

---

## 📱 使用步骤

### 场景 1：iOS 作为服务端，Android 作为客户端

#### iOS 设备

1. 打开 PrecisionClock APP
2. 进入「跨平台」Tab（第 6 个）
3. 点击「服务端」按钮
4. 记录显示的 IP 地址（如 192.168.1.100）

#### Android 设备

1. 打开跨平台对时 APP
2. 点击「客户端」按钮
3. 输入 iOS 的 IP 地址
4. 点击「连接」
5. 连接成功后点击「精确测量」
6. 等待 10 轮测量完成
7. 查看时间差结果

### 场景 2：Android 作为服务端，iOS 作为客户端

#### Android 设备

1. 打开跨平台对时 APP
2. 点击「服务端」按钮
3. 记录显示的 IP 地址

#### iOS 设备

1. 打开 PrecisionClock APP
2. 进入「跨平台」Tab
3. 点击「客户端」按钮
4. 输入 Android 的 IP 地址
5. 点击「连接」
6. 连接成功后点击「精确测量」
7. 查看结果

---

## 📊 精度说明

### 不同网络环境

| 网络环境 | RTT | 精度 | 推荐度 |
|---------|-----|------|--------|
| 5GHz Wi-Fi（同房间） | <3ms | ±1~2ms | ⭐⭐⭐⭐⭐ |
| 2.4GHz Wi-Fi | 5~15ms | ±3~8ms | ⭐⭐⭐⭐ |
| 有线局域网 | <2ms | ±1ms | ⭐⭐⭐⭐⭐ |
| 公共 Wi-Fi | 20~50ms | ±10~25ms | ⭐⭐ |

### 影响精度的因素

1. **网络延迟稳定性**：RTT 越小越稳定，结果越精确
2. **测量轮数**：轮数越多，中位数越准确（推荐 10~20 轮）
3. **设备负载**：CPU 占用高时可能影响时间戳精度
4. **Wi-Fi 信道拥堵**：高峰期可能增加延迟抖动

### 最佳实践

1. ✅ **使用 5GHz Wi-Fi**：延迟更低、更稳定
2. ✅ **同一房间**：减少路由跳转
3. ✅ **关闭其他网络应用**：减少带宽竞争
4. ✅ **多轮测量**：使用 20 轮以上取中位数
5. ✅ **持续监测**：观察偏差是否稳定

---

## 🔍 故障排查

### 无法连接

1. **检查 Wi-Fi**：确保两台设备在同一局域网
2. **检查 IP**：确认输入的 IP 地址正确
3. **检查防火墙**：确保端口 12345 未被封锁
4. **重启 APP**：有时需要重新启动服务端

### 精度差

1. **切换 5GHz Wi-Fi**：减少延迟
2. **增加测量轮数**：使用 20~50 轮
3. **关闭其他应用**：减少网络竞争
4. **靠近路由器**：减少信号衰减

### 测量失败

1. **检查权限**：Android 需要网络权限（已在 AndroidManifest.xml 中声明）
2. **检查端口**：确保 12345 端口可用
3. **查看日志**：检查连接状态信息

---

## 📚 技术细节

### iOS 端

- **框架**：Network.framework (NWListener + NWConnection)
- **语言**：Swift 5.9+
- **UI**：SwiftUI
- **最低版本**：iOS 16.0 / macOS 13.0
- **并发**：Swift Concurrency (async/await)

### Android 端

- **框架**：java.net.ServerSocket / Socket
- **语言**：Kotlin 1.9+
- **UI**：Jetpack Compose
- **最低版本**：Android 8.0 (API 26)
- **并发**：Kotlin Coroutines

### 通信协议

- **传输层**：TCP
- **端口**：12345
- **消息格式**：JSON
- **分隔符**：换行符 `\n`
- **时间戳精度**：毫秒级
  - iOS: `Date().timeIntervalSince1970`
  - Android: `System.currentTimeMillis() / 1000.0`

---

## 🎯 与 Apple 设备对时的对比

| 特性 | Apple 设备对时 | 跨平台对时 |
|------|--------------|-----------|
| 平台 | iOS ↔ iOS/Mac | iOS ↔ Android |
| 发现方式 | MultipeerConnectivity（自动） | 手动输入 IP |
| 连接方式 | Wi-Fi/蓝牙自动选择 | TCP Socket（需同一局域网） |
| 协议 | 自定义二进制 | JSON over TCP |
| 精度 | ±1~5ms | ±1~5ms（局域网） |
| 易用性 | ⭐⭐⭐⭐⭐（自动发现） | ⭐⭐⭐（需手动输入 IP） |

---

## 🚀 未来改进

1. **mDNS/Bonjour 自动发现**：减少手动输入 IP
2. **UDP 协议**：减少 TCP 握手开销，提高精度
3. **多设备同时测量**：支持 3+ 设备对比
4. **历史记录**：保存多次测量结果，绘制趋势图
5. **时钟漂移监测**：长期跟踪偏差变化
6. **NTP 服务器对比**：同时测量两台设备与 NTP 服务器的偏差

---

## 📄 文档

- `CROSS_PLATFORM_SYNC.md` - 详细技术文档
- `Android/` - Android 项目源码
- `PrecisionClock/CrossPlatformSync*.swift` - iOS 端代码

---

## 👨‍💻 开发者

- iOS 端：PrecisionClock 项目
- Android 端：PrecisionClock CrossPlatform

## 📝 License

MIT
