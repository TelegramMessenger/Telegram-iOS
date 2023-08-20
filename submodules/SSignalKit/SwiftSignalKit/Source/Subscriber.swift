import Foundation

public final class Subscriber<T, E> {
    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!
    
    private let lock = createOSUnfairLock()
    private var terminated = false
    internal var disposable: Disposable!
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.next = next
        self.error = error
        self.completed = completed
    }
    
    deinit {
        var freeDisposable: Disposable?
        self.lock.lock()
        if let disposable = self.disposable {
            freeDisposable = disposable
            self.disposable = nil
        }
        self.lock.unlock()
        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
    }
    
    internal func assignDisposable(_ disposable: Disposable) {
        var dispose = false
        self.lock.lock()
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
        }
        self.lock.unlock()
        
        if dispose {
            disposable.dispose()
        }
    }
    
    internal func markTerminatedWithoutDisposal() {
        var disposable: Disposable?
        
        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?
        
        self.lock.lock()
        if !self.terminated {
            self.terminated = true
            next = self.next
            self.next = nil
            error = self.error
            self.error = nil
            completed = self.completed
            self.completed = nil
            disposable = self.disposable
            self.disposable = nil
        }
        self.lock.unlock()
        
        if let next = next {
            withExtendedLifetime(next, {})
        }
        if let error = error {
            withExtendedLifetime(error, {})
        }
        if let completed = completed {
            withExtendedLifetime(completed, {})
        }
        
        withExtendedLifetime(disposable, {})
    }
    
    public func putNext(_ next: T) {
        var action: ((T) -> Void)! = nil
        self.lock.lock()
        if !self.terminated {
            action = self.next
        }
        self.lock.unlock()
        
        if action != nil {
            action(next)
        }
    }
    
    public func putError(_ error: E) {
        var action: ((E) -> Void)! = nil
        
        var disposeDisposable: Disposable?
        
        var next: ((T) -> Void)?
        var completed: (() -> Void)?
        
        self.lock.lock()
        if !self.terminated {
            action = self.error
            next = self.next
            self.next = nil
            self.error = nil
            completed = self.completed
            self.completed = nil;
            self.terminated = true
            disposeDisposable = self.disposable
            self.disposable = nil
            
        }
        self.lock.unlock()
        
        if let next = next {
            withExtendedLifetime(next, {})
        }
        if let completed = completed {
            withExtendedLifetime(completed, {})
        }
        
        if action != nil {
            action(error)
        }
        
        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }
    }
    
    public func putCompletion() {
        var action: (() -> Void)! = nil
        
        var disposeDisposable: Disposable? = nil
        
        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?
        
        self.lock.lock()
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
        self.lock.unlock()
        
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
    }
}
