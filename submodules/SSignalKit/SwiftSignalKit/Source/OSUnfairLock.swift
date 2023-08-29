import Foundation
import os.lock

// Note: this lock is not recursive!

public protocol OSUnfairLock {
    func lock()
    func unlock()
    func tryLock() -> Bool
    func withLock<R>(_ f: () throws -> R) rethrows -> R where R: Sendable
}

@available(iOS 16.0, *)
private struct NewOSUnfairLock: OSUnfairLock {
    private let _lock = OSAllocatedUnfairLock()
    
    func lock() {
        self._lock.lock()
    }
    
    func unlock() {
        self._lock.unlock()
    }
    
    func tryLock() -> Bool {
        return self._lock.lockIfAvailable()
    }
    
    func withLock<R>(_ f: () throws -> R) rethrows -> R where R: Sendable {
        self.lock()
        defer { self.unlock() }
        return try f()
    }
}

private final class OldOSUnfairLock: OSUnfairLock {
    private var _lock: UnsafeMutablePointer<os_unfair_lock>
    
    init() {
        self._lock = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        self._lock.initialize(to: os_unfair_lock())
    }
    
    deinit {
        self._lock.deinitialize(count: 1)
        self._lock.deallocate()
    }
    
    func lock() {
        os_unfair_lock_lock(self._lock)
    }
    
    func unlock() {
        os_unfair_lock_unlock(self._lock)
    }
    
    func tryLock() -> Bool {
        return os_unfair_lock_trylock(self._lock)
    }
    
    func withLock<R>(_ f: () throws -> R) rethrows -> R where R: Sendable {
        self.lock()
        defer { self.unlock() }
        return try f()
    }
}

public func createOSUnfairLock() -> OSUnfairLock {
    if #available(iOS 16.0, *) {
        return NewOSUnfairLock()
    } else {
        return OldOSUnfairLock()
    }
}
