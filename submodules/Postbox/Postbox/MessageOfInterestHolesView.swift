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
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    private let location: MessageOfInterestViewLocation
    private let count: Int
    private var anchor: HistoryViewInputAnchor
    private var wrappedView: MutableMessageHistoryView
    
    fileprivate var closestHole: MessageOfInterestHole?
    fileprivate var closestLaterMedia: [HolesViewMedia] = []
    
    init(postbox: Postbox, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int) {
        self.location = location
        self.count = count
        
        var peerId: PeerId
        switch self.location {
            case let .peer(id):
                peerId = id
        }
        var anchor: HistoryViewInputAnchor = .upperBound
        if let combinedState = postbox.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
            switch state.1 {
                case let .idBased(maxIncomingReadId, _, _, _, _):
                    anchor = .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
                case let .indexBased(maxIncomingReadIndex, _, _, _):
                    anchor = .index(maxIncomingReadIndex)
            }
        }
        self.anchor = anchor
        self.wrappedView = MutableMessageHistoryView(postbox: postbox, orderStatistics: [], peerIds: .single(peerId), anchor: self.anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, namespaces: .all, count: self.count, topTaggedMessages: [:], additionalDatas: [], getMessageCountInRange: { _, _ in return 0})
        let _ = self.updateFromView()
    }
    
    private func updateFromView() -> Bool {
        let closestHole: MessageOfInterestHole?
        if let (hole, direction) = self.wrappedView.firstHole() {
            closestHole = MessageOfInterestHole(hole: hole, direction: direction)
        } else {
            closestHole = nil
        }
        
        var closestLaterMedia: [HolesViewMedia] = []
        switch self.wrappedView.sampledState {
            case .loading:
                break
            case let .loaded(sample):
                switch sample.anchor {
                    case .index:
                        let anchorIndex = binaryIndexOrLower(sample.entries, sample.anchor)
                        loop: for i in max(0, anchorIndex) ..< sample.entries.count {
                            let message = sample.entries[i].message
                            if !message.media.isEmpty, let peer = message.peers[message.id.peerId] {
                                for media in message.media {
                                    closestLaterMedia.append(HolesViewMedia(media: media, peer: peer, authorIsContact: sample.entries[i].attributes.authorIsContact, index: message.index))
                                }
                            }
                            if closestLaterMedia.count >= 3 {
                                break loop
                            }
                        }
                    case .lowerBound, .upperBound:
                        break
                }
        }
        
        if self.closestHole != closestHole || self.closestLaterMedia != closestLaterMedia {
            self.closestHole = closestHole
            self.closestLaterMedia = closestLaterMedia
            return true
        } else {
            return false
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var peerId: PeerId
        switch self.location {
            case let .peer(id):
                peerId = id
        }
        var anchor: HistoryViewInputAnchor = self.anchor
        if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
            if let combinedState = postbox.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
                switch state.1 {
                    case let .idBased(maxIncomingReadId, _, _, _, _):
                        anchor = .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
                    case let .indexBased(maxIncomingReadIndex, _, _, _):
                        anchor = .index(maxIncomingReadIndex)
                }
            }
        }
        
        if self.anchor != anchor {
            self.anchor = anchor
            self.wrappedView = MutableMessageHistoryView(postbox: postbox, orderStatistics: [], peerIds: .single(peerId), anchor: self.anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, namespaces: .all, count: self.count, topTaggedMessages: [:], additionalDatas: [], getMessageCountInRange: { _, _ in return 0})
            return self.updateFromView()
        } else if self.wrappedView.replay(postbox: postbox, transaction: transaction) {
            return self.updateFromView()
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return MessageOfInterestHolesView(self)
    }
}

public final class MessageOfInterestHolesView: PostboxView {
    public let closestHole: MessageOfInterestHole?
    public let closestLaterMedia: [HolesViewMedia]
    
    init(_ view: MutableMessageOfInterestHolesView) {
        self.closestHole = view.closestHole
        self.closestLaterMedia = view.closestLaterMedia
    }
}
