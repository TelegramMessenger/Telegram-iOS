import Foundation

private struct SignalCombineState {
    let values: [Int : Any]
    let completed: Set<Int>
    let error: Bool
}

private func combineLatestAny<E, R>(signals: [Signal<Any, E>], combine: [Any] -> R) -> Signal<R, E> {
    return Signal { subscriber in
        
        let state = Atomic(value: SignalCombineState(values: [:], completed: Set(), error: false))
        let disposable = DisposableSet()
        
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
                state.modify { current in
                    if !current.error {
                        emitError = true
                        return SignalCombineState(values: current.values, completed: current.completed, error: true)
                    } else {
                        return current
                    }
                }
            }, completed: {
                var emitCompleted = false
                state.modify { current in
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

private func signalOfAny<T, E>(signal: Signal<T, E>) -> Signal<Any, E> {
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

public func combineLatest<T1, T2, E>(s1: Signal<T1, E>, s2: Signal<T2, E>) -> Signal<(T1, T2), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2)], { values in
        return (values[0] as! T1, values[1] as! T2)
    })
}

public func combineLatest<T1, T2, T3, E>(s1: Signal<T1, E>, s2: Signal<T2, E>, s3: Signal<T3, E>) -> Signal<(T1, T2, T3), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3)], { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3)
    })
}

public func combineLatest<T1, T2, T3, T4, E>(s1: Signal<T1, E>, s2: Signal<T2, E>, s3: Signal<T3, E>, s4: Signal<T4, E>) -> Signal<(T1, T2, T3, T4), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4)], { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4)
    })
}
