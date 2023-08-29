import Foundation

final class MutableStoryView: MutablePostboxView {
    let id: StoryId
    var item: CodableEntry?

    init(postbox: PostboxImpl, id: StoryId) {
        self.id = id
        self.item = postbox.storyTable.get(id: self.id)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        for event in transaction.storyEvents {
            switch event {
            case .updated(self.id):
                let item = postbox.storyTable.get(id: self.id)
                if self.item != item {
                    self.item = item
                    updated = true
                }
            default:
                break
            }
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let item = postbox.storyTable.get(id: self.id)
        if self.item != item {
            self.item = item
            return true
        } else {
            return false
        }
    }
    
    func immutableView() -> PostboxView {
        return StoryView(self)
    }
}

public final class StoryView: PostboxView {
    public let item: CodableEntry?
    
    init(_ view: MutableStoryView) {
        self.item = view.item
    }
}
