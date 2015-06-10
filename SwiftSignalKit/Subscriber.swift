import Foundation

public final class Subscriber<T, E> {
    private var next: (T -> Void)!
    private var error: (E -> Void)!
    private var completed: (() -> Void)!
    
    private var lock: OSSpinLock = 0
    private var terminated = false
    internal var disposable: Disposable!
    
    public init(next: (T -> Void)! = nil, error: (E -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
    }
    
    internal func assignDisposable(disposable: Disposable) {
        if self.terminated {
            disposable.dispose()
        } else {
            self.disposable = disposable
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        OSSpinLockLock(&self.lock)
        if !self.terminated {
            self.terminated = true
            self.next = nil
            self.error = nil
            self.completed = nil
        }
        OSSpinLockUnlock(&self.lock)
    }
    
    public func putNext(next: T) {
        var action: (T -> Void)! = nil
        OSSpinLockLock(&self.lock)
        if !self.terminated {
            action = self.next
        }
        OSSpinLockUnlock(&self.lock)
        
        if action != nil {
            action(next)
        }
    }
    
    public func putError(error: E) {
        var shouldDispose = false
        var action: (E -> Void)! = nil
        
        OSSpinLockLock(&self.lock);
        if !self.terminated {
            action = self.error
            shouldDispose = true;
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
        }
        OSSpinLockUnlock(&self.lock);
        
        if action != nil {
            action(error)
        }
        
        if shouldDispose && self.disposable != nil {
            let disposable = self.disposable
            disposable.dispose()
            self.disposable = nil
        }
    }
    
    public func putCompletion() {
        var shouldDispose = false
        var action: (() -> Void)! = nil
        
        OSSpinLockLock(&self.lock);
        if !self.terminated {
            action = self.completed
            shouldDispose = true;
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
        }
        OSSpinLockUnlock(&self.lock);
        
        if action != nil {
            action()
        }
        
        if shouldDispose && self.disposable != nil {
            let disposable = self.disposable
            disposable.dispose()
            self.disposable = nil
        }
    }
}
