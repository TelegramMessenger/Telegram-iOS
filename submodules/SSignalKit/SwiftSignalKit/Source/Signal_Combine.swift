import Foundation

private struct SignalCombineState {
    let values: [Int : Any]
    let completed: Set<Int>
    let error: Bool
}

private func combineLatestAny<E, R>(_ signals: [Signal<Any, E>], combine: @escaping([Any]) -> R, initialValues: [Int : Any], queue: Queue?) -> Signal<R, E> {
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
        for iterationIndex in 0 ..< count {
            let index = iterationIndex
            var signal = signals[index]
            if let queue = queue {
                signal = signal
                |> deliverOn(queue)
            }
            let signalDisposable = signal.start(next: { next in
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

public func combineLatest<T1, T2, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>) -> Signal<(T1, T2), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2)], combine: { values in
        return (values[0] as! T1, values[1] as! T2)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ v1: T1, _ s2: Signal<T2, E>, _ v2: T2) -> Signal<(T1, T2), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2)], combine: { values in
        return (values[0] as! T1, values[1] as! T2)
    }, initialValues: [0: v1, 1: v2], queue: queue)
}

public func combineLatest<T1, T2, T3, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>) -> Signal<(T1, T2, T3), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>) -> Signal<(T1, T2, T3, T4), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>) -> Signal<(T1, T2, T3, T4, T5), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>) -> Signal<(T1, T2, T3, T4, T5, T6), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>, _ s15: Signal<T15, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14), signalOfAny(s15)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14, values[14] as! T15)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>, _ s15: Signal<T15, E>, _ s16: Signal<T16, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14), signalOfAny(s15), signalOfAny(s16)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14, values[14] as! T15, values[15] as! T16)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>, _ s15: Signal<T15, E>, _ s16: Signal<T16, E>, _ s17: Signal<T17, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14), signalOfAny(s15), signalOfAny(s16), signalOfAny(s17)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14, values[14] as! T15, values[15] as! T16, values[16] as! T17)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>, _ s15: Signal<T15, E>, _ s16: Signal<T16, E>, _ s17: Signal<T17, E>, _ s18: Signal<T18, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14), signalOfAny(s15), signalOfAny(s16), signalOfAny(s17), signalOfAny(s18)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14, values[14] as! T15, values[15] as! T16, values[16] as! T17, values[17] as! T18)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19, E>(queue: Queue? = nil, _ s1: Signal<T1, E>, _ s2: Signal<T2, E>, _ s3: Signal<T3, E>, _ s4: Signal<T4, E>, _ s5: Signal<T5, E>, _ s6: Signal<T6, E>, _ s7: Signal<T7, E>, _ s8: Signal<T8, E>, _ s9: Signal<T9, E>, _ s10: Signal<T10, E>, _ s11: Signal<T11, E>, _ s12: Signal<T12, E>, _ s13: Signal<T13, E>, _ s14: Signal<T14, E>, _ s15: Signal<T15, E>, _ s16: Signal<T16, E>, _ s17: Signal<T17, E>, _ s18: Signal<T18, E>, _ s19: Signal<T19, E>) -> Signal<(T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11, T12, T13, T14, T15, T16, T17, T18, T19), E> {
    return combineLatestAny([signalOfAny(s1), signalOfAny(s2), signalOfAny(s3), signalOfAny(s4), signalOfAny(s5), signalOfAny(s6), signalOfAny(s7), signalOfAny(s8), signalOfAny(s9), signalOfAny(s10), signalOfAny(s11), signalOfAny(s12), signalOfAny(s13), signalOfAny(s14), signalOfAny(s15), signalOfAny(s16), signalOfAny(s17), signalOfAny(s18), signalOfAny(s19)], combine: { values in
        return (values[0] as! T1, values[1] as! T2, values[2] as! T3, values[3] as! T4, values[4] as! T5, values[5] as! T6, values[6] as! T7, values[7] as! T8, values[8] as! T9, values[9] as! T10, values[10] as! T11, values[11] as! T12, values[12] as! T13, values[13] as! T14, values[14] as! T15, values[15] as! T16, values[16] as! T17, values[17] as! T18, values[18] as! T19)
    }, initialValues: [:], queue: queue)
}

public func combineLatest<T, E>(queue: Queue? = nil, _ signals: [Signal<T, E>]) -> Signal<[T], E> {
    if signals.count == 0 {
        return single([T](), E.self)
    }
    
    return combineLatestAny(signals.map({signalOfAny($0)}), combine: { values in
        var combined: [T] = []
        for value in values {
            combined.append(value as! T)
        }
        return combined
    }, initialValues: [:], queue: queue)
}
