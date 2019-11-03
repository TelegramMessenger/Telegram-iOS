import Foundation
import SwiftSignalKit

public enum MediaResourceStatus: Equatable {
    case Remote
    case Local
    case Fetching(isActive: Bool, progress: Float)
}

public func ==(lhs: MediaResourceStatus, rhs: MediaResourceStatus) -> Bool {
    switch lhs {
        case .Remote:
            switch rhs {
                case .Remote:
                    return true
                default:
                    return false
            }
        case .Local:
            switch rhs {
                case .Local:
                    return true
                default:
                    return false
            }
        case let .Fetching(lhsIsActive, lhsProgress):
            switch rhs {
                case let .Fetching(rhsIsActive, rhsProgress):
                    return lhsIsActive == rhsIsActive && lhsProgress.isEqual(to: rhsProgress)
                default:
                    return false
            }
    }
}
