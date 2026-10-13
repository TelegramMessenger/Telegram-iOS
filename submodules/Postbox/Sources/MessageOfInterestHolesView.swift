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

public struct MessageOfInterestHole: Hashable, Equatable, CustomStringConvertible {
    public let hole: MessageHistoryViewHole
    public let direction: MessageHistoryViewRelativeHoleDirection
    
    public var description: String {
        return "hole: \(self.hole), direction: \(self.direction)"
    }
}

public enum MessageOfInterestViewLocation: Hashable {
    case peer(peerId: PeerId, threadId: Int64?)
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    private let location: MessageOfInterestViewLocation
    private let namespace: MessageId.Namespace
    private let count: Int
    private var anchor: HistoryViewInputAnchor
    private var wrappedView: MutableMessageHistoryView
    private var peerIds: MessageHistoryViewInput
    
    fileprivate var closestHole: MessageOfInterestHole?
    fileprivate var closestLaterMedia: [HolesViewMedia] = []
    
    init(postbox: PostboxImpl, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int) {
        self.location = location
        self.namespace = namespace
        self.count = count
        
        let mainPeerId: PeerId
        let peerIds: MessageHistoryViewInput
        switch self.location {
        case let .peer(id, threadId):
            mainPeerId = id
            peerIds = postbox.peerIdsForLocation(.peer(peerId: id, threadId: threadId), ignoreRelatedChats: false)
        }
        self.peerIds = peerIds
        self.anchor = MutableMessageOfInterestHolesView.unreadAnchor(postbox: postbox, peerId: mainPeerId, namespace: namespace)
        self.wrappedView = MutableMessageOfInterestHolesView.makeWrappedView(postbox: postbox, peerIds: peerIds, anchor: self.anchor, count: self.count)
        let _ = self.updateFromView()
    }
    
    /// The last read message while there are unread messages, otherwise the top of the
    /// history: the place the preload manager wants loaded.
    private static func unreadAnchor(postbox: PostboxImpl, peerId: PeerId, namespace: MessageId.Namespace) -> HistoryViewInputAnchor {
        if let combinedState = postbox.readStateTable.getCombinedState(peerId), let state = combinedState.states.first(where: { $0.0 == namespace }), state.1.count != 0 {
            switch state.1 {
            case let .idBased(maxIncomingReadId, _, _, _, _):
                return .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
            case let .indexBased(maxIncomingReadIndex, _, _, _):
                return .index(maxIncomingReadIndex)
            }
        }
        return .upperBound
    }
    
    /// Hole tracking stays on for every build: without it the wrapped view's `firstHole()`
    /// answers nil and the preload manager stops fetching for this chat.
    private static func makeWrappedView(postbox: PostboxImpl, peerIds: MessageHistoryViewInput, anchor: HistoryViewInputAnchor, count: Int) -> MutableMessageHistoryView {
        return MutableMessageHistoryView(postbox: postbox, orderStatistics: [], clipHoles: true, trackHoles: true, peerIds: peerIds, ignoreMessagesInTimestampRange: nil, ignoreMessageIds: Set(), anchor: anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, count: count, topTaggedMessages: [:], additionalDatas: [])
    }
    
    private func updateFromView() -> Bool {
        let closestHole: MessageOfInterestHole?
        if let (hole, direction, _, _) = self.wrappedView.firstHole() {
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
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var peerId: PeerId
        var threadId: Int64?
        switch self.location {
        case let .peer(id, threadIdValue):
            peerId = id
            threadId = threadIdValue
        }
        var anchor: HistoryViewInputAnchor = self.anchor
        if threadId == nil, transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
            anchor = MutableMessageOfInterestHolesView.unreadAnchor(postbox: postbox, peerId: peerId, namespace: self.namespace)
        }
        
        if self.anchor != anchor {
            self.anchor = anchor
            let peerIds: MessageHistoryViewInput
            switch self.location {
            case let .peer(id, threadId):
                peerIds = postbox.peerIdsForLocation(.peer(peerId: id, threadId: threadId), ignoreRelatedChats: false)
            }
            self.peerIds = peerIds
            self.wrappedView = MutableMessageOfInterestHolesView.makeWrappedView(postbox: postbox, peerIds: peerIds, anchor: self.anchor, count: self.count)
            return self.updateFromView()
        } else if self.wrappedView.replay(postbox: postbox, transaction: transaction) {
            var reloadView = false
            if !transaction.currentPeerHoleOperations.isEmpty {
                var allPeerIds: [PeerId]
                var threadId: Int64?
                switch peerIds {
                case let .single(peerId, threadIdValue):
                    allPeerIds = [peerId]
                    threadId = threadIdValue
                case let .associated(peerId, attachedMessageId):
                    allPeerIds = [peerId]
                    if let attachedMessageId = attachedMessageId {
                        allPeerIds.append(attachedMessageId.peerId)
                    }
                case .external:
                    allPeerIds = []
                    break
                }
                for (key, _) in transaction.currentPeerHoleOperations {
                    if allPeerIds.contains(key.peerId) && key.threadId == threadId {
                        reloadView = true
                        break
                    }
                }
            }
            if reloadView {
                let peerIds: MessageHistoryViewInput
                switch self.location {
                case let .peer(id, threadId):
                    peerIds = postbox.peerIdsForLocation(.peer(peerId: id, threadId: threadId), ignoreRelatedChats: false)
                }
                self.peerIds = peerIds
                self.wrappedView = MutableMessageOfInterestHolesView.makeWrappedView(postbox: postbox, peerIds: peerIds, anchor: self.anchor, count: self.count)
            }
            
            return self.updateFromView()
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
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
        self.closestHole = view.closestHole
        self.closestLaterMedia = view.closestLaterMedia
    }
}
