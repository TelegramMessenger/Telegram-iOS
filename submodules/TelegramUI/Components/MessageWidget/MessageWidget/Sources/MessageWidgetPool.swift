import Foundation

/// The threads every message widget's work runs on (spec 2026-10-15 D2): two in the app, each with an 8 MB stack, at
/// user-interactive QoS. Each widget has a serial `WidgetTaskQueue`: a free thread takes the oldest runnable queue's next
/// task and runs it to completion, so a widget is never on two threads at once and two widgets run side by side. Nothing
/// is pinned to a thread: QuickJS re-reads its stack top on every entry (WidgetRuntime's `JS_UpdateStackTop`), so a runtime may run
/// its next task on the other thread.
public final class MessageWidgetPool {
    /// Real stack of every pool thread: a runtime limited to `jsStackLimit`, with room for the native layout and drawing
    /// that run under it.
    public static let threadStackSize: Int = 8 << 20
    /// QuickJS stack limit for every runtime.
    public static let jsStackLimit: Int = 2 << 20

    public static let shared = MessageWidgetPool(threadCount: 2)

    fileprivate let condition = NSCondition()
    private var runnable: [WidgetTaskQueue] = []
    private var stopping = false

    public init(threadCount: Int) {
        precondition(threadCount > 0, "MessageWidgetPool needs a thread")
        for index in 0 ..< threadCount {
            let thread = Thread { [self] in
                self.work()
            }
            thread.name = "message-widget.\(index)"
            thread.stackSize = MessageWidgetPool.threadStackSize
            thread.qualityOfService = .userInteractive
            thread.start()
        }
    }

    /// A new widget's queue.
    public func makeQueue() -> WidgetTaskQueue {
        return WidgetTaskQueue(pool: self)
    }

    /// Ends the threads once the runnable tasks have run (tests: the app's pool lives as long as the app).
    public func stop() {
        self.condition.lock()
        self.stopping = true
        self.condition.broadcast()
        self.condition.unlock()
    }

    /// Under `condition`.
    fileprivate func schedule(_ queue: WidgetTaskQueue) {
        self.runnable.append(queue)
        self.condition.signal()
    }

    private func work() {
        while true {
            self.condition.lock()
            while self.runnable.isEmpty && !self.stopping {
                self.condition.wait()
            }
            if self.runnable.isEmpty {
                self.condition.unlock()
                return
            }
            let queue = self.runnable.removeFirst()
            let body = queue.takeNext()
            self.condition.unlock()
            autoreleasepool {
                body()
            }
            self.condition.lock()
            queue.didFinishRunning()
            self.condition.unlock()
        }
    }
}

/// One widget's serial queue on the pool: its tasks run in order, one at a time, on whichever pool thread is free.
/// All state is guarded by the pool's lock.
public final class WidgetTaskQueue {
    private let pool: MessageWidgetPool
    private var tasks: [(key: String?, body: () -> Void)] = []
    private var running = false
    private var scheduled = false
    private var closed = false

    fileprivate init(pool: MessageWidgetPool) {
        self.pool = pool
    }

    /// Queues `body` after the tasks queued before it. A `key` replaces the waiting task with the same key, in its place
    /// (the newest state wins). False when the queue is closed: `body` will never run.
    @discardableResult
    public func enqueue(key: String? = nil, _ body: @escaping () -> Void) -> Bool {
        self.pool.condition.lock()
        defer {
            self.pool.condition.unlock()
        }
        if self.closed {
            return false
        }
        if let key, let index = self.tasks.firstIndex(where: { $0.key == key }) {
            self.tasks[index].body = body
            return true
        }
        self.tasks.append((key: key, body: body))
        self.scheduleIfIdle()
        return true
    }

    /// Drops the waiting tasks, refuses new ones, and runs `teardown` once the running task, if any, has ended (spec D5:
    /// a destroyed widget leaves main at once; its core is torn down after its current task).
    public func close(teardown: @escaping () -> Void) {
        self.pool.condition.lock()
        defer {
            self.pool.condition.unlock()
        }
        if self.closed {
            return
        }
        self.closed = true
        self.tasks = [(key: nil, body: teardown)]
        self.scheduleIfIdle()
    }

    /// No task running or waiting.
    public var isIdle: Bool {
        self.pool.condition.lock()
        defer {
            self.pool.condition.unlock()
        }
        return !self.running && self.tasks.isEmpty
    }

    /// Under the pool's lock.
    private func scheduleIfIdle() {
        if !self.running && !self.scheduled && !self.tasks.isEmpty {
            self.scheduled = true
            self.pool.schedule(self)
        }
    }

    /// Under the pool's lock.
    fileprivate func takeNext() -> () -> Void {
        self.scheduled = false
        self.running = true
        return self.tasks.removeFirst().body
    }

    /// Under the pool's lock.
    fileprivate func didFinishRunning() {
        self.running = false
        self.scheduleIfIdle()
    }
}
