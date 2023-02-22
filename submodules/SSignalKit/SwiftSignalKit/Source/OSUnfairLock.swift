/*
import Foundation
import os.lock

private protocol Lockable {
    func lock()
    func unlock()
    func tryLock() -> Bool
}

@available(iOS 16.0, *)
private struct NewOSUnfairLock: Lockable {
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
}

private final class OldOSUnfairLock: Lockable {
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
}

public struct OSUnfairLock {
    private let _lock: Lockable
    
    public init() {
        if #available(iOS 16.0, *) {
            self._lock = NewOSUnfairLock()
        } else {
            self._lock = OldOSUnfairLock()
        }
    }
    
    public func lock() {
        self._lock.lock()
    }
    
    public func unlock() {
        self._lock.unlock()
    }
    
    public func tryLock() -> Bool {
        return self._lock.tryLock()
    }
    
    public func withLock<R>(_ f: () throws -> R) rethrows -> R where R: Sendable {
        self._lock.lock()
        defer { self._lock.unlock() }
        return try f()
    }
}
*/
