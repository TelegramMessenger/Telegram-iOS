import Foundation

public enum SignalEvent<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

public func dematerialize<T, E>(signal: Signal<T, E>) -> Signal<SignalEvent<T, E>, NoError> {
    return Signal { subscriber in
        return signal.start(next: { next in
            subscriber.putNext(.Next(next))
        }, error: { error in
            subscriber.putNext(.Error(error))
            subscriber.putCompletion()
        }, completed: {
            subscriber.putNext(.Completion)
            subscriber.putCompletion()
        })
    }
}

public func materialize<T, E>(signal: Signal<SignalEvent<T, E>, NoError>) -> Signal<T, E> {
    return Signal { subscriber in
        return signal.start(next: { next in
            switch next {
                case let .Next(next):
                    subscriber.putNext(next)
                case let .Error(error):
                    subscriber.putError(error)
                case .Completion:
                    subscriber.putCompletion()
            }
        }, error: { _ in
        }, completed: {
            subscriber.putCompletion()
        })
    }
}
