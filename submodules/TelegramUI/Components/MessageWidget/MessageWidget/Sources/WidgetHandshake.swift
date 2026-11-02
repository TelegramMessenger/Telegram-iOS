import Foundation
import QuartzCore

/// How long main waits for the widget work it starts (spec 2026-10-15 D3).
public struct MessageWidgetWaitPolicy: Equatable {
    /// The wall time main waits over every task of one run-loop turn; nil: no cap. Never a verdict: it only ends a wait.
    public var cap: TimeInterval?

    public init(cap: TimeInterval?) {
        self.cap = cap
    }

    /// The app's: a 20 ms cap per run-loop turn (the CPU-clock limits design: the unit allowance went with the units).
    public static let standard = MessageWidgetWaitPolicy(cap: 0.020)
    /// Tests: every wait ends with its task, as when everything ran on main.
    public static let unbounded = MessageWidgetWaitPolicy(cap: nil)
}

/// What main may still wait for in the current run-loop turn: one cap of time over every waited task (spec D3, D8). It
/// resets when main's run loop next waits (`beforeWaiting`, in the common modes, so a scroll's turns count too). Main
/// only.
public final class MessageWidgetTurn {
    public static let shared = MessageWidgetTurn()

    private(set) var timeWaited: TimeInterval = 0
    private var observer: CFRunLoopObserver?

    public init() {
        let observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { [weak self] _, _ in
            self?.reset()
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    deinit {
        if let observer = self.observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
    }

    func reset() {
        self.timeWaited = 0
    }

    func remainingTime(_ policy: MessageWidgetWaitPolicy) -> TimeInterval? {
        guard let cap = policy.cap else {
            return nil
        }
        return max(0.0, cap - self.timeWaited)
    }

    func record(time: TimeInterval) {
        self.timeWaited += time
    }
}

/// One task's handshake: the core completes it exactly once; main waits on it at most once. The task's result goes to
/// `deposit` when it completes, on the core's thread, so results are deposited in the order their tasks ran. The ways
/// a wait ends (the task completed, the timeout passed) race the completion under one lock: a completion main stopped
/// waiting for also calls `late`, so the result is applied without a wait.
final class WidgetTicket<Result> {
    private let lock = NSLock()
    private let wake: DispatchSemaphore
    private let deposit: (Result) -> Void
    private let late: () -> Void
    private var completed = false
    private var abandoned = false

    init(deposit: @escaping (Result) -> Void, late: @escaping () -> Void) {
        self.wake = DispatchSemaphore(value: 0)
        self.deposit = deposit
        self.late = late
    }

    /// Core: deposits the task's result, then wakes the waiting main thread, or calls `late` once main stopped waiting.
    func complete(_ result: Result) {
        self.deposit(result)
        self.lock.lock()
        if self.abandoned {
            self.lock.unlock()
            self.late()
            return
        }
        self.completed = true
        self.lock.unlock()
        self.wake.signal()
    }

    /// Main: waits until the task completes (true) or `timeout` passes (nil: no timeout); then false, and `late` will be
    /// called when it completes. A zero timeout does not wait at all.
    func wait(timeout: TimeInterval?) -> Bool {
        if timeout.map({ $0 > 0.0 }) ?? true {
            let deadline = timeout.map { DispatchTime.now() + $0 }
            while true {
                let signalled: Bool
                if let deadline {
                    signalled = self.wake.wait(timeout: deadline) == .success
                } else {
                    self.wake.wait()
                    signalled = true
                }
                if !signalled {
                    break
                }
                self.lock.lock()
                let done = self.completed
                self.lock.unlock()
                if done {
                    break
                }
            }
        }
        self.lock.lock()
        defer {
            self.lock.unlock()
        }
        if self.completed {
            return true
        }
        self.abandoned = true
        return false
    }
}

/// A widget's main-side handshake (spec D3): queues its tasks, waits for them within the turn's cap, and
/// applies their results on main in task order. Every result enters the mailbox when its task completes, in the order
/// the tasks ran, and main applies only from the mailbox: a run that finished within its wait drains it before
/// returning, and one that did not is drained later.
final class WidgetHandshake<Result> {
    let queue: WidgetTaskQueue
    let policy: MessageWidgetWaitPolicy
    let turn: MessageWidgetTurn
    /// Main: applies one result. Results arrive in the order their tasks ran.
    var apply: ((Result) -> Void)?

    private let lock = NSLock()
    private var mailbox: [Result] = []
    /// Main: a drain is applying results. Applying one can queue another task (a snapshot asks for its draw); that run
    /// leaves its result to this drain, which applies it in its place.
    private var draining = false

    init(queue: WidgetTaskQueue, policy: MessageWidgetWaitPolicy, turn: MessageWidgetTurn) {
        self.queue = queue
        self.policy = policy
        self.turn = turn
    }

    /// Main: queues `work` (with `key`, replacing a waiting task with the same key) and, when `wait`, waits for it within
    /// the turn's cap (`policy`'s, for this call only, when given). True when it finished within the wait:
    /// its result is applied before this returns. False when it goes on (its result is applied later, in order) or the
    /// queue is closed.
    @discardableResult
    func run(wait: Bool, key: String? = nil, policy: MessageWidgetWaitPolicy? = nil, _ work: @escaping () -> Result) -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        let policy = policy ?? self.policy
        // A wait ends with its task or at the turn's cap.
        let timeout: TimeInterval? = wait ? self.turn.remainingTime(policy) : 0.0
        let ticket = WidgetTicket<Result>(deposit: { [weak self] result in
            self?.deposit(result)
        }, late: { [weak self] in
            DispatchQueue.main.async {
                self?.drain()
            }
        })
        let queued = self.queue.enqueue(key: key) {
            ticket.complete(work())
        }
        guard queued else {
            return false
        }
        let start = CACurrentMediaTime()
        let finished = ticket.wait(timeout: timeout)
        if wait {
            self.turn.record(time: CACurrentMediaTime() - start)
        }
        if self.draining {
            // The running drain applies the result, after the older ones it still holds.
            return false
        }
        self.drain()
        return finished
    }

    /// Main: applies the results that finished after their wait, in order, including those that land while it runs. A
    /// drain started while one runs returns at once.
    func drain() {
        if self.draining {
            return
        }
        self.draining = true
        defer {
            self.draining = false
        }
        while true {
            self.lock.lock()
            if self.mailbox.isEmpty {
                self.lock.unlock()
                return
            }
            let item = self.mailbox.removeFirst()
            self.lock.unlock()
            self.apply?(item)
        }
    }

    /// Core: a task's result, deposited when it completes so the mailbox is in the order the tasks ran.
    private func deposit(_ result: Result) {
        self.lock.lock()
        self.mailbox.append(result)
        self.lock.unlock()
    }
}
