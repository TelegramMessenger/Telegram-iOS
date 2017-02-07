import Foundation

private struct SignalCombineState {
    let values: [Int : Any]
    let completed: Set<Int>
    let error: Bool
}

private func combineLatestAny<E, R>(_ signals: [Signal<Any, E>], combine: @escaping([Any]) -> R, initialValues: [Int : Any]) -> Signal<R, E> {
    return Signal { subscriber in
        let state = Atomic(value: SignalCombineState(values: initialValues, completed: Set(), error: false))
        let disposable = DisposableSet()
        
        if initialValues.count == signals.count {
            var values: [Any] = []
            for i in 0 ..< initialValues.count {
                values.append(initialValues[i]!)
            }
            subscriber.putNext(combine(values))
        }
        
        let count = signals.count
        for index in 0 ..< count {
            let signalDisposable = signals[index].start(next: { next in
                let currentState = state.modify { current in
                    var values = current.values
                    values[index] = next
                    return SignalCombineState(values: values, completed: current.completed, error: current.error)
                }
                if currentState.values.count == count {
                    var values: [Any] = []
                    for i in 0 ..< count {
                        values.append(currentState.values[i]!)
                    }
                    subscriber.putNext(combine(values))
                }
            }, error: { error in
                var emitError = false
                let _ = state.modify { current in
                    if !current.error {
                        emitError = true
                        return SignalCombineState(values: current.values, completed: current.completed, error: true)
                    } else {
                        return current
                    }
                }
                if emitError {
                    subscriber.putError(error)
                }
            }, completed: {
                var emitCompleted = false
                let _ = state.modify { current in
                    if !current.completed.contains(index) {
                        var completed = current.completed
                        completed.insert(index)
                        emitCompleted = completed.count == count
                        return SignalCombineState(values: current.values, completed: completed, error: current.error)
                    }
                    return current
                }
                if emitCompleted {
                    subscriber.putCompletion()
                }
            })
            
            disposable.add(signalDisposable)
        }
        
        return disposable;
    }
}

private func signalOfAny<T, E>(_ signal: Signal<T, E>) -> Signal<Any, E> {
    return Signal { subscriber in
        return signal.start(next: { next in
            subscriber.putNext(next)
        }, error: { error in
            subscriber.putError(error)
        }, completed: {
            subscriber.putCompletion()
        })
    }
}

public func combineLatest<T1, T2, E>(_ s1: Signal<T1, E>, _ s2: Signal<T2, E>) -> Signal<(T1, T2), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2)], combine: { values in
        return (values[0] as! T1, values[1] as! T2)
    }, initialValues: [:])
}

public func combineLatest<T1, T2, E>(_ s1: Signal<T1, E>, _ v1: T1, _ s2: Signal<T2, E>, _ v2: T2) -> Signal<(T1, T2), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2)], combine: { values in
        return (values[0] as! T1, values[1] as! T2)
    }, initialValues: [0: v1, 1: v2])
}

public func combineLatest<T1, T2, T3, E>(_ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>) -> Signal<(T1, T2, T3), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3)
    }, initialValues: [:])
}

public func combineLatest<T1, T2, T3, T4, E>(_ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>) -> Signal<(T1, T2, T3, T4), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4)
    }, initialValues: [:])
}

public func combineLatest<T1, T2, T3, T4, T5, E>(_ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>) -> Signal<(T1, T2, T3, T4, T5), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5)
    }, initialValues: [:])
}

public func combineLatest<T, E>(_ signals: [Signal<T, E>]) -> Signal<[T], E> {
    if signals.count == 0 {
        return single([T](), E.self)
    }
    
    return combineLatestAny(signals.map({signalOfAny($0)}), combine: { values in
        var combined: [T] = []
        for value in values {
            combined.append(value as! T)
        }
        return combined
    }, initialValues: [:])
}
