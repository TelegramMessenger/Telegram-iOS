import UIKit

public enum PhotoCaptureResult: Equatable {
    case began
    case finished(UIImage, UIImage?, Double)
    case failed

    public static func == (lhs: PhotoCaptureResult, rhs: PhotoCaptureResult) -> Bool {
        switch lhs {
        case .began:
            if case .began = rhs {
                return true
            } else {
                return false
            }
        case .failed:
            if case .failed = rhs {
                return true
            } else {
                return false
            }
        case let .finished(_, _, lhsTime):
            if case let .finished(_, _, rhsTime) = rhs, lhsTime == rhsTime {
                return true
            } else {
                return false
            }
        }
    }
}
