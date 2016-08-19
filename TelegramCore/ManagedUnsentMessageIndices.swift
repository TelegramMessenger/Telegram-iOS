import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedUnsentMessageIndicesState {
    private var sendDisposables: [MessageIndex: Disposable] = [:]
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.sendDisposables.values)
        self.sendDisposables.removeAll()
        return disposables
    }
    
    func update(entries: Set<MessageIndex>) -> (removed: [Disposable], added: [MessageIndex: MetaDisposable]) {
        var removed: [Disposable] = []
        var added: [MessageIndex: MetaDisposable] = [:]
        
        for (entry, disposable) in self.sendDisposables {
            if !entries.contains(entry) {
                removed.append(disposable)
                self.sendDisposables.removeValue(forKey: entry)
            }
        }
        
        for entry in entries {
            if self.sendDisposables[entry] == nil {
                let disposable = MetaDisposable()
                self.sendDisposables[entry] = disposable
                added[entry] = disposable
            }
        }
        
        return (removed, added)
    }
}

func managedUnsentMessageIndices(network: Network, postbox: Postbox, stateManager: StateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedUnsentMessageIndicesState())
        
        let disposable = postbox.unsentMessageIndicesView().start(next: { view in
            let (removed, added) = state.with { state -> (removed: [Disposable], added: [MessageIndex: MetaDisposable]) in
                return state.update(entries: view.indices)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (index, disposable) in added {
                let sendMessage = postbox.messageAtId(index.id)
                    |> filter { $0 != nil }
                    |> take(1)
                    |> mapToSignal { message -> Signal<Void, NoError> in
                        return sendUnsentMessage(network: network, postbox: postbox, stateManager: stateManager, message: message!)
                    }
                disposable.set(sendMessage.start())
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
