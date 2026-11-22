import Foundation

struct SubscriberResources<T, E> {
    var disposable: Disposable?
    var keepAliveObjects: [AnyObject]?
    var next: ((T) -> Void)?
    var error: ((E) -> Void)?
    var completed: (() -> Void)?
    
    mutating func release() {
        if self.disposable != nil {
            self.disposable = nil
        }
        if self.keepAliveObjects != nil {
            self.keepAliveObjects = nil
        }
        if self.next != nil {
            self.next = nil
        }
        if self.error != nil {
            self.error = nil
        }
        if self.completed != nil {
            self.completed = nil
        }
    }
}

final class SubscriberCore<T, E>: Disposable, CustomStringConvertible {
    private var lock = os_unfair_lock()

    private var next: ((T) -> Void)!
    private var error: ((E) -> Void)!
    private var completed: (() -> Void)!

    private var keepAliveObjects: [AnyObject]?

    private var terminated = false
    private var disposable: Disposable?
    private var subscriberHoldsDisposable = false
    private var handleHoldsDisposable = false
    private var handleDisposed = false
    private var subscriberAlive = true
    private var disposingWithSubscriber = false
    private var deferredSubscriberDeinit = false

    init(next: ((T) -> Void)!, error: ((E) -> Void)!, completed: (() -> Void)!) {
        self.next = next
        self.error = error
        self.completed = completed
    }

    var subscriberDescription: String {
        os_unfair_lock_lock(&self.lock)
        let result = "Subscriber { next: \(self.next == nil ? "nil" : "hasValue"), error: \(self.error == nil ? "nil" : "hasValue"), completed: \(self.completed == nil ? "nil" : "hasValue"), disposable: \(self.subscriberHoldsDisposable ? "hasValue" : "nil"), terminated: \(self.terminated) }"
        os_unfair_lock_unlock(&self.lock)
        return result
    }

    var description: String {
        os_unfair_lock_lock(&self.lock)
        let result = "SubscriberDisposable { disposable: \(self.handleDisposed ? "nil" : "hasValue") }"
        os_unfair_lock_unlock(&self.lock)
        return result
    }

    func assignDisposable(_ disposable: Disposable) -> Disposable {
        var dispose = false
        os_unfair_lock_lock(&self.lock)
        if self.terminated {
            dispose = true
        } else {
            self.disposable = disposable
            self.subscriberHoldsDisposable = true
            self.handleHoldsDisposable = true
        }
        os_unfair_lock_unlock(&self.lock)

        if dispose {
            disposable.dispose()
        }

        return self
    }

    func dispose() {
        var disposeItem: Disposable?
        var subscriberAlive = false
        os_unfair_lock_lock(&self.lock)
        if !self.handleDisposed {
            self.handleDisposed = true
            subscriberAlive = self.subscriberAlive
            if subscriberAlive {
                self.disposingWithSubscriber = true
            }
            if self.handleHoldsDisposable {
                self.handleHoldsDisposable = false
                disposeItem = self.disposable
                if !self.subscriberHoldsDisposable {
                    self.disposable = nil
                }
            }
        }
        os_unfair_lock_unlock(&self.lock)

        if let disposeItemValue = disposeItem {
            disposeItem = nil
            disposeItemValue.dispose()
        }
        if subscriberAlive {
            self.markTerminatedWithoutDisposal()
            
            os_unfair_lock_lock(&self.lock)
            self.disposingWithSubscriber = false
            let deferredSubscriberDeinit = self.deferredSubscriberDeinit
            self.deferredSubscriberDeinit = false
            os_unfair_lock_unlock(&self.lock)
            
            if deferredSubscriberDeinit {
                var resources = self.takeSubscriberResources()
                resources?.release()
            }
        }
    }

    private func releaseHandleDisposable() {
        var freeDisposable: Disposable?
        os_unfair_lock_lock(&self.lock)
        if self.handleHoldsDisposable {
            self.handleHoldsDisposable = false
            if !self.subscriberHoldsDisposable {
                freeDisposable = self.disposable
                self.disposable = nil
            }
        }
        os_unfair_lock_unlock(&self.lock)

        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }
    }

    private func takeSubscriberDisposable() -> Disposable? {
        if !self.subscriberHoldsDisposable {
            return nil
        }
        self.subscriberHoldsDisposable = false
        let result = self.disposable
        if !self.handleHoldsDisposable {
            self.disposable = nil
        }
        return result
    }

    func takeSubscriberResources() -> SubscriberResources<T, E>? {
        var resources = SubscriberResources<T, E>()
        
        os_unfair_lock_lock(&self.lock)
        if self.disposingWithSubscriber {
            self.deferredSubscriberDeinit = true
            os_unfair_lock_unlock(&self.lock)
            return nil
        }
        self.subscriberAlive = false
        self.subscriberHoldsDisposable = false
        if !self.handleHoldsDisposable {
            resources.disposable = self.disposable
            self.disposable = nil
        }
        resources.keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        resources.next = self.next
        self.next = nil
        resources.error = self.error
        self.error = nil
        resources.completed = self.completed
        self.completed = nil
        os_unfair_lock_unlock(&self.lock)
        
        return resources
    }
    
    func markTerminatedWithoutDisposal() {
        var freeDisposable: Disposable?
        var keepAliveObjects: [AnyObject]?
        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?

        os_unfair_lock_lock(&self.lock)
        if !self.terminated {
            self.terminated = true
            next = self.next
            self.next = nil
            error = self.error
            self.error = nil
            completed = self.completed
            self.completed = nil

            freeDisposable = self.takeSubscriberDisposable()
        }

        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil

        os_unfair_lock_unlock(&self.lock)

        if next != nil {
            next = nil
        }
        if error != nil {
            error = nil
        }
        if completed != nil {
            completed = nil
        }

        if let freeDisposableValue = freeDisposable {
            withExtendedLifetime(freeDisposableValue, {
            })
            freeDisposable = nil
        }

        self.releaseHandleDisposable()

        if let keepAliveObjectsValue = keepAliveObjects {
            withExtendedLifetime(keepAliveObjectsValue, {
            })
            keepAliveObjects = nil
        }
    }

    func putNext(_ next: T) {
        var action: ((T) -> Void)! = nil
        os_unfair_lock_lock(&self.lock)
        if !self.terminated {
            action = self.next
        }
        os_unfair_lock_unlock(&self.lock)

        if action != nil {
            action(next)
        }
    }

    func putError(_ error: E) {
        var action: ((E) -> Void)! = nil

        var disposeDisposable: Disposable?
        var keepAliveObjects: [AnyObject]?

        var next: ((T) -> Void)?
        var completed: (() -> Void)?

        os_unfair_lock_lock(&self.lock)
        if !self.terminated {
            action = self.error
            next = self.next
            self.next = nil
            self.error = nil
            completed = self.completed
            self.completed = nil
            self.terminated = true
            disposeDisposable = self.takeSubscriberDisposable()
        }
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        os_unfair_lock_unlock(&self.lock)

        if next != nil {
            next = nil
        }
        if completed != nil {
            completed = nil
        }

        if action != nil {
            action(error)
        }

        if let disposeDisposable = disposeDisposable {
            disposeDisposable.dispose()
        }

        self.releaseHandleDisposable()

        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
    }

    func putCompletion() {
        var action: (() -> Void)! = nil

        var disposeDisposable: Disposable? = nil
        var keepAliveObjects: [AnyObject]?

        var next: ((T) -> Void)?
        var error: ((E) -> Void)?
        var completed: (() -> Void)?

        os_unfair_lock_lock(&self.lock)
        if !self.terminated {
            action = self.completed
            next = self.next
            self.next = nil
            error = self.error
            self.error = nil
            completed = self.completed
            self.completed = nil
            self.terminated = true

            disposeDisposable = self.takeSubscriberDisposable()
        }
        keepAliveObjects = self.keepAliveObjects
        self.keepAliveObjects = nil
        os_unfair_lock_unlock(&self.lock)

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

        self.releaseHandleDisposable()

        if let keepAliveObjects = keepAliveObjects {
            withExtendedLifetime(keepAliveObjects, {
            })
        }
    }

    func keepAlive(_ object: AnyObject) {
        os_unfair_lock_lock(&self.lock)
        if self.keepAliveObjects == nil {
            self.keepAliveObjects = []
        }
        self.keepAliveObjects?.append(object)
        os_unfair_lock_unlock(&self.lock)
    }
}

public final class Subscriber<T, E>: CustomStringConvertible {
    private let coreReference: Unmanaged<SubscriberCore<T, E>>
    
    var core: SubscriberCore<T, E> {
        return self.coreReference.takeUnretainedValue()
    }
    
    public init(next: ((T) -> Void)! = nil, error: ((E) -> Void)! = nil, completed: (() -> Void)! = nil) {
        self.coreReference = Unmanaged.passRetained(SubscriberCore(next: next, error: error, completed: completed))
    }
    
    public var description: String {
        return self.coreReference.takeUnretainedValue().subscriberDescription
    }
    
    deinit {
        var resources = self.coreReference.takeUnretainedValue().takeSubscriberResources()
        self.coreReference.release()
        resources?.release()
    }
    
    public func putNext(_ next: T) {
        self.coreReference.takeUnretainedValue().putNext(next)
    }
    
    public func putError(_ error: E) {
        self.coreReference.takeUnretainedValue().putError(error)
    }
    
    public func putCompletion() {
        self.coreReference.takeUnretainedValue().putCompletion()
    }
    
    public func keepAlive(_ object: AnyObject) {
        self.coreReference.takeUnretainedValue().keepAlive(object)
    }
}
