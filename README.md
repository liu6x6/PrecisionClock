# PrecisionClock 精确时钟

一款跨平台（iOS / macOS）高精度时钟应用，支持毫秒级显示、多时钟源 NTP 网络对时，以及模拟圆盘时钟。适用于需要在两台设备之间精确同步时间的场景。

## 功能

### 🕐 数字时钟
- 实时显示 **时:分:秒.毫秒**
- 1 秒内 **200 格精细刻度**（每格 5ms）
- 毫秒进度条 + 滑动指示器
- 刻度下方显示数字标签，方便读取

### 🕰️ 模拟时钟
- 圆盘表盘 + 时/分/秒三根指针
- 秒针 **平滑连续运动**（非跳秒），100Hz 刷新
- 60 秒刻度 + 12 小时刻度 + 300 微型刻度
- 1-12 小时数字，圆角字体
- 深色径向渐变表盘 + 金属质感边框

### ⏱️ 秒表
- 开始 / 暂停 / 重置 / 计圈
- **500 格精细刻度**（每格 2ms），带数字标签
- 三环进度指示（秒 / 10毫秒 / 毫秒）
- 计圈列表，显示每圈用时和差值
- 120fps CADisplayLink 驱动（iOS），高频 Timer（macOS）

### 🌐 NTP 对时
- 真实 **NTP 协议**（UDP 123 端口）实现
- 支持 **10 个时钟源** 可选：

| 时钟源 | 地址 | 区域 |
|--------|------|------|
| 🍎 Apple | time.apple.com | 美国 |
| 🔵 Google | time.google.com | 全球 |
| 🟠 Cloudflare | time.cloudflare.com | 全球 |
| 🟡 阿里云 | ntp.aliyun.com | 中国 |
| 🔷 腾讯云 | ntp.tencent.com | 中国 |
| 🌏 Pool Asia | asia.pool.ntp.org | 亚洲 |
| 🇨🇳 Pool China | cn.pool.ntp.org | 中国 |
| 🇺🇸 US Naval Obs | time.nist.gov | 美国 |
| 🇩🇪 PTB 德国 | ptbtime1.ptb.de | 德国 |
| 🇯🇵 NICT 日本 | ntp.nict.jp | 日本 |

- 一键测量所有时钟源，多次测量取中位数
- 偏差排名可视化（绿色 <10ms / 黄色 <50ms / 红色 >50ms）
- 选择偏差最小的源作为主时钟，校准后时间实时显示

## 支持平台

| 平台 | 最低版本 |
|------|----------|
| iPhone | iOS 16.0 |
| iPad | iPadOS 16.0 |
| Mac | macOS 13.0 (Ventura) |

## 项目结构

```
PrecisionClock/
├── PrecisionClock.xcodeproj/
└── PrecisionClock/
    ├── PrecisionClockApp.swift    # APP 入口
    ├── ContentView.swift          # 主页面 TabView
    ├── ClockView.swift            # 数字时钟（刻度 + 进度条）
    ├── AnalogClockView.swift      # 模拟圆盘时钟（指针式）
    ├── StopwatchView.swift        # 秒表（计圈 + 三环进度）
    ├── SyncView.swift             # NTP 对时（时钟源选择 + 偏差排名）
    ├── NTPClient.swift            # NTP 协议客户端（UDP）
    ├── PrecisionTimer.swift       # 高精度计时器（跨平台）
    └── Assets.xcassets/           # 资源文件
```

## 架构说明

### 数据流

```
ContentView (TabView)
├── ClockView          → 直接使用 Date()，Timer.publish 1ms 刷新
├── AnalogClockView    → 直接使用 Date()，Timer.publish 10ms 刷新
├── StopwatchView      → PrecisionTimer (ObservableObject, CADisplayLink/Timer)
└── SyncView           → NTPManager (ObservableObject)
                            └── NTPClient.measure() → NTPMeasurement
```

### 跨平台处理

`PrecisionTimer.swift` 使用条件编译适配不同平台：

- **iOS**：`CADisplayLink`（最高 120fps，ProMotion 设备）
- **macOS**：`Timer`（120Hz 高频刷新）

其余所有视图均为纯 SwiftUI 通用代码，无需任何平台判断。

### NTP 协议实现

`NTPClient.swift` 实现了简化的 NTP v4 客户端：

1. 通过 `NWConnection`（UDP 端口 123）发送 48 字节 NTP 请求
2. 解析响应报文中的 Transmit Timestamp（NTP epoch → Unix epoch）
3. 使用标准 NTP 算法计算时间偏差和往返延迟：
   - `offset = ((t2 - t1) + (t3 - t4)) / 2`
   - `rtt = (t4 - t1) - (t3 - t2)`
4. 多次测量取中位数，提高准确性

### 刻度设计

刻度采用三级层次结构，数字标签从大到小：

| 级别 | 间隔 | 线宽 | 线高 | 颜色 | 数字大小 |
|------|------|------|------|------|----------|
| 主刻度 | 每 500ms (时钟) / 200ms (秒表) | 1.5px | 28/26px | 白色 | 9pt |
| 中刻度 | 每 250ms / 100ms | 1px | 20/18px | 灰色 | 8pt |
| 小刻度 | 每 50ms / 20ms | 0.5px | 12/11px | 淡灰 | 7pt |
| 微刻度 | 每 5ms / 2ms | 0.5px | 6/5px | 极淡 | 无 |

## 快速开始

### 环境要求

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

### 运行

```bash
# 克隆或下载项目后
open PrecisionClock.xcodeproj
```

在 Xcode 中：

1. 选择目标设备（iPhone / iPad / My Mac）
2. 配置 Signing Team（代码签名）
3. 点击 **▶ Run**

### 两台手机对时步骤

1. 两台手机都安装并打开此 APP
2. 进入 **NTP 对时** Tab
3. 点击右上角 **↻** 按钮一键测量所有时钟源
4. 选择偏差最小（绿色）的时钟源
5. 两台手机切换到 **数字时钟** 或 **模拟时钟** Tab
6. 对比两台手机上显示的毫秒数，差值即为时间偏差

## 技术栈

- **SwiftUI** — 声明式 UI
- **Combine** — 响应式数据流（Timer.publish, ObservableObject）
- **Network.framework** — NTP UDP 通信（NWConnection）
- **CoreAnimation** — CADisplayLink 高精度帧同步（iOS）

## License

MIT
