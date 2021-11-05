import Foundation

final class MutableTopChatMessageView: MutablePostboxView {
    private let peerIds: Set<PeerId>
    fileprivate var messages: [PeerId: Message] = [:]
    
    init(postbox: PostboxImpl, peerIds: Set<PeerId>) {
        self.peerIds = peerIds
        
        for peerId in self.peerIds {
            if let index = postbox.chatListIndexTable.get(peerId: peerId).topMessageIndex {
                self.messages[peerId] = postbox.getMessage(index.id)
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        for peerId in self.peerIds {
            if transaction.currentOperationsByPeerId[peerId] != nil {
                if let index = postbox.chatListIndexTable.get(peerId: peerId).topMessageIndex {
                    self.messages[peerId] = postbox.getMessage(index.id)
                } else {
                    self.messages.removeValue(forKey: peerId)
                }
                updated = true
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*var messages: [PeerId: Message] = [:]

        for peerId in self.peerIds {
            if let index = postbox.chatListIndexTable.get(peerId: peerId).topMessageIndex {
                messages[peerId] = postbox.getMessage(index.id)
            }
        }

        var updated = false

        if self.messages.count != messages.count {
            updated = true
        } else {
            for (key, value) in self.messages {
                if let other = messages[key] {
                    if other.stableId != value.stableId || other.stableVersion != value.stableVersion {
                        updated = true
                        break
                    }
                } else {
                    updated = true
                    break
                }
            }
        }

        if updated {
            self.messages = messages
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return TopChatMessageView(self)
    }
}

public final class TopChatMessageView: PostboxView {
    public let messages: [PeerId: Message]
    
    init(_ view: MutableTopChatMessageView) {
        self.messages = view.messages
    }
}
