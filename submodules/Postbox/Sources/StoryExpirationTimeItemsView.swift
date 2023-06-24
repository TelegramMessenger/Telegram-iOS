import Foundation

public struct StoryExpirationTimeEntry: Equatable {
    public var id: StoryId
    public var expirationTimestamp: Int32

    init(id: StoryId, expirationTimestamp: Int32) {
        self.id = id
        self.expirationTimestamp = expirationTimestamp
    }
}

final class MutableStoryExpirationTimeItemsView: MutablePostboxView {
    var topEntry: StoryExpirationTimeEntry?

    init(postbox: PostboxImpl) {
        let _ = self.refreshDueToExternalTransaction(postbox: postbox)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.storyItemsEvents.isEmpty {
            var refresh = false
            loop: for event in transaction.storyItemsEvents {
                switch event {
                case .replace:
                    refresh = true
                    break loop
                }
            }
            if refresh {
                updated = self.refreshDueToExternalTransaction(postbox: postbox)
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        var topEntry: StoryExpirationTimeEntry?
        if let item = postbox.storyItemsTable.getMinExpirationTimestamp() {
            topEntry = StoryExpirationTimeEntry(id: item.0, expirationTimestamp: item.1)
        }
        if self.topEntry != topEntry {
            self.topEntry = topEntry
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return StoryExpirationTimeItemsView(self)
    }
}

public final class StoryExpirationTimeItemsView: PostboxView {
    public let topEntry: StoryExpirationTimeEntry?
    
    init(_ view: MutableStoryExpirationTimeItemsView) {
        self.topEntry = view.topEntry
    }
}
