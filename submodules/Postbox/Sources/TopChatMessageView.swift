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
