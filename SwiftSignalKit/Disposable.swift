import Foundation

public protocol Disposable
{
    func dispose()
}

internal struct _EmptyDisposable : Disposable {
    internal func dispose() {
    }
}

public let EmptyDisposable: Disposable = _EmptyDisposable()

public final class ActionDisposable : Disposable
{
    private var action: () -> Void
    private var lock: OSSpinLock = 0
    
    public init(action: () -> Void) {
        self.action = action
    }
    
    public func dispose() {
        var action = doNothing
        OSSpinLockLock(&self.lock)
        action = self.action
        self.action = doNothing
        OSSpinLockUnlock(&self.lock)
        action()
    }
}

public final class MetaDisposable : Disposable
{
    private var lock: OSSpinLock = 0
    private var disposed = false
    private var disposable: Disposable! = nil
    
    public init() {
    }
    
    public func set(disposable: Disposable?) {
        var previousDisposable: Disposable! = nil
        var disposeImmediately = false
        
        OSSpinLockLock(&self.lock)
        disposeImmediately = self.disposed
        if !disposeImmediately {
            previousDisposable = self.disposable
            if let disposable = disposable {
                self.disposable = disposable
            } else {
                self.disposable = nil
            }
        }
        OSSpinLockUnlock(&self.lock)
        
        if previousDisposable != nil {
            previousDisposable.dispose()
        }
        
        if disposeImmediately {
            if let disposable = disposable {
                disposable.dispose()
            }
        }
    }
    
    public func dispose()
    {
        var disposable: Disposable! = nil
        
        OSSpinLockLock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposable = self.disposable
            self.disposable = nil
        }
        OSSpinLockUnlock(&self.lock)
        
        if disposable != nil {
            disposable.dispose()
        }
    }
}

public final class DisposableSet : Disposable {
    private var lock: OSSpinLock = 0
    private var disposed = false
    private var disposables: [Disposable] = []
    
    public init() {
        
    }
    
    public func add(disposable: Disposable) {
        var disposeImmediately = false
        
        OSSpinLockLock(&self.lock)
        if self.disposed {
            disposeImmediately = true
        } else {
            self.disposables.append(disposable)
        }
        OSSpinLockUnlock(&self.lock)
        
        if disposeImmediately {
            disposable.dispose()
        }
    }
    
    public func dispose() {
        var disposables: [Disposable] = []
        OSSpinLockLock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = []
        }
        OSSpinLockUnlock(&self.lock)
        
        if disposables.count != 0 {
            for disposable in disposables {
                disposable.dispose()
            }
        }
    }
}
