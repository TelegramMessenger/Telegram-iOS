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
    private var lock = pthread_mutex_t()
    private var disposed = false
    private var disposable: Disposable! = nil
    
    public init() {
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    public func set(_ disposable: Disposable?) {
        var previousDisposable: Disposable! = nil
        var disposeImmediately = false
        
        pthread_mutex_lock(&self.lock)
        disposeImmediately = self.disposed
        if !disposeImmediately {
            previousDisposable = self.disposable
            if let disposable = disposable {
                self.disposable = disposable
            } else {
                self.disposable = nil
            }
        }
        pthread_mutex_unlock(&self.lock)
        
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
        
        pthread_mutex_lock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposable = self.disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        
        if disposable != nil {
            disposable.dispose()
        }
    }
}

public final class DisposableSet : Disposable {
    private var lock = pthread_mutex_t()
    private var disposed = false
    private var disposables: [Disposable] = []
    
    public init() {
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    public func add(_ disposable: Disposable) {
        var disposeImmediately = false
        
        pthread_mutex_lock(&self.lock)
        if self.disposed {
            disposeImmediately = true
        } else {
            self.disposables.append(disposable)
        }
        pthread_mutex_unlock(&self.lock)
        
        if disposeImmediately {
            disposable.dispose()
        }
    }
    
    public func remove(_ disposable: Disposable) {
        pthread_mutex_lock(&self.lock)
        if let index = self.disposables.index(where: { $0 === disposable }) {
            self.disposables.remove(at: index)
        }
        pthread_mutex_unlock(&self.lock)
    }
    
    public func dispose() {
        var disposables: [Disposable] = []
        pthread_mutex_lock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = []
        }
        pthread_mutex_unlock(&self.lock)
        
        if disposables.count != 0 {
            for disposable in disposables {
                disposable.dispose()
            }
        }
    }
}
