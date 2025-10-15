import Foundation

final class MutableCachedPeerDataView: MutablePostboxView {
    let peerId: PeerId
    let trackAssociatedMessages: Bool
    var cachedPeerData: CachedPeerData?
    var associatedMessages: [MessageId: Message] = [:]
    
    init(postbox: PostboxImpl, peerId: PeerId, trackAssociatedMessages: Bool) {
        self.peerId = peerId
        self.trackAssociatedMessages = trackAssociatedMessages
        self.cachedPeerData = postbox.cachedPeerDataTable.get(peerId)
        if let cachedPeerData = self.cachedPeerData {
            for id in cachedPeerData.messageIds {
                if let message = postbox.getMessage(id) {
                    self.associatedMessages[message.id] = message
                }
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if let cachedPeerData = transaction.currentUpdatedCachedPeerData[self.peerId]?.updated {
            self.cachedPeerData = cachedPeerData
            if self.trackAssociatedMessages {
                self.associatedMessages.removeAll()
                for id in cachedPeerData.messageIds {
                    if let message = postbox.getMessage(id) {
                        self.associatedMessages[message.id] = message
                    }
                }
            }
            
            return true
        } else {
            var updatedIds = Set<MessageId>()
            if self.trackAssociatedMessages {
                if let cachedPeerData = self.cachedPeerData {
                    for peerId in Set(cachedPeerData.messageIds.map(\.peerId)) {
                        if let operations = transaction.currentOperationsByPeerId[peerId] {
                            for operation in operations {
                                switch operation {
                                case let .InsertMessage(message):
                                    if cachedPeerData.messageIds.contains(message.id) {
                                        updatedIds.insert(message.id)
                                    }
                                case let .Remove(indices):
                                    for index in indices {
                                        if cachedPeerData.messageIds.contains(index.0.id) {
                                            updatedIds.insert(index.0.id)
                                        }
                                    }
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
            }
            if !updatedIds.isEmpty {
                for id in updatedIds {
                    if let message = postbox.getMessage(id) {
                        self.associatedMessages[message.id] = message
                    } else {
                        self.associatedMessages.removeValue(forKey: id)
                    }
                }
                return true
            } else {
                return false
            }
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return CachedPeerDataView(self)
    }
}

public final class CachedPeerDataView: PostboxView {
    public let peerId: PeerId
    public let cachedPeerData: CachedPeerData?
    public let associatedMessages: [MessageId: Message]
    
    init(_ view: MutableCachedPeerDataView) {
        self.peerId = view.peerId
        self.cachedPeerData = view.cachedPeerData
        self.associatedMessages = view.associatedMessages
    }
}
