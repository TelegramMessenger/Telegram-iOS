import Foundation

public enum AtomicLockError: Error {
    case isLocked
}

public final class Atomic<T> {
    private let lock = createOSUnfairLock()
    private var value: T
    
    public init(value: T) {
        self.value = value
    }
    
    deinit {
    }
    
    public func with<R>(_ f: (T) -> R) -> R {
        self.lock.lock()
        let result = f(self.value)
        self.lock.unlock()
        
        return result
    }
    
    public func tryWith<R>(_ f: (T) -> R) throws -> R {
        if self.lock.tryLock() {
            let result = f(self.value)
            self.lock.unlock()
            return result
        } else {
            throw AtomicLockError.isLocked
        }
    }
    
    public func modify(_ f: (T) -> T) -> T {
        self.lock.lock()
        let result = f(self.value)
        self.value = result
        self.lock.unlock()
        
        return result
    }
    
    public func swap(_ value: T) -> T {
        self.lock.lock()
        let previous = self.value
        self.value = value
        self.lock.unlock()
        
        return previous
    }
}
