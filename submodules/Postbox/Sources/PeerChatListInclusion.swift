import Foundation

public enum PeerChatListInclusion: Equatable {
    case notIncluded
    case ifHasMessagesOrOneOf(groupId: PeerGroupId, pinningIndex: UInt16?, minTimestamp: Int32?)
    
    public var groupId: PeerGroupId? {
        switch self {
            case .notIncluded:
                return nil
            case let .ifHasMessagesOrOneOf(groupId, _, _):
                return groupId
        }
    }
    
    public func withPinningIndex(groupId: PeerGroupId, pinningIndex: UInt16?) -> PeerChatListInclusion {
        switch self {
            case let .ifHasMessagesOrOneOf(_, _, minTimestamp):
                return .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: pinningIndex, minTimestamp: minTimestamp)
            default:
                return .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: pinningIndex, minTimestamp: nil)
        }
    }
    
    public func withoutPinningIndex() -> PeerChatListInclusion {
        switch self {
            case let .ifHasMessagesOrOneOf(groupId, _, minTimestamp):
                return .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: nil, minTimestamp: minTimestamp)
            default:
                return self
        }
    }
    
    public func withGroupId(groupId: PeerGroupId) -> PeerChatListInclusion {
        switch self {
            case .notIncluded:
                return self
            case let .ifHasMessagesOrOneOf(_, pinningIndex, minTimestamp):
                return .ifHasMessagesOrOneOf(groupId: groupId, pinningIndex: pinningIndex, minTimestamp: minTimestamp)
        }
    }
}
