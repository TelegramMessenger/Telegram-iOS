import Foundation
import SwiftSignalKit

/// Time and delayed execution, injected so the registry's grace and backoff windows are
/// deterministic under test rather than depending on wall-clock sleeps.
public protocol PreuploadScheduler: AnyObject {
    func now() -> Double
    func after(_ delay: Double, _ f: @escaping () -> Void) -> Disposable
}

/// Production scheduler: real time, real timers on a caller-supplied queue.
public final class QueuePreuploadScheduler: PreuploadScheduler {
    private let queue: Queue

    public init(queue: Queue) {
        self.queue = queue
    }

    public func now() -> Double {
        return CFAbsoluteTimeGetCurrent()
    }

    public func after(_ delay: Double, _ f: @escaping () -> Void) -> Disposable {
        let timer = SwiftSignalKit.Timer(timeout: delay, repeat: false, completion: f, queue: self.queue)
        timer.start()
        return ActionDisposable {
            timer.invalidate()
        }
    }
}

/// Test scheduler: time only moves when the test moves it. Shipped alongside the production one so
/// every consumer's tests drive the registry the same way.
public final class ManualPreuploadScheduler: PreuploadScheduler {
    private final class Pending {
        let fireAt: Double
        let action: () -> Void
        var cancelled: Bool = false

        init(fireAt: Double, action: @escaping () -> Void) {
            self.fireAt = fireAt
            self.action = action
        }
    }

    private var currentTime: Double = 0.0
    private var pending: [Pending] = []

    public init() {
    }

    public func now() -> Double {
        return self.currentTime
    }

    public func after(_ delay: Double, _ f: @escaping () -> Void) -> Disposable {
        let item = Pending(fireAt: self.currentTime + delay, action: f)
        self.pending.append(item)
        return ActionDisposable {
            item.cancelled = true
        }
    }

    /// Advance the clock, firing every timer whose deadline has passed, in deadline order.
    public func advance(by delta: Double) {
        self.currentTime += delta
        while true {
            let due = self.pending
                .filter { !$0.cancelled && $0.fireAt <= self.currentTime }
                .sorted { $0.fireAt < $1.fireAt }
            guard let next = due.first else {
                break
            }
            self.pending.removeAll { $0 === next }
            next.action()
        }
        self.pending.removeAll { $0.cancelled }
    }

    /// Number of live (uncancelled, unfired) timers — lets a test assert that a grace timer was
    /// cancelled rather than merely never observed to fire.
    public var pendingCount: Int {
        return self.pending.filter { !$0.cancelled }.count
    }
}
