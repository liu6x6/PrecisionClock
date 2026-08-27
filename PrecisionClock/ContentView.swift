import SwiftUI

struct ContentView: View {
    @StateObject private var stopwatchTimer = PrecisionTimer()
    @StateObject private var ntpManager = NTPManager()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            ClockView()
                .tabItem {
                    Image(systemName: "clock")
                    Text("数字时钟")
                }
                .tag(0)

            AnalogClockView()
                .tabItem {
                    Image(systemName: "clock.badge")
                    Text("模拟时钟")
                }
                .tag(1)

            StopwatchView(timer: stopwatchTimer)
                .tabItem {
                    Image(systemName: "stopwatch")
                    Text("秒表")
                }
                .tag(2)

            SyncView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("NTP对时")
                }
                .tag(3)

            DeviceSyncView()
                .tabItem {
                    Image(systemName: "two.iphones")
                    Text("设备对时")
                }
                .tag(4)

            CrossPlatformSyncView()
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("跨平台")
                }
                .tag(5)
        }
        .preferredColorScheme(.dark)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
