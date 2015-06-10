import Foundation

public final class Atomic<T> {
    private var lock: OSSpinLock = 0
    private var value: T
    
    public init(value: T) {
        self.value = value
    }
    
    public func with<R>(f: T -> R) -> R {
        OSSpinLockLock(&self.lock)
        let result = f(self.value)
        OSSpinLockUnlock(&self.lock)
        
        return result
    }
    
    public func modify(f: T -> T) -> T {
        OSSpinLockLock(&self.lock)
        let result = f(self.value)
        self.value = result
        OSSpinLockUnlock(&self.lock)
        
        return result
    }
    
    public func swap(value: T) -> T {
        OSSpinLockLock(&self.lock)
        let previous = self.value
        self.value = value
        OSSpinLockUnlock(&self.lock)
        
        return previous
    }
}
