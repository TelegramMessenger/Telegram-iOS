import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedMessageHistoryHolesState {
    private var holeDisposables: [MessageHistoryHolesViewEntry: Disposable] = [:]
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.holeDisposables.values)
        self.holeDisposables.removeAll()
        return disposables
    }
    
    func update(entries: Set<MessageHistoryHolesViewEntry>) -> (removed: [Disposable], added: [MessageHistoryHolesViewEntry: MetaDisposable]) {
        var removed: [Disposable] = []
        var added: [MessageHistoryHolesViewEntry: MetaDisposable] = [:]
        
        for (entry, disposable) in self.holeDisposables {
            if !entries.contains(entry) {
                removed.append(disposable)
                self.holeDisposables.removeValue(forKey: entry)
            }
        }
        
        for entry in entries {
            switch entry.hole {
            case .peer:
                if self.holeDisposables[entry] == nil {
                    let disposable = MetaDisposable()
                    self.holeDisposables[entry] = disposable
                    added[entry] = disposable
                }
            }
        }
        
        return (removed, added)
    }
}

func managedMessageHistoryHoles(accountPeerId: PeerId, network: Network, postbox: Postbox) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedMessageHistoryHolesState())
        
        let disposable = postbox.messageHistoryHolesView().start(next: { view in
            let (removed, added) = state.with { state -> (removed: [Disposable], added: [MessageHistoryHolesViewEntry: MetaDisposable]) in
                return state.update(entries: view.entries)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (entry, disposable) in added {
                switch entry.hole {
                case let .peer(hole):
                    disposable.set(fetchMessageHistoryHole(accountPeerId: accountPeerId, source: .network(network), postbox: postbox, peerInput: .direct(peerId: hole.peerId, threadId: hole.threadId), namespace: hole.namespace, direction: entry.direction, space: entry.space, count: entry.count).start())
                }
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
