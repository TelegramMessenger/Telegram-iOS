import Foundation

public enum SignalFeedbackLoopState<T> {
    case initial
    case loop(T)
}

private final class FeedbackLoopContinuation {
    private var lock = os_unfair_lock()
    private var action: (() -> Void)?
    
    func set(_ action: (() -> Void)?) {
        os_unfair_lock_lock(&self.lock)
        let previous = self.action
        self.action = action
        os_unfair_lock_unlock(&self.lock)
        withExtendedLifetime(previous, {})
    }
    
    func get() -> (() -> Void)? {
        os_unfair_lock_lock(&self.lock)
        let action = self.action
        os_unfair_lock_unlock(&self.lock)
        return action
    }
}

public func feedbackLoop<R1, R, E>(once: @escaping (SignalFeedbackLoopState<R1>) -> Signal<R1, E>?, reduce: @escaping (R1, R1) -> R1) -> Signal<R, E> {
    return Signal { subscriber in
        let currentDisposable = MetaDisposable()
        
        let state = Atomic<R1?>(value: nil)
        
        let loopAgain = FeedbackLoopContinuation()
        
        let loopOnce: (MetaDisposable?) -> Void = { disposable in
            if let signal = once(.initial) {
                disposable?.set(signal.start(next: { next in
                    let _ = state.modify { value in
                        if let value = value {
                            return reduce(value, next)
                        } else {
                            return value
                        }
                    }
                }, error: { error in
                    subscriber.putError(error)
                }, completed: {
                    loopAgain.get()?()
                }))
            } else {
                subscriber.putCompletion()
            }
        }
        
        loopAgain.set({ [weak currentDisposable] in
            loopOnce(currentDisposable)
        })
        
        loopOnce(currentDisposable)
        
        return ActionDisposable {
            currentDisposable.dispose()
            loopAgain.set(nil)
        }
    }
}
