import Foundation

public protocol PostboxView: AnyObject {
}

protocol MutablePostboxView: AnyObject {
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> Bool
    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool
    func immutableView() -> PostboxView
}

final class CombinedMutableView {
    let views: [PostboxViewKey: MutablePostboxView]
    
    init(views: [PostboxViewKey: MutablePostboxView]) {
        self.views = views
    }
    
    func replay(postbox: PostboxImpl, transaction: PostboxTransaction) -> (updated: Bool, updateTrackedHoles: Bool) {
        var anyUpdated = false
        var updateTrackedHoles = false
        for (_, view) in self.views {
            if let mutableView = view as? MutableMessageHistoryView {
                var innerUpdated = false
                
                let previousPeerIds = mutableView.peerIds
            
                if mutableView.replay(postbox: postbox, transaction: transaction) {
                    innerUpdated = true
                }
                
                var updateType: ViewUpdateType = .Generic
                switch mutableView.peerIds {
                    case let .single(peerId, threadId):
                        for key in transaction.currentPeerHoleOperations.keys {
                            if key.peerId == peerId && key.threadId == threadId {
                                updateType = .FillHole
                                break
                            }
                        }
                    case .associated:
                        var ids = Set<PeerId>()
                        switch mutableView.peerIds {
                            case .single, .external:
                                assertionFailure()
                            case let .associated(mainPeerId, associatedId):
                                ids.insert(mainPeerId)
                                if let associatedId = associatedId {
                                    ids.insert(associatedId.peerId)
                                }
                        }
                        
                        if !ids.isEmpty {
                            for key in transaction.currentPeerHoleOperations.keys {
                                if ids.contains(key.peerId) {
                                    updateType = .FillHole
                                    break
                                }
                            }
                        }
                    case .external:
                        break
                }
                
                mutableView.updatePeerIds(transaction: transaction)
                if mutableView.peerIds != previousPeerIds {
                    updateType = .UpdateVisible
                    
                    let _ = mutableView.refreshDueToExternalTransaction(postbox: postbox)
                    innerUpdated = true
                }
            
                if innerUpdated {
                    anyUpdated = true
                    updateTrackedHoles = true
                    let _ = updateType
                    //pipe.putNext((MessageHistoryView(mutableView), updateType))
                }
            } else if view.replay(postbox: postbox, transaction: transaction) {
                anyUpdated = true
            }
        }
        return (anyUpdated, updateTrackedHoles)
    }

    func refreshDueToExternalTransaction(postbox: PostboxImpl) -> Bool {
        var updated = false
        for (_, view) in self.views {
            if view.refreshDueToExternalTransaction(postbox: postbox) {
                updated = true
            }
        }
        return updated
    }
    
    func immutableView() -> CombinedView {
        var result: [PostboxViewKey: PostboxView] = [:]
        for (key, view) in self.views {
            result[key] = view.immutableView()
        }
        return CombinedView(views: result)
    }
}

public final class CombinedView {
    public let views: [PostboxViewKey: PostboxView]
    
    init(views: [PostboxViewKey: PostboxView]) {
        self.views = views
    }
}
