import Foundation

public enum PostboxStoryStatesKey: Hashable {
    case local
    case subscriptions(PostboxStorySubscriptionsKey)
    case peer(PeerId)
}

final class MutableStoryStatesView: MutablePostboxView {
    let key: PostboxStoryStatesKey
    var value: CodableEntry?

    init(postbox: PostboxImpl, key: PostboxStoryStatesKey) {
        self.key = key
        
        let _ = self.refreshDueToExternalTransaction(postbox: postbox)
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool {
        var updated = false
        switch self.key {
        case .local, .subscriptions:
            let storyGeneralKey: StoryGeneralStatesTable.Key
            switch self.key {
            case .local:
                storyGeneralKey = .local
            case let .subscriptions(value):
                storyGeneralKey = .subscriptions(value)
            case .peer:
                assertionFailure()
                return false
            }
            if !transaction.storyGeneralStatesEvents.isEmpty {
                loop: for event in transaction.storyGeneralStatesEvents {
                    switch event {
                    case .set(storyGeneralKey):
                        let value = postbox.storyGeneralStatesTable.get(key: storyGeneralKey)
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
        case let .peer(peerId):
            let storyPeerKey: StoryPeerStatesTable.Key = .peer(peerId)
            if !transaction.storyPeerStatesEvents.isEmpty {
                loop: for event in transaction.storyPeerStatesEvents {
                    switch event {
                    case .set(storyPeerKey):
                        let value = postbox.storyPeerStatesTable.get(key: storyPeerKey)?.entry
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
        }
        
        return updated
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        let value: CodableEntry?
        switch self.key {
        case .local:
            value = postbox.storyGeneralStatesTable.get(key: .local)
        case let .subscriptions(valueKey):
            value = postbox.storyGeneralStatesTable.get(key: .subscriptions(valueKey))
        case let .peer(peerId):
            value = postbox.storyPeerStatesTable.get(key: .peer(peerId))?.entry
        }
        
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
