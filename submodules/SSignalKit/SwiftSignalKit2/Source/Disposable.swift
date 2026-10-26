import Foundation

public protocol Disposable: AnyObject {
    func dispose()
}

public final class StrictDisposable: Disposable {
    private let disposable: Disposable
    private let file: String
    private let line: Int
    private var lock = os_unfair_lock()
    private var isDisposed = false

    public init(_ disposable: Disposable, file: String, line: Int) {
        self.disposable = disposable
        self.file = file
        self.line = line
    }

    deinit {
        #if DEBUG
        if !self.isDisposed {
            assertionFailure("Leaked disposable \(self.disposable) from \(self.file):\(self.line)")
        }
        #endif
    }

    public func dispose() {
        os_unfair_lock_lock(&self.lock)
        self.isDisposed = true
        os_unfair_lock_unlock(&self.lock)
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
    private var lock = os_unfair_lock()

    private var action: (() -> Void)?

    public init(action: @escaping() -> Void) {
        self.action = action
    }

    public func dispose() {
        let disposeAction: (() -> Void)?

        os_unfair_lock_lock(&self.lock)
        disposeAction = self.action
        self.action = nil
        os_unfair_lock_unlock(&self.lock)

        disposeAction?()
    }
}

public final class MetaDisposable : Disposable {
    private var lock = os_unfair_lock()
    private var disposed = false
    private var disposable: Disposable! = nil

    public init() {
    }

    public func set(_ disposable: Disposable?) {
        var previousDisposable: Disposable! = nil
        var disposeImmediately = false

        os_unfair_lock_lock(&self.lock)
        disposeImmediately = self.disposed
        if !disposeImmediately {
            previousDisposable = self.disposable
            if let disposable = disposable {
                self.disposable = disposable
            } else {
                self.disposable = nil
            }
        }
        os_unfair_lock_unlock(&self.lock)

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

        os_unfair_lock_lock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposable = self.disposable
            self.disposable = nil
        }
        os_unfair_lock_unlock(&self.lock)

        if disposable != nil {
            disposable.dispose()
        }
    }
}

public final class DisposableSet : Disposable {
    private var lock = os_unfair_lock()
    private var disposed = false
    private var disposables: [Disposable] = []

    public init() {
    }

    public func add(_ disposable: Disposable) {
        var disposeImmediately = false

        os_unfair_lock_lock(&self.lock)
        if self.disposed {
            disposeImmediately = true
        } else {
            self.disposables.append(disposable)
        }
        os_unfair_lock_unlock(&self.lock)

        if disposeImmediately {
            disposable.dispose()
        }
    }

    public func remove(_ disposable: Disposable) {
        var removedDisposable: Disposable?
        os_unfair_lock_lock(&self.lock)
        if let index = self.disposables.firstIndex(where: { $0 === disposable }) {
            removedDisposable = self.disposables.remove(at: index)
        }
        os_unfair_lock_unlock(&self.lock)

        if let removedDisposableValue = removedDisposable {
            withExtendedLifetime(removedDisposableValue, {})
            removedDisposable = nil
        }
    }

    public func removeLast() {
        var removedDisposable: Disposable?
        os_unfair_lock_lock(&self.lock)
        if !self.disposables.isEmpty {
            removedDisposable = self.disposables.removeLast()
        }
        os_unfair_lock_unlock(&self.lock)

        if let removedDisposableValue = removedDisposable {
            withExtendedLifetime(removedDisposableValue, {})
            removedDisposable = nil
        }
    }

    public func dispose() {
        var disposables: [Disposable] = []
        os_unfair_lock_lock(&self.lock)
        if !self.disposed {
            self.disposed = true
            disposables = self.disposables
            self.disposables = []
        }
        os_unfair_lock_unlock(&self.lock)

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
        pthread_mutex_destroy(&self.lock)
    }
    
    public func set(_ disposable: Disposable?, forKey key: T) {
        var disposeImmediately = false
        var disposePrevious: Disposable?
        var removedEntry: (key: T, value: Disposable)?
        
        pthread_mutex_lock(&self.lock)
        if self.disposed {
            disposeImmediately = true
        } else {
            if let disposable = disposable {
                disposePrevious = self.disposables.updateValue(disposable, forKey: key)
            } else if let index = self.disposables.index(forKey: key) {
                removedEntry = self.disposables.remove(at: index)
                disposePrevious = removedEntry?.value
            }
        }
        pthread_mutex_unlock(&self.lock)
        
        if removedEntry != nil {
            removedEntry = nil
        }
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
