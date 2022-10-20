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
    case peer(PeerId)
}

final class MutableMessageOfInterestHolesView: MutablePostboxView {
    private let location: MessageOfInterestViewLocation
    private let count: Int
    private var anchor: HistoryViewInputAnchor
    private var wrappedView: MutableMessageHistoryView
    private var peerIds: MessageHistoryViewInput
    
    fileprivate var closestHole: MessageOfInterestHole?
    fileprivate var closestLaterMedia: [HolesViewMedia] = []
    
    init(postbox: PostboxImpl, location: MessageOfInterestViewLocation, namespace: MessageId.Namespace, count: Int) {
        self.location = location
        self.count = count
        
        let mainPeerId: PeerId
        let peerIds: MessageHistoryViewInput
        switch self.location {
        case let .peer(id):
            mainPeerId = id
            peerIds = postbox.peerIdsForLocation(.peer(id), ignoreRelatedChats: false)
        }
        self.peerIds = peerIds
        var anchor: HistoryViewInputAnchor = .upperBound
        if let combinedState = postbox.readStateTable.getCombinedState(mainPeerId), let state = combinedState.states.first, state.1.count != 0 {
            switch state.1 {
            case let .idBased(maxIncomingReadId, _, _, _, _):
                anchor = .message(MessageId(peerId: mainPeerId, namespace: state.0, id: maxIncomingReadId))
            case let .indexBased(maxIncomingReadIndex, _, _, _):
                anchor = .index(maxIncomingReadIndex)
            }
        }
        self.anchor = anchor
        self.wrappedView = MutableMessageHistoryView(postbox: postbox, orderStatistics: [], clipHoles: true, peerIds: peerIds, ignoreMessagesInTimestampRange: nil, anchor: self.anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, count: self.count, topTaggedMessages: [:], additionalDatas: [], getMessageCountInRange: { _, _ in return 0})
        let _ = self.updateFromView()
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
        switch self.location {
            case let .peer(id):
                peerId = id
        }
        var anchor: HistoryViewInputAnchor = self.anchor
        if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
            let updatedAnchor: HistoryViewInputAnchor = .upperBound
            if let combinedState = postbox.readStateTable.getCombinedState(peerId), let state = combinedState.states.first, state.1.count != 0 {
                switch state.1 {
                case let .idBased(maxIncomingReadId, _, _, _, _):
                    anchor = .message(MessageId(peerId: peerId, namespace: state.0, id: maxIncomingReadId))
                case let .indexBased(maxIncomingReadIndex, _, _, _):
                    anchor = .index(maxIncomingReadIndex)
                }
            }
            anchor = updatedAnchor
        }
        
        if self.anchor != anchor {
            self.anchor = anchor
            let peerIds: MessageHistoryViewInput
            switch self.location {
            case let .peer(id):
                peerIds = postbox.peerIdsForLocation(.peer(id), ignoreRelatedChats: false)
            }
            self.wrappedView = MutableMessageHistoryView(postbox: postbox, orderStatistics: [], clipHoles: true, peerIds: peerIds, ignoreMessagesInTimestampRange: nil, anchor: self.anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, count: self.count, topTaggedMessages: [:], additionalDatas: [], getMessageCountInRange: { _, _ in return 0})
            return self.updateFromView()
        } else if self.wrappedView.replay(postbox: postbox, transaction: transaction) {
            var reloadView = false
            if !transaction.currentPeerHoleOperations.isEmpty {
                var allPeerIds: [PeerId]
                switch peerIds {
                case let .single(peerId):
                    allPeerIds = [peerId]
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
                    if allPeerIds.contains(key.peerId) {
                        reloadView = true
                        break
                    }
                }
            }
            if reloadView {
                let peerIds: MessageHistoryViewInput
                switch self.location {
                case let .peer(id):
                    peerIds = postbox.peerIdsForLocation(.peer(id), ignoreRelatedChats: false)
                }
                self.wrappedView = MutableMessageHistoryView(postbox: postbox, orderStatistics: [], clipHoles: true, peerIds: peerIds, ignoreMessagesInTimestampRange: nil, anchor: self.anchor, combinedReadStates: nil, transientReadStates: nil, tag: nil, appendMessagesFromTheSameGroup: false, namespaces: .all, count: self.count, topTaggedMessages: [:], additionalDatas: [], getMessageCountInRange: { _, _ in return 0})
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
