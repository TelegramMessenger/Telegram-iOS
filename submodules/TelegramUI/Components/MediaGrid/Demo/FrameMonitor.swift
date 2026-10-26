import UIKit

final class FrameMonitor {
    struct Summary {
        var frames: Int
        var dropped: Int
        var worst: Double
        var average: Double
    }

    private struct Sample {
        var timestamp: CFTimeInterval
        var interval: Double
    }

    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval?
    private var window: [Sample] = []
    private var windowHead = 0
    private var lastUpdate: CFTimeInterval = 0.0
    private var frames = 0
    private var dropped = 0
    private var total = 0.0
    private var worstOverall = 0.0

    var onUpdate: ((Summary) -> Void)?

    func start() {
        guard self.displayLink == nil else {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(self.tick(_:)))
        if #available(iOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60.0, maximum: 120.0, preferred: 120.0)
        }
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    func stop() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.lastTimestamp = nil
    }

    func reset() {
        self.window = []
        self.windowHead = 0
        self.frames = 0
        self.dropped = 0
        self.total = 0.0
        self.worstOverall = 0.0
        self.lastTimestamp = nil
    }

    var summary: Summary {
        var worst = 0.0
        for index in self.windowHead ..< self.window.count {
            worst = max(worst, self.window[index].interval)
        }
        return Summary(frames: self.frames, dropped: self.dropped, worst: worst, average: self.frames > 0 ? self.total / Double(self.frames) : 0.0)
    }

    var overallWorst: Double {
        return self.worstOverall
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer {
            self.lastTimestamp = link.timestamp
        }
        guard let last = self.lastTimestamp else {
            return
        }
        let interval = link.timestamp - last
        let expected = link.targetTimestamp - link.timestamp
        self.frames += 1
        self.total += interval
        self.worstOverall = max(self.worstOverall, interval)
        if expected > 0.0 && interval > 1.5 * expected {
            self.dropped += 1
        }
        self.window.append(Sample(timestamp: link.timestamp, interval: interval))
        let cutoff = link.timestamp - 5.0
        while self.windowHead < self.window.count && self.window[self.windowHead].timestamp < cutoff {
            self.windowHead += 1
        }
        if self.windowHead > 512 {
            self.window.removeFirst(self.windowHead)
            self.windowHead = 0
        }
        if link.timestamp - self.lastUpdate >= 0.1 {
            self.lastUpdate = link.timestamp
            self.onUpdate?(self.summary)
        }
    }
}
