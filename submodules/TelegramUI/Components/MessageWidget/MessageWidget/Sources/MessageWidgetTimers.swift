import Foundation

/// A timer the engine set. Cancelled from the core's thread (`clearTimeout`, a kill); fired on main.
final class MessageWidgetTimerHandle {
    private let lock = NSLock()
    private var cancelled = false
    private var timer: Timer?

    var isCancelled: Bool {
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        return self.cancelled
    }

    /// Any thread: the block will not run after this returns, and the run-loop timer lets go of it on main soon after.
    func cancel() {
        self.lock.lock()
        self.cancelled = true
        let timer = self.timer
        self.timer = nil
        self.lock.unlock()
        if let timer {
            DispatchQueue.main.async {
                timer.invalidate()
            }
        }
    }

    fileprivate func setTimer(_ timer: Timer?) {
        self.lock.lock()
        self.timer = timer
        self.lock.unlock()
    }
}

/// Where a widget's engine timers fire (spec 2026-10-15 D6): main's run loop, in the common modes, so they keep firing
/// while a list scrolls. A fire is handed to `fire` with its key (`timer-<id>`, `wake`), which queues it as a task of
/// the widget's; the block itself runs in that task, and not at all if the timer was cancelled by then.
final class MessageWidgetTimers {
    /// Main: set once by the owner, before any timer can be scheduled.
    var fire: ((_ key: String, _ body: @escaping () -> Void) -> Void)?

    init() {
    }

    /// Callable from any thread (CFRunLoopAddTimer is thread-safe).
    func schedule(after delay: TimeInterval, key: String, _ block: @escaping () -> Void) -> MessageWidgetTimerHandle {
        let handle = MessageWidgetTimerHandle()
        let timer = Timer(timeInterval: max(0.0, delay), repeats: false, block: { [weak self] _ in
            handle.setTimer(nil)
            guard let fire = self?.fire, !handle.isCancelled else {
                return
            }
            fire(key) {
                if !handle.isCancelled {
                    block()
                }
            }
        })
        handle.setTimer(timer)
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
        return handle
    }
}
