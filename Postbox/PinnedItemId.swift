import Foundation

public enum PinnedItemId: Hashable {
    case peer(PeerId)
    case group(PeerGroupId)
    
    public static func ==(lhs: PinnedItemId, rhs: PinnedItemId) -> Bool {
        switch lhs {
            case let .peer(id):
                if case .peer(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .group(id):
                if case .group(id) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public var hashValue: Int {
        switch self {
            case let .peer(id):
                return id.hashValue
            case let .group(id):
                return id.hashValue
        }
    }
}
