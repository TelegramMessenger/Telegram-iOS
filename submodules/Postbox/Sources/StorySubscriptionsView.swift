import Foundation

public enum PostboxStorySubscriptionsKey: Int32 {
    case hidden = 0
    case filtered = 1
}

final class MutableStorySubscriptionsView: MutablePostboxView {
    private let key: PostboxStorySubscriptionsKey
    var peerIds: [PeerId]
    
    init(postbox: PostboxImpl, key: PostboxStorySubscriptionsKey) {
        self.key = key
        self.peerIds = postbox.storySubscriptionsTable.getAll(subscriptionsKey: self.key)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.storySubscriptionsEvents.isEmpty {
            loop: for event in transaction.storySubscriptionsEvents {
                switch event {
                case let .replaceAll(key):
                    if key == self.key {
                        let peerIds = postbox.storySubscriptionsTable.getAll(subscriptionsKey: self.key)
                        if self.peerIds != peerIds {
                            updated = true
                            self.peerIds = peerIds
                        }
                        
                        break loop
                    }
                }
            }
        }
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let peerIds = postbox.storySubscriptionsTable.getAll(subscriptionsKey: self.key)
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
