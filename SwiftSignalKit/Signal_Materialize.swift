import Foundation

public enum SignalEvent<T, E> {
    case Next(T)
    case Error(E)
    case Completion
}

public func materialize<T, E, NoError>(signal: Signal<SignalEvent<T, E>, NoError>) -> Signal<T, E> {
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
            subscriber.putCompletion()
        }, completed: {
            subscriber.putCompletion()
        })
    }
}
