# PrecisionClock — AI 开发指南

> 本文档专为 AI 辅助开发设计。提供项目全貌、架构决策、代码约定和扩展指引，帮助 AI 快速理解项目并继续开发。

---

## 1. 项目概述

**PrecisionClock（精确时钟）** 是一款跨平台 SwiftUI 应用，提供高精度时钟显示和网络对时功能。

| 属性 | 值 |
|------|-----|
| 语言 | Swift 5.9+ |
| 框架 | SwiftUI (纯声明式) |
| 最低版本 | iOS 16.0 / macOS 13.0 |
| 架构模式 | MVVM (SwiftUI 原生) |
| 数据流 | 单向：Model → @Published → View |
| 并发 | Combine + Swift Concurrency (async/await) |

---

## 2. 文件结构与职责

```
PrecisionClock/
├── PrecisionClock.xcodeproj/
│   └── project.pbxproj              # Xcode 项目配置（多平台 target）
├── PrecisionClock/
│   ├── PrecisionClockApp.swift      # @main 入口 (10行)
│   ├── ContentView.swift            # TabView 容器 (46行)
│   ├── ClockView.swift              # 数字时钟页面 (216行)
│   ├── AnalogClockView.swift        # 模拟圆盘时钟 (368行)
│   ├── StopwatchView.swift          # 秒表页面 (310行)
│   ├── SyncView.swift               # NTP 对时页面 (479行)
│   ├── NTPClient.swift              # NTP 协议实现 (284行)
│   ├── PrecisionTimer.swift         # 跨平台高精度计时器 (90行)
│   └── Assets.xcassets/             # 资源文件
└── docs/                            # 文档目录
```

**代码量**：总计 ~1800 行 Swift 代码（8 个文件）。

---

## 3. 架构总览

```
┌─────────────────────────────────────────────────────────┐
│                     PrecisionClockApp                     │
│                      (@main 入口)                         │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│                      ContentView                          │
│                    (TabView × 4)                          │
├──────────┬──────────┬──────────────┬────────────────────┤
│ 数字时钟 │ 模拟时钟  │   秒表       │   NTP 对时          │
│ ClockView│ AnalogClk│ StopwatchView│   SyncView          │
│          │ View     │              │                     │
│ 依赖:    │ 依赖:    │ 依赖:        │ 依赖:               │
│ Date()   │ Date()   │PrecisionTmr │ NTPManager          │
│ Timer    │ Timer    │CADisplayLink│  └─ NTPClient       │
│ publish  │ publish  │/Timer       │     └─ NWConnection │
└──────────┴──────────┴──────────────┴────────────────────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
     ┌──────────────┐ ┌─────────┐ ┌──────────────┐
     │PrecisionTimer│ │NTPClient│ │ 系统时钟      │
     │(ObservableObj)│ │(async)  │ │ Date()       │
     │              │ │         │ │ gettimeofday  │
     │CADisplayLink │ │UDP 123  │ │              │
     │/Timer 120Hz  │ │NTP v4   │ │              │
     └──────────────┘ └─────────┘ └──────────────┘
```

---

## 4. 核心模块详解

### 4.1 PrecisionTimer（高精度计时器）

**文件**：`PrecisionTimer.swift` (~90行)

**职责**：秒表核心引擎，提供 start/stop/reset/lap 操作。

**跨平台策略**：
```swift
#if canImport(UIKit)
// iOS: CADisplayLink (最高 120fps ProMotion)
private var displayLink: CADisplayLink?
#else
// macOS: Timer (120Hz)
private var timer: Timer?
#endif
```

**时间计算逻辑**：
```swift
elapsedTime = accumulatedTime + Date().timeIntervalSince(startTime)
//           ^^^^^^^^^^^^^^^^   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
//           暂停期间累积的时间    当前运行期间的增量
```

**状态机**：
```
idle ──start()──→ running ──stop()──→ paused ──start()──→ running
  ↑                 │                   │                   │
  └──── reset() ←──┘                   └─── reset() ───────┘
                    │
                    └──lap()──→ 追加到 laps[]
```

### 4.2 NTPClient（NTP 协议客户端）

**文件**：`NTPClient.swift` (~284行)

**职责**：通过 UDP 端口 123 与 NTP 服务器通信，计算时间偏差。

**NTP 报文结构**（48 字节）：
```
Byte 0:   LI(2bit) | VN(3bit)=4 | Mode(3bit)=3(client) → 0x23
Byte 1-39: 填充 0
Byte 40-47: Transmit Timestamp (64-bit, NTP epoch 1900-01-01)
```

**时间计算**：
```swift
// NTP 算法
// t1 = 发送请求时间, t2 = 服务器接收时间
// t3 = 服务器发送时间, t4 = 收到响应时间
offset = ((t2 - t1) + (t3 - t4)) / 2    // 时间偏差
rtt    = (t4 - t1) - (t3 - t2)           // 往返延迟

// epoch 转换
ntpEpochDiff = 2208988800  // 1900→1970 的秒数差
```

**关键类**：
| 类/结构体 | 职责 |
|-----------|------|
| `NTPServer` | 服务器定义（host, flag, region） |
| `NTPClient.query()` | 单次 NTP 查询（静态方法，async throws） |
| `NTPClient.measure()` | 多次测量取中位数（默认 5 轮） |
| `NTPManager` | ObservableObject，管理所有测量结果和选中服务器 |
| `NTPMeasurement` | 单次测量结果（offset, rtt, ntpTime） |

**可用时钟源**（21 个）：
```swift
NTPServer.allServers: [
    // 科技巨头
    apple, google, google1~4, android,  // Apple/Google/Android
    cloudflare, aws, microsoft,         // Cloudflare/AWS/Microsoft
    facebook, ubuntu,                   // Facebook/Ubuntu
    // 中国
    ntp.aliyun, ntp.tencent,            // 阿里云/腾讯云
    ntsc, cn_ntp,                       // 国家授时中心/中国池
    // NTP Pool
    pool_asia, pool_cn,                 // 亚洲/中国池
    // 国家级计量机构
    usno, ptb, nict                     // 美国/德国/日本
]
```

### 4.3 ClockView（数字时钟）

**文件**：`ClockView.swift` (~216行)

**时间源**：`Date()` — 直接读取系统时钟，无 NTP 校准。

**刷新机制**：`Timer.publish(every: 0.001, ...)` — 每 1ms 刷新一次。

**刻度系统**（FineScaleView，200 格）：
```
每格 = 5ms (1秒 ÷ 200)

主刻度 (i%100==0):  线宽 1.5px, 高 28px, 白色,  数字 9pt  → 每 500ms
中刻度 (i%50==0):   线宽 1.0px, 高 20px, 灰色,  数字 8pt  → 每 250ms
小刻度 (i%10==0):   线宽 0.5px, 高 12px, 淡灰,  数字 7pt  → 每 50ms
微刻度 (其他):      线宽 0.5px, 高 6px,  极淡,  无数字    → 每 5ms
```

**组件**：
- `MicrosecondBar` — 毫秒进度条（0~1秒内位置）
- `FineScaleView` — 精细刻度 + 数字标签 + 三角指示器
- `Triangle` — Shape（三角形游标）

### 4.4 AnalogClockView（模拟时钟）

**文件**：`AnalogClockView.swift` (~368行)

**时间源**：`Date()` — 直接读取系统时钟。

**刷新机制**：`Timer.publish(every: 0.01, ...)` — 每 10ms 刷新（100fps）。

**指针角度计算**：
```swift
// 时针: 每小时30° + 每分钟0.5° + 每秒微调
hourAngle = (hour/12)*360 + (totalSeconds/3600)*30

// 分针: 每分钟6° + 每秒0.1° + 纳秒微调
minuteAngle = (minute/60)*360 + ((second+nano)/60)*6

// 秒针: 平滑连续运动
secondAngle = (second + nano/1e9) / 60 * 360
```

**自定义 Shape 组件**：
| 组件 | 说明 |
|------|------|
| `ClockFace` | 表盘（径向渐变 + 金属边框） |
| `ClockTicks` | 60 秒刻度 + 300 微刻度 |
| `ClockNumbers` | 1-12 数字（圆形排列） |
| `ClockHand` | 时/分针（菱形 + 尾部） |
| `SecondHand` | 秒针（细线 + 圆形配重） |
| `TickMark` / `MiniTickMark` | 刻度线 Shape |

### 4.5 StopwatchView（秒表）

**文件**：`StopwatchView.swift` (~310行)

**时间源**：`PrecisionTimer`（ObservableObject）。

**刻度系统**（StopwatchScale，500 格）：
```
每格 = 2ms (1秒 ÷ 500)

主刻度 (i%100==0):  每 200ms, 线高 26px, 白色,  数字 9pt
中刻度 (i%50==0):   每 100ms, 线高 18px, 灰色,  数字 8pt
小刻度 (i%10==0):   每 20ms,  线高 11px, 淡灰,  数字 7pt
微刻度 (其他):      每 2ms,   线高 5px,  极淡,  无数字
```

**组件**：
| 组件 | 说明 |
|------|------|
| `StopwatchScale` | 500 格精细刻度 + 数字标签 |
| `NanoProgressRing` | 三环进度（秒/10ms/ms） |
| `LapListView` | 计圈列表（显示差值） |

### 4.6 SyncView（NTP 对时）

**文件**：`SyncView.swift` (~479行)

**时间源**：NTP 校准后的时间 = `Date() - ntpOffset`。

**注意**：不使用 `NavigationView`（macOS 不兼容），改用自定义标题栏。

**组件**：
| 组件 | 说明 |
|------|------|
| `SelectedServerCard` | 当前选中服务器的偏差/延迟显示 |
| `CorrectedClockCard` | 校准后的时钟 + 微型刻度 |
| `ServerListSection` | 10 个服务器列表（可选中/可单独测量） |
| `ServerRow` | 单个服务器行（名称/偏差/RTT/测量按钮） |
| `MeasurementResultsSection` | 偏差排名列表 |
| `OffsetBar` | 偏差可视化条（中心线 + 左右偏移） |
| `InstructionsCard` | 对时操作说明 |
| `MiniScale` | 100 格微型刻度 |

---

## 5. 数据模型

### 5.1 核心数据结构

```swift
// 服务器定义
struct NTPServer: Identifiable, Hashable {
    let id: String      // "apple", "google", ...
    let name: String    // "Apple", "Google", ...
    let host: String    // "time.apple.com"
    let flag: String    // "🍎", "🔵", ...
    let region: String  // "美国", "全球", ...
}

// 测量结果
struct NTPMeasurement: Identifiable {
    let id: UUID
    let server: NTPServer
    let offset: TimeInterval    // 偏差（秒）
    let rtt: TimeInterval       // 往返延迟（秒）
    let ntpTime: Date           // 校准后的 NTP 时间
    let timestamp: Date         // 测量时间
    let success: Bool
    let error: String?
}
```

### 5.2 ObservableObject 层次

```
@main PrecisionClockApp
  └── ContentView
        ├── @StateObject stopwatchTimer: PrecisionTimer
        │     ├── @Published elapsedTime: TimeInterval
        │     ├── @Published isRunning: Bool
        │     └── @Published laps: [TimeInterval]
        │
        └── SyncView
              └── @StateObject ntpManager: NTPManager
                    ├── @Published measurements: [String: NTPMeasurement]
                    ├── @Published selectedServerId: String
                    ├── @Published isMeasuring: Bool
                    └── @Published correctedOffset: TimeInterval
```

---

## 6. 跨平台适配

### 6.1 条件编译

项目中仅有一处条件编译，位于 `PrecisionTimer.swift`：

```swift
#if canImport(UIKit)
// iOS/iPadOS: 使用 CADisplayLink
#else
// macOS: 使用 Timer
#endif
```

### 6.2 macOS 兼容性注意事项

| API | iOS | macOS | 状态 |
|-----|-----|-------|------|
| `Timer.publish` | ✅ | ✅ | 通用 |
| `DateFormatter` | ✅ | ✅ | 通用 |
| `Calendar` | ✅ | ✅ | 通用 |
| `NWConnection` | ✅ | ✅ (10.14+) | 通用 |
| `CADisplayLink` | ✅ | ❌ (14+才有) | 已条件编译 |
| `NavigationView` | ✅ | ⚠️ 部分可用 | 已移除，改用自定义标题栏 |
| `navigationBarTitleDisplayMode` | ✅ | ❌ | 已移除 |
| `toolbarColorScheme` | ✅ | ❌ | 已移除 |
| `TabView` | ✅ | ✅ | 通用 |
| `GeometryReader` | ✅ | ✅ | 通用 |
| `@StateObject` | ✅ | ✅ | 通用 |

### 6.3 已知限制

1. **Timer 精度**：`Timer.publish(every: 0.001, ...)` 实际精度受系统调度影响，macOS 上可能有 ±5ms 抖动
2. **CADisplayLink macOS 14+**：macOS 14 开始可用，但本项目为兼容 macOS 13 仍使用 Timer
3. **NTP UDP**：部分网络可能封锁 UDP 123 端口，需要回退到 HTTP 时间源

---

## 7. 关键流程图

### 7.1 NTP 对时流程

```
用户点击 "一键测量"
         │
         ▼
  NTPManager.measureAll()
         │
         ├── for each server in NTPServer.allServers (并发):
         │        │
         │        ▼
         │   NTPClient.measure(server, rounds=3)
         │        │
         │        ├── for round in 1...3:
         │        │     │
         │        │     ├── t1 = Date()  (发送时间)
         │        │     ├── NWConnection.send(48字节 NTP 请求) → UDP:123
         │        │     ├── NWConnection.receive() → 48字节响应
         │        │     ├── t4 = Date()  (接收时间)
         │        │     ├── 解析 bytes[40-47] → transmitTimestamp
         │        │     ├── 转换 epoch: seconds - 2208988800
         │        │     ├── offset = ((t2-t1) + (t3-t4)) / 2
         │        │     └── rtt = (t4-t1) - (t3-t2)
         │        │
         │        ├── 取 offset[] 的中位数
         │        └── 返回 NTPMeasurement
         │
         ├── 更新 measurements[serverId] = measurement
         └── 更新 correctedOffset (选中服务器的偏差)
```

### 7.2 秒表计时流程

```
用户点击 "开始"
       │
       ▼
PrecisionTimer.start()
       │
       ├── startTime = Date()
       ├── 启动刷新循环:
       │     iOS:   CADisplayLink (120fps)
       │     macOS: Timer (120Hz)
       │
       ▼ (每帧回调)
update()
       │
       └── elapsedTime = accumulatedTime + Date() - startTime
              │
              ├── @Published → SwiftUI 自动刷新 View
              ├── 刻度指示器位置 = fraction * width
              ├── 进度环 trim = fraction
              └── 数字显示 = formatter(elapsedTime)

用户点击 "暂停"
       │
       ▼
PrecisionTimer.stop()
       │
       ├── accumulatedTime += Date() - startTime
       ├── startTime = nil
       └── 停止刷新循环
```

### 7.3 时间源对比

```
┌──────────────────────────────────────────────────┐
│                 所有时间来自同一源                   │
│                Date() → gettimeofday()            │
│                → 系统内核时钟 (mach_absolute_time)  │
└───────────────────────┬──────────────────────────┘
                        │
        ┌───────────────┼───────────────┐
        ▼               ▼               ▼
  ┌───────────┐  ┌───────────┐  ┌──────────────┐
  │ 数字时钟   │  │ 模拟时钟   │  │ NTP 校准时钟  │
  │ Date()    │  │ Date()    │  │ Date()-offset │
  │ 1ms 刷新  │  │ 10ms 刷新 │  │ 1ms 刷新      │
  │ = 系统时间 │  │ = 系统时间 │  │ ≈ NTP标准时间  │
  └───────────┘  └───────────┘  └──────────────┘
                                        │
                                        ▼
                               偏差来源: NTP 服务器
                               精度: ±10~50ms (取决于网络)
```

---

## 8. 样式与设计约定

### 8.1 颜色主题
- **主色调**：深色模式（`Color.black` 背景）
- **文字**：白色（主）、灰色（次）、`Color.gray.opacity(0.3)` (极次)
- **功能色**：
  - 时钟/刻度：`Color.cyan`（蓝色系）
  - 秒表：`Color.green`（绿色系）
  - 模拟时钟秒针：`Color.red`
  - 偏差指示：绿(<10ms) / 黄(<50ms) / 红(>50ms)

### 8.2 字体
- 所有数字使用 `.monospaced` + `.monospacedDigit()` 防止数字跳动
- 时钟数字：`design: .monospaced`，`weight: .thin` / `.ultraLight`
- 刻度标签：`design: .monospaced`，`weight: .light`

### 8.3 组件风格
- 所有圆角使用 `cornerRadius: 12`（卡片）或 `4`（小元素）
- 背景使用 `Color.gray.opacity(0.06~0.1)` 作为卡片背景
- 发光效果使用 `.shadow(color:, radius:)`

---

## 9. 扩展指引

### 9.1 可以添加的功能（按优先级）

| 功能 | 难度 | 涉及文件 | 说明 |
|------|------|----------|------|
| 闹钟功能 | ⭐⭐ | 新增 AlarmView.swift | 定时提醒 + 通知 |
| 世界时钟 | ⭐⭐ | 新增 WorldClockView.swift | 多时区显示 |
| 倒计时 | ⭐⭐ | 新增 CountdownView.swift | 倒计时 + 提醒 |
| 真正 HTTP 时间源 | ⭐⭐⭐ | 修改 NTPClient.swift | 添加 HTTPS 时间 API 作为备用 |
| 蓝牙时间同步 | ⭐⭐⭐⭐ | 新增 BluetoothSync.swift | 设备间直接对时 |
| 表盘主题 | ⭐⭐ | 修改 AnalogClockView.swift | 多种表盘风格 |
| Widget 小组件 | ⭐⭐⭐ | 新增 Widget Extension | 桌面时钟 |
| Apple Watch 版本 | ⭐⭐⭐ | 新增 watchOS target | 手表同步 |
| 网络延迟测试 | ⭐⭐ | 修改 SyncView.swift | ping 测试 + 图表 |

### 9.2 添加新页面的模板

```swift
import SwiftUI

struct NewFeatureView: View {
    // 1. 状态
    @State private var someState = ...

    var body: some View {
        VStack {
            // 2. 布局
        }
        .background(Color.black.ignoresSafeArea())
        // 3. 如果需要高频刷新:
        // .onReceive(Timer.publish(every: 0.001, ...).autoconnect()) { _ in }
    }
}
```

在 `ContentView.swift` 的 `TabView` 中添加新 Tab：

```swift
NewFeatureView()
    .tabItem {
        Image(systemName: "icon.name")
        Text("新功能")
    }
    .tag(N)  // N = 下一个数字
```

### 9.3 macOS 兼容性检查清单

添加新功能前，确认不使用以下 iOS 专有 API：
- ❌ `NavigationView` + `navigationBarTitleDisplayMode`
- ❌ `toolbarColorScheme(.dark, for: .navigationBar)`
- ❌ `ToolbarItem(placement: .navigationBarTrailing)`
- ❌ `CADisplayLink`（除非用 `#if canImport(UIKit)` 包裹）
- ❌ `UIApplication` / `UIDevice` / `UIScreen`
- ❌ `UIWindow` / `UIViewController`

使用以下跨平台 API 代替：
- ✅ 自定义 `HStack` 标题栏（代替 NavigationView）
- ✅ `Timer`（代替 CADisplayLink，或条件编译）
- ✅ `TabView` / `ScrollView` / `VStack` / `HStack`
- ✅ `@State` / `@StateObject` / `@Published`
- ✅ `NWConnection` (Network.framework)

---

## 10. 构建与运行

```bash
# 打开项目
open ~/PrecisionClock/PrecisionClock.xcodeproj

# 命令行构建 (macOS)
xcodebuild -project PrecisionClock.xcodeproj \
  -scheme PrecisionClock \
  -destination 'platform=macOS' \
  build

# 命令行构建 (iOS Simulator)
xcodebuild -project PrecisionClock.xcodeproj \
  -scheme PrecisionClock \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  build

# 清理
xcodebuild -project PrecisionClock.xcodeproj \
  -scheme PrecisionClock \
  clean
```

---

## 11. 项目配置关键参数

**project.pbxproj 中的关键设置**：

| 设置 | 值 | 说明 |
|------|-----|------|
| `IPHONEOS_DEPLOYMENT_TARGET` | 16.0 | iOS 最低版本 |
| `MACOSX_DEPLOYMENT_TARGET` | 13.0 | macOS 最低版本 |
| `SDKROOT` | auto | 自动适配平台 |
| `SUPPORTED_PLATFORMS` | iphoneos iphonesimulator macosx | 多平台 |
| `SWIFT_VERSION` | 5.0 | Swift 版本 |
| `PRODUCT_BUNDLE_IDENTIFIER` | com.precisionclock.app | Bundle ID |
| `INFOPLIST_KEY_CFBundleDisplayName` | 精确时钟 | 显示名称 |

---

## 12. 已知问题与技术债

1. **Timer.publish 精度**：设置 `every: 0.001` 但实际精度受系统调度限制，可能 ±5ms
2. **NTP 无重试**：单次失败不会自动重试
3. **无持久化**：测量结果、选中服务器在 app 重启后丢失（可添加 UserDefaults）
4. **模拟时钟刷新**：10ms (100fps) 在非 ProMotion 设备上浪费刷新（60fps 足够）
5. **NTP 报文验证**：未校验 Leap Indicator 和 Stratum 字段

---

## 13. AI 开发约定

1. **修改代码前先阅读本文档**，了解架构和约定
2. **新文件遵循现有命名**：`XxxView.swift` (视图)、`XxxManager.swift` (管理器)
3. **所有数字显示**必须使用 `.monospacedDigit()` 和 `design: .monospaced`
4. **新增 View 默认深色背景**：`.background(Color.black.ignoresSafeArea())`
5. **避免引入 iOS 专有 API**，如必须使用请用 `#if os(iOS)` 或 `#if canImport(UIKit)` 条件编译
6. **刻度系统遵循四级层次**：主/中/小/微，数字标签仅主/中/小
7. **时间源选择**：
   - 显示当前时间 → `Date()` + `Timer.publish`
   - 需要高精度 → `PrecisionTimer` (ObservableObject)
   - 需要标准时间 → `NTPManager` + `NTPClient`
