import Foundation

public func beforeNext<T, E, R>(_ f: (T) -> R) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            return signal.start(next: { next in
                let _ = f(next)
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

public func afterNext<T, E, R>(_ f: (T) -> R) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            return signal.start(next: { next in
                subscriber.putNext(next)
                let _ = f(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

public func beforeStarted<T, E>(_ f: () -> Void) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            f()
            return signal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

public func beforeCompleted<T, E>(_ f: () -> Void) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            return signal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                f()
                subscriber.putCompletion()
            })
        }
    }
}

public func afterCompleted<T, E>(_ f: () -> Void) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            return signal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
                f()
            })
        }
    }
}

public func afterDisposed<T, E, R>(_ f: (Void) -> R) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal<T, E> { subscriber in
            let disposable = DisposableSet()
            disposable.add(signal.start(next: { next in
                subscriber.putNext(next)
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            }))
            disposable.add(ActionDisposable {
                let _ = f()
            })
            
            return disposable
        }
    }
}

public func withState<T, E, S>(_ signal: Signal<T, E>, _ initialState: () -> S, next: (T, S) -> Void = { _ in }, error: (E, S) -> Void = { _ in }, completed: (S) -> Void = { _ in }, disposed: (S) -> Void = { _ in }) -> Signal<T, E> {
    return Signal { subscriber in
        let state = initialState()
        let disposable = signal.start(next: { vNext in
            next(vNext, state)
            subscriber.putNext(vNext)
        }, error: { vError in
            error(vError, state)
            subscriber.putError(vError)
        }, completed: {
            completed(state)
            subscriber.putCompletion()
        })
        return ActionDisposable {
            disposable.dispose()
            disposed(state)
        }
    }
}
