import Foundation

public struct HolesViewMedia: Comparable {
    public let media: Media
    public let peer: Peer
    public let authorIsContact: Bool
    public let index: MessageIndex
    
    public static func ==(lhs: HolesViewMedia, rhs: HolesViewMedia) -> Bool {
        return lhs.index == rhs.index && (lhs.media === rhs.media || lhs.media.isEqual(to: rhs.media)) && lhs.peer.isEqual(rhs.peer) && lhs.authorIsContact == rhs.authorIsContact
    }
    
    public static func <(lhs: HolesViewMedia, rhs: HolesViewMedia) -> Bool {
        return lhs.index < rhs.index
    }
}

public struct MessageOfInterestHole: Hashable, Equatable {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
}

public enum MessageOfInterestViewLocation: Hashable {
    case peer(PeerId)
    
    public static func ==(lhs: MessageOfInterestViewLocation, rhs: MessageOfInterestViewLocation) -> Bool {
        switch lhs {
            case let .peer(value):
                if case .peer(value) = rhs {
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
        }
    }
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    init(postbox: Postbox, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int) {
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return MessageOfInterestHolesView(self)
    }
}

public final class MessageOfInterestHolesView: PostboxView {
    public let closestHole: MessageOfInterestHole?
    public let closestLaterMedia: [HolesViewMedia]
    
    init(_ view: MutableMessageOfInterestHolesView) {
        self.closestHole = nil
        self.closestLaterMedia = []
    }
}
