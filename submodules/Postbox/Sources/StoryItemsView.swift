import Foundation

final class MutableStoryItemsView: MutablePostboxView {
    let peerId: PeerId
    var items: [StoryItemsTableEntry]

    init(postbox: PostboxImpl, peerId: PeerId) {
        self.peerId = peerId
        self.items = postbox.storyItemsTable.get(peerId: peerId)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.storyItemsEvents.isEmpty {
            loop: for event in transaction.storyItemsEvents {
                switch event {
                case .replace(peerId):
                    let items = postbox.storyItemsTable.get(peerId: self.peerId)
                    if self.items != items {
                        self.items = items
                        updated = true
                    }
                    break loop
                default:
                    break
                }
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let items = postbox.storyItemsTable.get(peerId: self.peerId)
        if self.items != items {
            self.items = items
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return StoryItemsView(self)
    }
}

public final class StoryItemsView: PostboxView {
    public let items: [StoryItemsTableEntry]
    
    init(_ view: MutableStoryItemsView) {
        self.items = view.items
    }
}
