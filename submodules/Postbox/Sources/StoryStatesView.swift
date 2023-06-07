import Foundation

public enum PostboxStoryStatesKey: Hashable {
    case local
    case subscriptions(PostboxStorySubscriptionsKey)
    case peer(PeerId)
}

private extension PostboxStoryStatesKey {
    init(tableKey: StoryStatesTable.Key) {
        switch tableKey {
        case .local:
            self = .local
        case let .subscriptions(key):
            self = .subscriptions(key)
        case let .peer(peerId):
            self = .peer(peerId)
        }
    }
    
    var tableKey: StoryStatesTable.Key {
        switch self {
        case .local:
            return .local
        case let .subscriptions(key):
            return .subscriptions(key)
        case let .peer(peerId):
            return .peer(peerId)
        }
    }
}

final class MutableStoryStatesView: MutablePostboxView {
    let key: PostboxStoryStatesKey
    var value: CodableEntry?

    init(postbox: PostboxImpl, key: PostboxStoryStatesKey) {
        self.key = key
        self.value = postbox.storyStatesTable.get(key: key.tableKey)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        if !transaction.storyStatesEvents.isEmpty {
            let tableKey = self.key.tableKey
            loop: for event in transaction.storyStatesEvents {
                switch event {
                case .set(tableKey):
                    let value = postbox.storyStatesTable.get(key: self.key.tableKey)
                    if value != self.value {
                        self.value = value
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
        let value = postbox.storyStatesTable.get(key: self.key.tableKey)
        if value != self.value {
            self.value = value
            return true
        }
        return false
    }
    
    func immutableView() -> PostboxView {
        return StoryStatesView(self)
    }
}

public final class StoryStatesView: PostboxView {
    public let value: CodableEntry?
    
    init(_ view: MutableStoryStatesView) {
        self.value = view.value
    }
}
