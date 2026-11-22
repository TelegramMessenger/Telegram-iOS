import Foundation

/// The observable state of one pre-upload.
///
/// `Value` is whatever the producer eventually yields — in this project, a cloud `Media`.
/// The registry itself never inspects it.
public enum PreuploadState<Value> {
    case progress(Float)
    case done(Value)
    case failed
}

public extension PreuploadState {
    /// `.progress` is the only non-terminal state. The registry relies on this to know when a
    /// context has finished and when a `join` subscriber may be completed.
    var isTerminal: Bool {
        switch self {
        case .progress:
            return false
        case .done, .failed:
            return true
        }
    }
}
