import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

private final class ManagedChatListHolesState {
    private var currentHole: (ChatListHolesEntry, Disposable)?
    
    func clearDisposables() -> [Disposable] {
        if let (_, disposable) = self.currentHole {
            self.currentHole = nil
            return [disposable]
        } else {
            return []
        }
    }
    
    func update(entries: [ChatListHolesEntry]) -> (removed: [Disposable], added: [ChatListHolesEntry: MetaDisposable]) {
        var removed: [Disposable] = []
        var added: [ChatListHolesEntry: MetaDisposable] = [:]
        
        if let (entry, disposable) = self.currentHole {
            if !entries.contains(entry) {
                removed.append(disposable)
                self.currentHole = nil
            }
        }
        
        if self.currentHole == nil, let entry = entries.first {
            let disposable = MetaDisposable()
            self.currentHole = (entry, disposable)
            added[entry] = disposable
        }
        
        return (removed, added)
    }
}

func managedChatListHoles(network: Network, postbox: Postbox, accountPeerId: PeerId) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedChatListHolesState())
        
        let topRootHoleKey: PostboxViewKey = .allChatListHoles(.root)
        let topArchiveHoleKey: PostboxViewKey = .allChatListHoles(Namespaces.PeerGroup.archive)
        let filtersKey: PostboxViewKey = .preferences(keys: Set([PreferencesKeys.chatListFilters]))
        let combinedView = postbox.combinedView(keys: [topRootHoleKey, topArchiveHoleKey, filtersKey])
        
        let disposable = combineLatest(postbox.chatListHolesView(), combinedView).start(next: { view, combinedView in
            var entries = Array(view.entries).sorted(by: { lhs, rhs in
                return lhs.hole.index > rhs.hole.index
            })
            
            if let preferencesView = combinedView.views[filtersKey] as? PreferencesView, let filtersState = preferencesView.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self), !filtersState.filters.isEmpty {
                if let topRootHole = combinedView.views[topRootHoleKey] as? AllChatListHolesView, let hole = topRootHole.latestHole {
                    let entry = ChatListHolesEntry(groupId: .root, hole: hole)
                    if !entries.contains(entry) {
                        entries.append(entry)
                    }
                }
                if let topArchiveHole = combinedView.views[topArchiveHoleKey] as? AllChatListHolesView, let hole = topArchiveHole.latestHole {
                    if !view.entries.contains(ChatListHolesEntry(groupId: Namespaces.PeerGroup.archive, hole: hole)) {
                        let entry = ChatListHolesEntry(groupId: Namespaces.PeerGroup.archive, hole: hole)
                        if !entries.contains(entry) {
                            entries.append(entry)
                        }
                    }
                }
            }
            
            let (removed, added) = state.with { state in
                return state.update(entries: entries)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                disposable.set(fetchChatListHole(postbox: postbox, network: network, accountPeerId: accountPeerId, groupId: entry.groupId, hole: entry.hole).start())
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
