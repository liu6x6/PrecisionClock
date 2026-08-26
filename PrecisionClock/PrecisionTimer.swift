import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

class PrecisionTimer: ObservableObject {
    @Published var elapsedTime: TimeInterval = 0
    @Published var isRunning: Bool = false
    @Published var laps: [TimeInterval] = []

    private var startTime: Date?
    private var accumulatedTime: TimeInterval = 0

    #if canImport(UIKit)
    private var displayLink: CADisplayLink?
    #else
    private var timer: Timer?
    #endif

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startTime = Date()

        #if canImport(UIKit)
        let link = CADisplayLink(target: TimerProxy { [weak self] in
            self?.update()
        }, selector: #selector(TimerProxy.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
        #else
        // macOS: 使用高频 Timer (CADisplayLink 在 macOS 14+ 才可用)
        let t = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.update()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        #endif
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if let startTime = startTime {
            accumulatedTime += Date().timeIntervalSince(startTime)
        }
        startTime = nil

        #if canImport(UIKit)
        displayLink?.invalidate()
        displayLink = nil
        #else
        timer?.invalidate()
        timer = nil
        #endif

        update()
    }

    func reset() {
        stop()
        elapsedTime = 0
        accumulatedTime = 0
        laps = []
    }

    func lap() {
        guard isRunning else { return }
        laps.append(elapsedTime)
    }

    private func update() {
        if let startTime = startTime {
            elapsedTime = accumulatedTime + Date().timeIntervalSince(startTime)
        }
    }
}

#if canImport(UIKit)
// CADisplayLink needs an NSObject target
class TimerProxy: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) {
        self.handler = handler
    }
    @objc func tick() {
        handler()
    }
}
#endif
