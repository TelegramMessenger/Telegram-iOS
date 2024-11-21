import Foundation

public func take<T, E>(_ count: Int) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            let counter = Atomic(value: 0)
            return signal.start(next: { next in
                var passthrough = false
                var complete = false
                let _ = counter.modify { value in
                    let updatedCount = value + 1
                    passthrough = updatedCount <= count
                    complete = updatedCount == count
                    return updatedCount
                }
                if passthrough {
                    subscriber.putNext(next)
                }
                if complete {
                    subscriber.putCompletion()
                }
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

public func takeLast<T, E>(_ signal: Signal<T, E>) -> Signal<T, E> {
    return Signal { subscriber in
        let lastValue = Atomic<T?>(value: nil)
        return signal.start(next: { next in
            let _ = lastValue.swap(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            if let value = lastValue.with({ $0 }) {
                subscriber.putNext(value)
            }
            subscriber.putCompletion()
        })
    }
}

public struct SignalTakeAction {
    public let passthrough: Bool
    public let complete: Bool
    
    public init(passthrough: Bool, complete: Bool) {
        self.passthrough = passthrough
        self.complete = complete
    }
}

public func take<T, E>(until: @escaping (T) -> SignalTakeAction) -> (Signal<T, E>) -> Signal<T, E> {
    return { signal in
        return Signal { subscriber in
            return signal.start(next: { next in
                let action = until(next)
                if action.passthrough {
                    subscriber.putNext(next)
                }
                if action.complete {
                    subscriber.putCompletion()
                }
            }, error: { error in
                subscriber.putError(error)
            }, completed: {
                subscriber.putCompletion()
            })
        }
    }
}

public func last<T, E>(signal: Signal<T, E>) -> Signal<T?, E> {
    return Signal { subscriber in
        let value = Atomic<T?>(value: nil)
        return signal.start(next: { next in
            let _ = value.swap(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putNext(value.with({ $0 }))
            subscriber.putCompletion()
        })
    }
}
