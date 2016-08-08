import Foundation

public final class Atomic<T> {
    private var lock: OSSpinLock = 0
    private var value: T
    
    public init(value: T) {
        self.value = value
    }
    
    public func with<R>(_ f: @noescape(T) -> R) -> R {
        OSSpinLockLock(&self.lock)
        let result = f(self.value)
        OSSpinLockUnlock(&self.lock)
        
        return result
    }
    
    public func modify(_ f: @noescape(T) -> T) -> T {
        OSSpinLockLock(&self.lock)
        let result = f(self.value)
        self.value = result
        OSSpinLockUnlock(&self.lock)
        
        return result
    }
    
    public func swap(_ value: T) -> T {
        OSSpinLockLock(&self.lock)
        let previous = self.value
        self.value = value
        OSSpinLockUnlock(&self.lock)
        
        return previous
    }
}
