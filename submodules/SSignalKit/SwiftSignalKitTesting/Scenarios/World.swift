#if SSK_LEGACY
import SwiftSignalKitLegacy
typealias SKTimer = SwiftSignalKitLegacy.Timer
#else
import SwiftSignalKit2
typealias SKTimer = SwiftSignalKit2.Timer
#endif
import Foundation

public let implementationName: String = {
    #if SSK_LEGACY
    return "legacy"
    #else
    return "v2"
    #endif
}()

public final class Trace {
    private var lock = pthread_mutex_t()
    private var storage: [String] = []
    public var limit: Int = Int.max
    public private(set) var overflowed = false

    public init() {
        pthread_mutex_init(&self.lock, nil)
    }

    deinit {
        pthread_mutex_destroy(&self.lock)
    }

    public func log(_ event: String) {
        pthread_mutex_lock(&self.lock)
        if self.storage.count < self.limit {
            self.storage.append(event)
        } else {
            self.overflowed = true
        }
        pthread_mutex_unlock(&self.lock)
    }

    public var events: [String] {
        pthread_mutex_lock(&self.lock)
        let result = self.storage
        pthread_mutex_unlock(&self.lock)
        return result
    }

    public var count: Int {
        pthread_mutex_lock(&self.lock)
        let result = self.storage.count
        pthread_mutex_unlock(&self.lock)
        return result
    }
}

final class WeakRef<T: AnyObject> {
    weak var value: T?
    init(_ value: T) {
        self.value = value
    }
}

final class Sentinel {
    let name: String
    let trace: Trace

    init(_ name: String, _ trace: Trace) {
        self.name = name
        self.trace = trace
    }

    deinit {
        self.trace.log("deinit \(self.name)")
    }

    @inline(never)
    func touch() {
    }
}

struct SplitMix64 {
    var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        self.state &+= 0x9E3779B97F4A7C15
        var z = self.state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func int(_ upperBound: Int) -> Int {
        if upperBound <= 1 {
            return 0
        }
        return Int(self.next() % UInt64(upperBound))
    }

    mutating func chance(_ percent: Int) -> Bool {
        return self.int(100) < percent
    }
}

final class CountingDisposable: Disposable {
    let name: String
    let trace: Trace

    init(_ name: String, _ trace: Trace) {
        self.name = name
        self.trace = trace
    }

    deinit {
        self.trace.log("deinit \(self.name)")
    }

    func dispose() {
        self.trace.log("\(self.name) dispose")
    }
}
