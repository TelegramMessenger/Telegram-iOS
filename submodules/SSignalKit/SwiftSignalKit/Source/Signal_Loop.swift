import Foundation

public enum SignalFeedbackLoopState<T> {
    case initial
    case loop(T)
}

public func feedbackLoop<R1, R, E>(once: @escaping (SignalFeedbackLoopState<R1>) -> Signal<R1, E>?, reduce: @escaping (R1, R1) -> R1) -> Signal<R, E> {
    return Signal { subscriber in
        let currentDisposable = MetaDisposable()
        
        let state = Atomic<R1?>(value: nil)
        
        var loopAgain: (() -> Void)?
        
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
                    loopAgain?()
                }))
            } else {
                subscriber.putCompletion()
            }
        }
        
        loopAgain = { [weak currentDisposable] in
            loopOnce(currentDisposable)
        }
        
        loopOnce(currentDisposable)
        
        return ActionDisposable {
            currentDisposable.dispose()
        }
    }
}
