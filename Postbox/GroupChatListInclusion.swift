import Foundation

public enum GroupChatListInclusion: Equatable {
    case ifHasMessagesOrPinningIndex(pinningIndex: UInt16?)
    
    public func withPinningIndex(_ pinningIndex: UInt16?) -> GroupChatListInclusion {
        switch self {
            case .ifHasMessagesOrPinningIndex:
                return .ifHasMessagesOrPinningIndex(pinningIndex: pinningIndex)
        }
    }
    
    public func withoutPinningIndex() -> GroupChatListInclusion {
        switch self {
            case .ifHasMessagesOrPinningIndex:
                return .ifHasMessagesOrPinningIndex(pinningIndex: nil)
        }
    }
    
    public static func ==(lhs: GroupChatListInclusion, rhs: GroupChatListInclusion) -> Bool {
        switch lhs {
            case let .ifHasMessagesOrPinningIndex(lhsPinningIndex):
                if case let .ifHasMessagesOrPinningIndex(rhsPinningIndex) = rhs {
                    if lhsPinningIndex != rhsPinningIndex {
                        return false
                    }
                    return true
                } else {
                    return false
                }
        }
    }
}
