import Foundation

public enum PostboxViewKey: Hashable {
    case itemCollectionInfos(namespaces: [ItemCollectionId.Namespace])
    case peerChatState(peerId: PeerId)
    
    public var hashValue: Int {
        switch self {
            case .itemCollectionInfos:
                return 0
            case let .peerChatState(peerId):
                return peerId.hashValue
        }
    }
    
    public static func ==(lhs: PostboxViewKey, rhs: PostboxViewKey) -> Bool {
        switch lhs {
            case let .itemCollectionInfos(lhsNamespaces):
                if case let .itemCollectionInfos(rhsNamespaces) = rhs, lhsNamespaces == rhsNamespaces {
                    return true
                } else {
                    return false
                }
            case let .peerChatState(peerId):
                if case .peerChatState(peerId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

func postboxViewForKey(postbox: Postbox, key: PostboxViewKey) -> MutablePostboxView {
    switch key {
        case let .itemCollectionInfos(namespaces):
            return MutableItemCollectionInfosView(postbox: postbox, namespaces: namespaces)
        case let .peerChatState(peerId):
            return MutablePeerChatStateView(postbox: postbox, peerId: peerId)
    }
}
