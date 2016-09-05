import Foundation

public protocol Disposable: class {
    func dispose()
}

final class _EmptyDisposable: Disposable {
    func dispose() {
    }
}

public let EmptyDisposable: Disposable = _EmptyDisposable()

public final class ActionDisposable : Disposable {
    private var action: () -> Void
    private var lock: Int32 = 0
    
    public init(action: @escaping() -> Void) {
        self.action = action
    }
    
    public func dispose() {
        if OSAtomicCompareAndSwap32(0, 1, &self.lock) {
            self.action()
            self.action = doNothing
        }
    }
}

public final class MetaDisposable : Disposable {
    private var lock: OSSpinLock = 0
    private var disposed = false
    private var disposable: Disposable! = nil
    
    public init() {
    }
    
    public func set(_ disposable: Disposable?) {
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
    
    public func add(_ disposable: Disposable) {
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
    
    public func remove(_ disposable: Disposable) {
        OSSpinLockLock(&self.lock)
        if let index = self.disposables.index(where: { $0 === disposable }) {
            self.disposables.remove(at: index)
        }
        OSSpinLockUnlock(&self.lock)
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
