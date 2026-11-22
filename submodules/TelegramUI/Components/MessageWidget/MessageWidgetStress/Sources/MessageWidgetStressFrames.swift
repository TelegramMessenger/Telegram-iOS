import Foundation
import UIKit

/// The client's own frames during a measuring window (CLIENTS.md, "Your frames"): the intervals between consecutive
/// callbacks of a CADisplayLink on the main run loop.
final class MessageWidgetStressFrames: NSObject {
    private var link: CADisplayLink?
    private var last: CFTimeInterval?
    private(set) var intervals: [Double] = []

    func start() {
        self.stop()
        self.intervals.removeAll()
        self.last = nil
        let link = CADisplayLink(target: self, selector: #selector(self.tick(_:)))
        link.preferredFrameRateRange = MessageWidgetStressRunner.frameRateRange(screen: UIScreen.main)
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    func stop() {
        self.link?.invalidate()
        self.link = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if let last = self.last {
            self.intervals.append((link.timestamp - last) * 1000.0)
        }
        self.last = link.timestamp
    }

    /// The run file's `frames`: count, p50, p95 and max of the intervals (ms), and the share of display frames missed at
    /// `refreshHz`: Σ(round(interval / period) − 1) / Σ round(interval / period).
    func summary(refreshHz: Double) -> [String: Any] {
        let sorted = self.intervals.sorted()
        func percentile(_ p: Double) -> Any {
            guard !sorted.isEmpty else {
                return NSNull()
            }
            let index = min(sorted.count - 1, Int((p * Double(sorted.count - 1)).rounded()))
            return round2(sorted[index])
        }
        let period = 1000.0 / max(refreshHz, 1.0)
        var missed = 0.0
        var total = 0.0
        for interval in sorted {
            let frames = max(1.0, (interval / period).rounded())
            missed += frames - 1.0
            total += frames
        }
        return [
            "count": self.intervals.count,
            "p50": percentile(0.5),
            "p95": percentile(0.95),
            "max": sorted.last.map { round2($0) as Any } ?? NSNull(),
            "dropped": total > 0 ? round4(missed / total) as Any : NSNull(),
            "longTaskMs": NSNull(),
            "mainThreadMsPerSec": NSNull(),
        ]
    }
}

func round2(_ value: Double) -> Double {
    return (value * 100.0).rounded() / 100.0
}

func round4(_ value: Double) -> Double {
    return (value * 10000.0).rounded() / 10000.0
}
