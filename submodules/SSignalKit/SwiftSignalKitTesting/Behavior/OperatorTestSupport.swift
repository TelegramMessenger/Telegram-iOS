import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class OperatorLog {
    private let lock = NSLock()
    private var items: [String] = []

    func add(_ item: String) {
        self.lock.lock()
        self.items.append(item)
        self.lock.unlock()
    }

    var events: [String] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.items
    }

    func clear() {
        self.lock.lock()
        self.items.removeAll()
        self.lock.unlock()
    }

    func count(of item: String) -> Int {
        return self.events.filter { $0 == item }.count
    }
}

final class OperatorCountingDisposable: Disposable {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    func dispose() {
        self.action()
    }
}

final class OperatorSource<T, E> {
    let name: String
    let log: OperatorLog
    var onSubscribe: ((Subscriber<T, E>, Int) -> Void)?
    var logsEveryDisposeCall = false

    private let lock = NSLock()
    private var nextId = 0
    private var live: [(Int, Subscriber<T, E>)] = []
    private var subscribeTimestamps: [Double] = []

    init(_ name: String, _ log: OperatorLog, onSubscribe: ((Subscriber<T, E>, Int) -> Void)? = nil) {
        self.name = name
        self.log = log
        self.onSubscribe = onSubscribe
    }

    var signal: Signal<T, E> {
        return Signal { subscriber in
            self.lock.lock()
            self.nextId += 1
            let id = self.nextId
            self.live.append((id, subscriber))
            self.subscribeTimestamps.append(CFAbsoluteTimeGetCurrent())
            self.lock.unlock()

            self.log.add("\(self.name).subscribe#\(id)")
            self.onSubscribe?(subscriber, id)

            if self.logsEveryDisposeCall {
                return OperatorCountingDisposable {
                    self.lock.lock()
                    self.live.removeAll(where: { $0.0 == id })
                    self.lock.unlock()
                    self.log.add("\(self.name).dispose#\(id)")
                }
            }
            return ActionDisposable {
                self.lock.lock()
                self.live.removeAll(where: { $0.0 == id })
                self.lock.unlock()
                self.log.add("\(self.name).dispose#\(id)")
            }
        }
    }

    private func liveSubscribers() -> [Subscriber<T, E>] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.live.map { $0.1 }
    }

    func emit(_ value: T) {
        for subscriber in self.liveSubscribers() {
            subscriber.putNext(value)
        }
    }

    func complete() {
        for subscriber in self.liveSubscribers() {
            subscriber.putCompletion()
        }
    }

    func fail(_ error: E) {
        for subscriber in self.liveSubscribers() {
            subscriber.putError(error)
        }
    }

    var liveCount: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.live.count
    }

    var subscriptionCount: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.nextId
    }

    var subscribeTimes: [Double] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.subscribeTimestamps
    }
}

func operatorSyncSource<T, E>(_ name: String, _ log: OperatorLog, values: [T], terminal: OperatorTerminal<E>) -> OperatorSource<T, E> {
    return OperatorSource<T, E>(name, log, onSubscribe: { subscriber, _ in
        for value in values {
            subscriber.putNext(value)
        }
        switch terminal {
        case .none:
            break
        case .complete:
            subscriber.putCompletion()
        case let .fail(error):
            subscriber.putError(error)
        }
    })
}

enum OperatorTerminal<E> {
    case none
    case complete
    case fail(E)
}

@discardableResult
func operatorRecord<T, E>(_ signal: Signal<T, E>, _ log: OperatorLog, completion: (() -> Void)? = nil) -> Disposable {
    return signal.start(next: { value in
        log.add("next \(value)")
    }, error: { error in
        log.add("error \(error)")
        completion?()
    }, completed: {
        log.add("completed")
        completion?()
    })
}

final class OperatorFlag {
    private let lock = NSLock()
    private var current = false

    var value: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.current
    }

    func set() {
        self.lock.lock()
        self.current = true
        self.lock.unlock()
    }
}

final class OperatorCounter {
    private let lock = NSLock()
    private var current = 0

    var value: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.current
    }

    @discardableResult
    func increment() -> Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.current += 1
        return self.current
    }

    func decrement() {
        self.lock.lock()
        self.current -= 1
        self.lock.unlock()
    }
}

final class OperatorBox<V> {
    private let lock = NSLock()
    private var items: [V] = []

    func append(_ item: V) {
        self.lock.lock()
        self.items.append(item)
        self.lock.unlock()
    }

    var values: [V] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.items
    }
}

func operatorBlock(_ queue: Queue) -> DispatchSemaphore {
    let semaphore = DispatchSemaphore(value: 0)
    let entered = DispatchSemaphore(value: 0)
    queue.queue.async {
        entered.signal()
        semaphore.wait()
    }
    precondition(entered.wait(timeout: .now() + 10.0) == .success, "queue did not start the blocking block")
    return semaphore
}

func operatorFlush(_ queue: Queue) {
    queue.queue.sync {
    }
}
