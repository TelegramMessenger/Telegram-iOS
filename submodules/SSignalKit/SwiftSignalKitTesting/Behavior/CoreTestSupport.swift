import XCTest
import Foundation
#if SSK_LEGACY
@testable import SwiftSignalKitLegacy
#else
@testable import SwiftSignalKit2
#endif

final class CoreEventLog {
    private let lock = NSLock()
    private var storage: [String] = []

    func append(_ event: String) {
        self.lock.lock()
        self.storage.append(event)
        self.lock.unlock()
    }

    var events: [String] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }

    func count(of event: String) -> Int {
        return self.events.filter { $0 == event }.count
    }
}

final class CoreCounter {
    private let lock = NSLock()
    private var storage = 0

    @discardableResult
    func increment() -> Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.storage += 1
        return self.storage
    }

    @discardableResult
    func decrement() -> Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        self.storage -= 1
        return self.storage
    }

    var value: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }
}

final class CoreFlag {
    private let lock = NSLock()
    private var storage: Bool?

    func set(_ value: Bool) {
        self.lock.lock()
        self.storage = value
        self.lock.unlock()
    }

    var value: Bool? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.storage
    }
}

final class CoreCountingDisposable: Disposable {
    private let lock = NSLock()
    private var count = 0
    private let label: String
    private let log: CoreEventLog?
    var onDispose: (() -> Void)?

    init(_ label: String = "dispose", log: CoreEventLog? = nil) {
        self.label = label
        self.log = log
    }

    func dispose() {
        self.lock.lock()
        self.count += 1
        let onDispose = self.onDispose
        self.lock.unlock()
        self.log?.append(self.label)
        onDispose?()
    }

    var disposeCount: Int {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.count
    }
}

final class CoreObject {
    let value: Int

    init(_ value: Int = 0) {
        self.value = value
    }
}

final class CoreDeinitProbe {
    private let onDeinit: () -> Void

    init(_ onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        self.onDeinit()
    }
}

final class CoreSubscriberHolder<T, E> {
    var subscriber: Subscriber<T, E>?
}

final class CoreEquatableProbe: Equatable {
    let id: Int
    private let onDeinit: () -> Void

    init(_ id: Int, onDeinit: @escaping () -> Void) {
        self.id = id
        self.onDeinit = onDeinit
    }

    deinit {
        self.onDeinit()
    }

    static func ==(lhs: CoreEquatableProbe, rhs: CoreEquatableProbe) -> Bool {
        return lhs.id == rhs.id
    }
}

final class CoreDeinitProbeDisposable: Disposable {
    private let onDeinit: () -> Void

    init(_ onDeinit: @escaping () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        self.onDeinit()
    }

    func dispose() {
    }
}
