import Foundation

#if DEBUG
// Signals keep themselves in memory until terminated (dispose, putError, putCompletion)
private final class LiveSubscribers {
    var dict: [ObjectIdentifier: AnyObject] = [:]
}
private let liveSubscribers = Atomic<LiveSubscribers>(value: LiveSubscribers())
#endif

public final class Subscriber<T, E>: CustomStringConvertible {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private var lock = pthread_mutex_t()
    private var terminated = false
    internal var disposable: Disposable?
    
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
        pthread_mutex_lock(&self.lock)
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        pthread_mutex_unlock(&self.lock)
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
        
        pthread_mutex_destroy(&self.lock)
    }
    
    internal func assignDisposable(_ disposable: Disposable) {
        #if DEBUG
        liveSubscribers.with { impl in
            //let _ = impl.dict[ObjectIdentifier(self)] = self
        }
        #endif
        
        var dispose = false
        pthread_mutex_lock(&self.lock)
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
        }
        pthread_mutex_unlock(&self.lock)
        
        if dispose {
            disposable.dispose()
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        var freeDisposable: Disposable?
        
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
        pthread_mutex_unlock(&self.lock)
        
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
        
        #if DEBUG
        liveSubscribers.with { impl in
            let _ = impl.dict.removeValue(forKey: ObjectIdentifier(self))
        }
        #endif
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
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(error)
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
        
        #if DEBUG
        liveSubscribers.with { impl in
            let _ = impl.dict.removeValue(forKey: ObjectIdentifier(self))
        }
        #endif
    }
    
    public func putCompletion() {
        var action: (() -> Void)! = nil
        
        var disposeDisposable: Disposable? = nil
        
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
        
        #if DEBUG
        liveSubscribers.with { impl in
            let _ = impl.dict.removeValue(forKey: ObjectIdentifier(self))
        }
        #endif
    }
}
