import Foundation

public protocol Disposable: AnyObject {
    func dispose()
}

public final class StrictDisposable: Disposable {
    private let disposable: Disposable
    private let file: String
    private let line: Int
    private let isDisposed = Atomic<Bool>(value: false)
    
    public init(_ disposable: Disposable, file: String, line: Int) {
        self.disposable = disposable
        self.file = file
        self.line = line
    }
    
    deinit {
        #if DEBUG
        if !self.isDisposed.with({ $0 }) {
            assertionFailure("Leaked disposable \(self.disposable) from \(self.file):\(self.line)")
        }
        #endif
    }
    
    public func dispose() {
        let _ = self.isDisposed.swap(true)
        self.disposable.dispose()
    }
}

public extension Disposable {
    func strict(file: String = #file, line: Int = #line) -> Disposable {
        return StrictDisposable(self, file: file, line: line)
    }
}

final class _EmptyDisposable: Disposable {
    func dispose() {
    }
}

public let EmptyDisposable: Disposable = _EmptyDisposable()

public final class ActionDisposable : Disposable {
    private var lock = pthread_mutex_t()
    
    private var action: (() -> Void)?
    
    public init(action: @escaping() -> Void) {
        self.action = action
        
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        var freeAction: (() -> Void)?
        pthread_mutex_lock(&self.lock)
        freeAction = self.action
        self.action = nil
        pthread_mutex_unlock(&self.lock)
        
        if let freeAction = freeAction {
            withExtendedLifetime(freeAction, {})
        }
        
        pthread_mutex_destroy(&self.lock)
    }
    
    public func dispose() {
        let disposeAction: (() -> Void)?
        
        pthread_mutex_lock(&self.lock)
        disposeAction = self.action
        self.action = nil
        pthread_mutex_unlock(&self.lock)
        
        disposeAction?()
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
        var freeDisposable: Disposable?
        pthread_mutex_lock(&self.lock)
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        if let freeDisposable = freeDisposable {
            withExtendedLifetime(freeDisposable, { })
        }
        
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
        pthread_mutex_lock(&self.lock)
        self.disposables.removeAll()
        pthread_mutex_unlock(&self.lock)
        
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
        if let index = self.disposables.firstIndex(where: { $0 === disposable }) {
            self.disposables.remove(at: index)
        }
        pthread_mutex_unlock(&self.lock)
    }
    
    public func removeLast() {
        pthread_mutex_lock(&self.lock)
        self.disposables.removeLast()
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

public final class DisposableDict<T: Hashable> : Disposable {
    private var lock = pthread_mutex_t()
    private var disposed = false
    private var disposables: [T: Disposable] = [:]
    
    public init() {
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_lock(&self.lock)
        self.disposables.removeAll()
        pthread_mutex_unlock(&self.lock)
        
        pthread_mutex_destroy(&self.lock)
    }
    
    public func set(_ disposable: Disposable?, forKey key: T) {
        var disposeImmediately = false
        var disposePrevious: Disposable?
        
        pthread_mutex_lock(&self.lock)
        if self.disposed {
            disposeImmediately = true
        } else {
            disposePrevious = self.disposables[key]
            if let disposable = disposable {
                self.disposables[key] = disposable
            }
        }
        pthread_mutex_unlock(&self.lock)
        
        if disposeImmediately {
            disposable?.dispose()
        }
        disposePrevious?.dispose()
    }
    
    public func dispose() {
        var disposables: [T: Disposable] = [:]
        pthread_mutex_lock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = [:]
        }
        pthread_mutex_unlock(&self.lock)
        
        if disposables.count != 0 {
            for disposable in disposables.values {
                disposable.dispose()
            }
        }
    }
}
