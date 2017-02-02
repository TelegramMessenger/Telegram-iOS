import Foundation

public final class Subscriber<T, E> {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private var lock = pthread_mutex_t()
    private var terminated = false
    internal var disposable: Disposable!
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
        pthread_mutex_init(&self.lock, nil)
    }
    
    deinit {
        pthread_mutex_destroy(&self.lock)
    }
    
    internal func assignDisposable(_ disposable: Disposable) {
        if self.terminated {
            disposable.dispose()
        } else {
            self.disposable = disposable
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            self.terminated = true
            self.next = nil
            self.error = nil
            self.completed = nil
        }
        pthread_mutex_unlock(&self.lock)
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
        var shouldDispose = false
        var action: ((E) -> Void)! = nil
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.error
            shouldDispose = true;
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action(error)
        }
        
        if shouldDispose && self.disposable != nil {
            let disposable = self.disposable!
            disposable.dispose()
            self.disposable = nil
        }
    }
    
    public func putCompletion() {
        var shouldDispose = false
        var action: (() -> Void)! = nil
        
        pthread_mutex_lock(&self.lock)
        if !self.terminated {
            action = self.completed
            shouldDispose = true;
            self.next = nil
            self.error = nil
            self.completed = nil;
            self.terminated = true
        }
        pthread_mutex_unlock(&self.lock)
        
        if action != nil {
            action()
        }
        
        if shouldDispose && self.disposable != nil {
            let disposable = self.disposable!
            disposable.dispose()
            self.disposable = nil
        }
    }
}
