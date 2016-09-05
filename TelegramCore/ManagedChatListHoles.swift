import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

private final class ManagedChatListHolesState {
    private var holeDisposables: [ChatListHole: Disposable] = [:]
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.holeDisposables.values)
        self.holeDisposables.removeAll()
        return disposables
    }
    
    func update(entries: Set<ChatListHole>) -> (removed: [Disposable], added: [ChatListHole: MetaDisposable]) {
        var removed: [Disposable] = []
        var added: [ChatListHole: MetaDisposable] = [:]
        
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
        
        return (removed, added)
    }
}

func managedChatListHoles(network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedChatListHolesState())
        
        let disposable = postbox.chatListHolesView().start(next: { view in
            let (removed, added) = state.with { state -> (removed: [Disposable], added: [ChatListHole: MetaDisposable]) in
                return state.update(entries: view.entries)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                disposable.set(fetchChatListHole(network: network, postbox: postbox, hole: entry).start())
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
