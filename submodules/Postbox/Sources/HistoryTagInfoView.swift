import Foundation

final class MutableHistoryTagInfoView: MutablePostboxView {
    fileprivate let peerId: PeerId
    fileprivate let tag: MessageTags
    
    fileprivate var currentIndex: MessageIndex?
    
    init(postbox: PostboxImpl, peerId: PeerId, tag: MessageTags) {
        self.peerId = peerId
        self.tag = tag
        for namespace in postbox.messageHistoryIndexTable.existingNamespaces(peerId: self.peerId) {
            if let index = postbox.messageHistoryTagsTable.latestIndex(tag: self.tag, peerId: self.peerId, namespace: namespace) {
                self.currentIndex = index
                break
            }
        }
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        if let operations = transaction.currentOperationsByPeerId[self.peerId] {
            var updated = false
            var refresh = false
            for operation in operations {
                switch operation {
                case let .InsertMessage(message):
                    if self.currentIndex == nil {
                        if message.tags.contains(self.tag) {
                            self.currentIndex = message.index
                            updated = true
                        }
                    }
                case let .Remove(indicesAndTags):
                    if self.currentIndex != nil {
                        for (index, tags) in indicesAndTags {
                            if tags.contains(self.tag) {
                                if index == self.currentIndex {
                                    self.currentIndex = nil
                                    updated = true
                                    refresh = true
                                }
                            }
                        }
                    }
                default:
                    break
                }
            }
            
            if refresh {
                for namespace in postbox.messageHistoryIndexTable.existingNamespaces(peerId: self.peerId) {
                    if let index = postbox.messageHistoryTagsTable.latestIndex(tag: self.tag, peerId: self.peerId, namespace: namespace) {
                        self.currentIndex = index
                        break
                    }
                }
            }
            
            return updated
        } else {
            return false
        }
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        /*var currentIndex: MessageIndex?
        for namespace in postbox.messageHistoryIndexTable.existingNamespaces(peerId: self.peerId) {
            if let index = postbox.messageHistoryTagsTable.latestIndex(tag: self.tag, peerId: self.peerId, namespace: namespace) {
                currentIndex = index
                break
            }
        }
        if self.currentIndex != currentIndex {
            self.currentIndex = currentIndex
            return true
        } else {
            return false
        }*/
        return false
    }
    
    func immutableView() -> PostboxView {
        return HistoryTagInfoView(self)
    }
}

public final class HistoryTagInfoView: PostboxView {
    public let isEmpty: Bool
    
    init(_ view: MutableHistoryTagInfoView) {
        self.isEmpty = view.currentIndex == nil
    }
}
