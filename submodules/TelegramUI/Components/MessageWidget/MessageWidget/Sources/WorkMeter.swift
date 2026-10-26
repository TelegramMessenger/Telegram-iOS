import Foundation
import QuartzCore

/// The units one core task has spent over every budget it ran on (the parse's, the boot's, a library's first install,
/// the validator's calls), for the handshake (spec 2026-10-15 D3): `crossed` runs once, on the task's thread, when they
/// reach `threshold` (the task's sync budget, past which main stops waiting). Read by main.
final class WorkMeter {
    let threshold: UInt64
    private let crossed: () -> Void
    private let lock = NSLock()
    private var units: UInt64 = 0
    private var fired = false

    init(threshold: UInt64, crossed: @escaping () -> Void = {}) {
        self.threshold = threshold
        self.crossed = crossed
    }

    func add(_ units: UInt64) {
        self.lock.lock()
        let (sum, overflow) = self.units.addingReportingOverflow(units)
        self.units = overflow ? .max : sum
        let fire = !self.fired && self.units >= self.threshold
        if fire {
            self.fired = true
        }
        self.lock.unlock()
        if fire {
            self.crossed()
        }
    }

    var spent: UInt64 {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.units
    }

    var hasCrossed: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.fired
    }
}
