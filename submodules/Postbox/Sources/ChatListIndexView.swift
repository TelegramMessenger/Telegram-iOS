import Foundation

final class MutableChatListIndexView: MutablePostboxView {
    fileprivate let id: PeerId
    fileprivate var chatListIndex: ChatListIndex?
    fileprivate var inclusion: PeerChatListInclusion

    init(postbox: PostboxImpl, id: PeerId) {
        self.id = id
        self.chatListIndex = postbox.chatListIndexTable.get(peerId: id).includedIndex(peerId: self.id)?.1
        self.inclusion = postbox.chatListIndexTable.get(peerId: id).inclusion
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        if transaction.currentUpdatedChatListInclusions[self.id] != nil || transaction.currentOperationsByPeerId[self.id] != nil {
            updated = true
        }

        if updated {
            let chatListIndex = postbox.chatListIndexTable.get(peerId: id).includedIndex(peerId: self.id)?.1
            let inclusion = postbox.chatListIndexTable.get(peerId: id).inclusion
            if self.chatListIndex != chatListIndex || self.inclusion != inclusion {
                self.chatListIndex = chatListIndex
                self.inclusion = inclusion
                
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        return false
    }
    
    func immutableView() -> PostboxView {
        return ChatListIndexView(self)
    }
}

public final class ChatListIndexView: PostboxView {
    public let chatListIndex: ChatListIndex?
    public let inclusion: PeerChatListInclusion
    
    init(_ view: MutableChatListIndexView) {
        self.chatListIndex = view.chatListIndex
        self.inclusion = view.inclusion
    }
}
