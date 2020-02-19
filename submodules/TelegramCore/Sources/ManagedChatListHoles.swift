import Foundation
import Postbox
import SwiftSignalKit
import SyncCore

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
        
        let topRootHoleKey: PostboxViewKey = .allChatListHoles(.root)
        let filtersKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.chatListFilters]))
        let combinedView = postbox.combinedView(keys: [topRootHoleKey, filtersKey])
        
        let disposable = combineLatest(postbox.chatListHolesView(), combinedView).start(next: { view, combinedView in
            var additionalLatestHole: ChatListHole?
            
            if let preferencesView = combinedView.views[filtersKey] as? PreferencesView, let filtersState = preferencesView.values[PreferencesKeys.chatListFilters] as? ChatListFiltersState, !filtersState.filters.isEmpty {
                if let topRootHole = combinedView.views[topRootHoleKey] as? AllChatListHolesView {
                    additionalLatestHole = topRootHole.latestHole
                }
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
