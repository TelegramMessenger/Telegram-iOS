import Foundation

final class MutableStorySubscriptionsView: MutablePostboxView {
    var peerIds: [PeerId]
    
    init(postbox: PostboxImpl) {
        self.peerIds = postbox.storySubscriptionsTable.getAll()
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.storySubscriptionsEvents.isEmpty {
            loop: for event in transaction.storySubscriptionsEvents {
                switch event {
                case .replaceAll:
                    let peerIds = postbox.storySubscriptionsTable.getAll()
                    if self.peerIds != peerIds {
                        updated = true
                        self.peerIds = peerIds
                    }
                    
                    break loop
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let peerIds = postbox.storySubscriptionsTable.getAll()
        if self.peerIds != peerIds {
            self.peerIds = peerIds
            
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return StorySubscriptionsView(self)
    }
}

public final class StorySubscriptionsView: PostboxView {
    public let peerIds: [PeerId]
    
    init(_ view: MutableStorySubscriptionsView) {
        self.peerIds = view.peerIds
    }
}
