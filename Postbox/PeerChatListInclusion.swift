import Foundation

public enum PeerChatListInclusion: Equatable {
    case notSpecified
    case never
    case ifHasMessages
    case ifHasMessagesOrOneOf(pinningIndex: UInt16?, minTimestamp: Int32?)
    
    public func withSetIfHasMessagesOrMaxMinTimestamp(_ minTimestamp: Int32) -> PeerChatListInclusion {
        switch self {
            case let .ifHasMessagesOrOneOf(pinningIndex, currentMinTimestamp):
                var maxTimestamp: Int32 = minTimestamp
                if let currentMinTimestamp = currentMinTimestamp, currentMinTimestamp > maxTimestamp {
                    maxTimestamp = currentMinTimestamp
                }
                return .ifHasMessagesOrOneOf(pinningIndex: pinningIndex, minTimestamp: maxTimestamp)
            default:
                return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: minTimestamp)
        }
    }
    
    public func withPinningIndex(_ pinningIndex: UInt16?) -> PeerChatListInclusion {
        switch self {
            case let .ifHasMessagesOrOneOf(_, minTimestamp):
                return .ifHasMessagesOrOneOf(pinningIndex: pinningIndex, minTimestamp: minTimestamp)
            default:
                return .ifHasMessagesOrOneOf(pinningIndex: pinningIndex, minTimestamp: nil)
        }
    }
    
    public func withoutPinningIndex() -> PeerChatListInclusion {
        switch self {
            case let .ifHasMessagesOrOneOf(_, minTimestamp):
                return .ifHasMessagesOrOneOf(pinningIndex: nil, minTimestamp: minTimestamp)
            default:
                return self
        }
    }
    
    public static func ==(lhs: PeerChatListInclusion, rhs: PeerChatListInclusion) -> Bool {
        switch lhs {
            case .notSpecified:
                if case .notSpecified = rhs {
                    return true
                } else {
                    return false
                }
            case .never:
                if case .never = rhs {
                    return true
                } else {
                    return false
                }
            case .ifHasMessages:
                if case .ifHasMessages = rhs {
                    return true
                } else {
                    return false
                }
            case let .ifHasMessagesOrOneOf(lhsPinningIndex, lhsMinTimestamp):
                if case let .ifHasMessagesOrOneOf(rhsPinningIndex, rhsMinTimestamp) = rhs {
                    if lhsPinningIndex != rhsPinningIndex {
                        return false
                    }
                    if lhsMinTimestamp != rhsMinTimestamp {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}
