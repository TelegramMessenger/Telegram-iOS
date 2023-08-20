import Foundation

public protocol Disposable: AnyObject {
    func dispose()
}

final class _EmptyDisposable: Disposable {
    func dispose() {
    }
}

public let EmptyDisposable: Disposable = _EmptyDisposable()

public final class ActionDisposable : Disposable {
    private let lock = createOSUnfairLock()
    
    private var action: (() -> Void)?
    
    public init(action: @escaping() -> Void) {
        self.action = action
    }
    
    deinit {
        var freeAction: (() -> Void)?
        self.lock.lock()
        freeAction = self.action
        self.action = nil
        self.lock.unlock()
        
        if let freeAction = freeAction {
            withExtendedLifetime(freeAction, {})
        }
    }
    
    public func dispose() {
        let disposeAction: (() -> Void)?
        
        self.lock.lock()
        disposeAction = self.action
        self.action = nil
        self.lock.unlock()
        
        disposeAction?()
    }
}

public final class MetaDisposable : Disposable {
    private let lock = createOSUnfairLock()
    private var disposed = false
    private var disposable: Disposable! = nil
    
    public init() {
    }
    
    deinit {
        var freeDisposable: Disposable?
        self.lock.lock()
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        self.lock.unlock()
        if let freeDisposable = freeDisposable {
            withExtendedLifetime(freeDisposable, { })
        }
    }
    
    public func set(_ disposable: Disposable?) {
        var previousDisposable: Disposable! = nil
        var disposeImmediately = false
        
        self.lock.lock()
        disposeImmediately = self.disposed
        if !disposeImmediately {
            previousDisposable = self.disposable
            if let disposable = disposable {
                self.disposable = disposable
            } else {
                self.disposable = nil
            }
        }
        self.lock.unlock()
        
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
        
        self.lock.lock()
        if !self.disposed {
            self.disposed = true
            disposable = self.disposable
            self.disposable = nil
        }
        self.lock.unlock()
        
        if disposable != nil {
            disposable.dispose()
        }
    }
}

public final class DisposableSet : Disposable {
    private let lock = createOSUnfairLock()
    private var disposed = false
    private var disposables: [Disposable] = []
    
    public init() {
    }
    
    deinit {
        self.lock.lock()
        let disposables = self.disposables
        self.disposables = []
        self.lock.unlock()
        
        withExtendedLifetime(disposables, {})
    }
    
    public func add(_ disposable: Disposable) {
        var disposeImmediately = false
        
        self.lock.lock()
        if self.disposed {
            disposeImmediately = true
        } else {
            assert(!self.disposables.contains(where: { $0 === disposable }))
            self.disposables.append(disposable)
        }
        self.lock.unlock()
        
        if disposeImmediately {
            disposable.dispose()
        }
    }
    
    public func remove(_ disposable: Disposable) {
        self.lock.lock()
        if let index = self.disposables.firstIndex(where: { $0 === disposable }) {
            self.disposables.remove(at: index)
        } else {
            assertionFailure()
        }
        self.lock.unlock()
    }
    
    public func dispose() {
        var disposables: [Disposable] = []
        self.lock.lock()
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = []
        }
        self.lock.unlock()
        
        if disposables.count != 0 {
            for disposable in disposables {
                disposable.dispose()
            }
        }
    }
}

public final class DisposableDict<T: Hashable> : Disposable {
    private let lock = createOSUnfairLock()
    private var disposed = false
    private var disposables: [T: Disposable] = [:]
    
    public init() {
    }
    
    deinit {
        self.lock.lock()
        let disposables = self.disposables
        self.disposables = [:]
        self.lock.unlock()
        
        withExtendedLifetime(disposables, {})
    }
    
    public func set(_ disposable: Disposable?, forKey key: T) {
        var disposeImmediately = false
        var disposePrevious: Disposable?
        
        self.lock.lock()
        if self.disposed {
            disposeImmediately = true
        } else {
            disposePrevious = self.disposables[key]
            if let disposable = disposable {
                self.disposables[key] = disposable
            } else {
                self.disposables.removeValue(forKey: key)
            }
        }
        self.lock.unlock()
        
        if disposeImmediately {
            disposable?.dispose()
        }
        disposePrevious?.dispose()
    }
    
    public func dispose() {
        var disposables: [T: Disposable] = [:]
        self.lock.lock()
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = [:]
        }
        self.lock.unlock()
        
        if disposables.count != 0 {
            for disposable in disposables.values {
                disposable.dispose()
            }
        }
    }
}
