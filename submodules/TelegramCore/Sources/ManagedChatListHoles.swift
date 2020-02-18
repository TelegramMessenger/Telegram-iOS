import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedChatListHolesState {
    private var holeDisposables: [ChatListHolesEntry: Disposable] = [:]
    private var additionalLatestHoleDisposable: (ChatListHole, Disposable)?
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.holeDisposables.values)
        self.holeDisposables.removeAll()
        return disposables
    }
    
    func update(entries: Set<ChatListHolesEntry>, additionalLatestHole: ChatListHole?) -> (removed: [Disposable], added: [ChatListHolesEntry: MetaDisposable], addedAdditionalLatestHole: (ChatListHole, MetaDisposable)?) {
        var removed: [Disposable] = []
        var added: [ChatListHolesEntry: MetaDisposable] = [:]
        
        for (entry, disposable) in self.holeDisposables {
            if !entries.contains(entry) {
                removed.append(disposable)
                self.holeDisposables.removeValue(forKey: entry)
            }
        }
        
        for entry in entries {
            if self.holeDisposables[entry] == nil {
                let disposable = MetaDisposable()
                self.holeDisposables[entry] = disposable
                added[entry] = disposable
            }
        }
        
        var addedAdditionalLatestHole: (ChatListHole, MetaDisposable)?
        if self.holeDisposables.isEmpty {
            if self.additionalLatestHoleDisposable?.0 != additionalLatestHole {
                if let (_, disposable) = self.additionalLatestHoleDisposable {
                    removed.append(disposable)
                }
                if let additionalLatestHole = additionalLatestHole {
                    let disposable = MetaDisposable()
                    self.additionalLatestHoleDisposable = (additionalLatestHole, disposable)
                    addedAdditionalLatestHole = (additionalLatestHole, disposable)
                }
            }
        }
        
        return (removed, added, addedAdditionalLatestHole)
    }
}

func managedChatListHoles(network: Network, postbox: Postbox, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedChatListHolesState())
        
        let topRootHoleKey = PostboxViewKey.allChatListHoles(.root)
        let topRootHole = postbox.combinedView(keys: [topRootHoleKey])
        
        let disposable = combineLatest(postbox.chatListHolesView(), topRootHole).start(next: { view, topRootHoleView in
            var additionalLatestHole: ChatListHole?
            if let topRootHole = topRootHoleView.views[topRootHoleKey] as? AllChatListHolesView {
                #if os(macOS)
                additionalLatestHole = topRootHole.latestHole
                #endif
            }
            
            let (removed, added, addedAdditionalLatestHole) = state.with { state in
                return state.update(entries: view.entries, additionalLatestHole: additionalLatestHole)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                disposable.set(fetchChatListHole(postbox: postbox, network: network, accountPeerId: accountPeerId, groupId: entry.groupId, hole: entry.hole).start())
            }
            
            if let (hole, disposable) = addedAdditionalLatestHole {
                disposable.set(fetchChatListHole(postbox: postbox, network: network, accountPeerId: accountPeerId, groupId: .root, hole: hole).start())
            }
        })
        
        return ActionDisposable {
            disposable.dispose()
            for disposable in state.with({ state -> [Disposable] in
                state.clearDisposables()
            }) {
                disposable.dispose()
            }
        }
    }
}
