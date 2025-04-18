import Foundation

final class WrappedSubscriberDisposable: Disposable {
    private var lock = pthread_mutex_t()
    private var disposable: Disposable?
    
    init(_ disposable: Disposable) {
        self.disposable = disposable
        
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    func dispose() {
        var disposableValue: Disposable?
        pthread_mutex_lock(&self.lock)
        disposableValue = self.disposable
        self.disposable = nil
        pthread_mutex_unlock(&self.lock)
        
        disposableValue?.dispose()
    }
    
    func markTerminated() {
        var disposableValue: Disposable?
        pthread_mutex_lock(&self.lock)
        disposableValue = self.disposable
        self.disposable = nil
        pthread_mutex_unlock(&self.lock)
        
        if let disposableValue = disposableValue {
            withExtendedLifetime(disposableValue, {
            })
        }
    }
}

public final class Subscriber<T, E>: CustomStringConvertible {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private var keepAliveObjects: [AnyObject]?
    
    private var lock = pthread_mutex_t()
    private var terminated = false
    internal var disposable: Disposable?
    private weak var wrappedDisposable: WrappedSubscriberDisposable?
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
        pthread_mutex_init(&self.lock, nil)
    }
    
    public var description: String {
        return "Subscriber { next: \(self.next == nil ? "nil" : "hasValue"), error: \(self.error == nil ? "nil" : "hasValue"), completed: \(self.completed == nil ? "nil" : "hasValue"), disposable: \(self.disposable == nil ? "nil" : "hasValue"), terminated: \(self.terminated) }"
    }
    
    deinit {
        var freeDisposable: Disposable?
        var keepAliveObjects: [AnyObject]?
        
        pthread_mutex_lock(&self.lock)
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        pthread_mutex_unlock(&self.lock)
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
        
        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
        
        pthread_mutex_destroy(&self.lock)
    }
    
    internal func assignDisposable(_ disposable: Disposable) -> Disposable {
        var updatedWrappedDisposable: WrappedSubscriberDisposable?
        var dispose = false
        pthread_mutex_lock(&self.lock)
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
            updatedWrappedDisposable = WrappedSubscriberDisposable(disposable)
            self.wrappedDisposable = updatedWrappedDisposable
        }
        pthread_mutex_unlock(&self.lock)
        
        if dispose {
            disposable.dispose()
        }
        
        if let updatedWrappedDisposable = updatedWrappedDisposable {
            return updatedWrappedDisposable
        } else {
            return EmptyDisposable
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        var freeDisposable: Disposable?
        var keepAliveObjects: [AnyObject]?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            self.terminated = true
            self.next = nil
            self.error = nil
            self.completed = nil
            
            if let disposable = self.disposable {
                freeDisposable = disposable
                self.disposable = nil
            }
        }
        
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        
        pthread_mutex_unlock(&self.lock)
        
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
        
        if let wrappedDisposable = self.wrappedDisposable {
            wrappedDisposable.markTerminated()
        }
        
        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
    }
    
    public func putNext(_ next: T) {
        var action: ((T) -> Void)! = nil
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.next
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(next)
        }
    }
    
    public func putError(_ error: E) {
        var action: ((E) -> Void)! = nil
        
        var disposeDisposable: Disposable?
        var keepAliveObjects: [AnyObject]?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.error
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
            disposeDisposable = self.disposable
            self.disposable = nil
        }
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(error)
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
        
        if let wrappedDisposable = self.wrappedDisposable {
            wrappedDisposable.markTerminated()
        }
        
        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
    }
    
    public func putCompletion() {
        var action: (() -> Void)! = nil
        
        var disposeDisposable: Disposable? = nil
        var keepAliveObjects: [AnyObject]?
        
        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.completed
            next = self.next
            self.next = nil
            error = self.error
            self.error = nil
            completed = self.completed
            self.completed = nil
            self.terminated = true
            
            disposeDisposable = self.disposable
            self.disposable = nil
        }
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        pthread_mutex_unlock(&self.lock)
        
        if let next = next {
            withExtendedLifetime(next, {})
        }
        if let error = error {
            withExtendedLifetime(error, {})
        }
        if let completed = completed {
            withExtendedLifetime(completed, {})
        }
        
        if action != nil {
            action()
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
        
        if let wrappedDisposable = self.wrappedDisposable {
            wrappedDisposable.markTerminated()
        }
        
        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
    }
    
    public func keepAlive(_ object: AnyObject) {
        pthread_mutex_lock(&self.lock)
        if self.keepAliveObjects == nil {
            self.keepAliveObjects = []
        }
        self.keepAliveObjects?.append(object)
        pthread_mutex_unlock(&self.lock)
    }
}
