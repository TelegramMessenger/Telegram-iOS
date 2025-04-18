import Foundation

public enum MessageHistoryAnchorIndex: Comparable {
    case message(MessageIndex)
    case lowerBound
    case upperBound
    
    public static func <(lhs: MessageHistoryAnchorIndex, rhs: MessageHistoryAnchorIndex) -> Bool {
        switch lhs {
            case let .message(lhsIndex):
                switch rhs {
                    case let .message(rhsIndex):
                        return lhsIndex < rhsIndex
                    case .lowerBound:
                        return false
                    case .upperBound:
                        return true
                }
            case .lowerBound:
                if case .lowerBound = rhs {
                    return false
                } else {
                    return true
                }
            case .upperBound:
                return false
        }
    }
    
    public func isLess(than: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index):
                return index < than
        }
    }
    
    public func isLessOrEqual(to: MessageIndex) -> Bool {
        switch self {
            case .lowerBound:
                return true
            case .upperBound:
                return false
            case let .message(index):
                return index <= to
        }
    }
}
