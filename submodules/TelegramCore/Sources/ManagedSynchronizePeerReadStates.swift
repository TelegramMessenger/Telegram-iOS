import Foundation
import Postbox
import SwiftSignalKit

private final class ManagedSynchronizePeerReadStatesState {
    private var synchronizeDisposables: [PeerId: (PeerReadStateSynchronizationOperation, Disposable)] = [:]
    
    func clearDisposables() -> [Disposable] {
        let disposables = Array(self.synchronizeDisposables.values.map({ $0.1 }))
        self.synchronizeDisposables.removeAll()
        return disposables
    }
    
    func update(operations: [PeerId: PeerReadStateSynchronizationOperation]) -> (removed: [Disposable], added: [(PeerId, PeerReadStateSynchronizationOperation, MetaDisposable)]) {
        var removed: [Disposable] = []
        var added: [(PeerId, PeerReadStateSynchronizationOperation, MetaDisposable)] = []
        
        for (peerId, (operation, disposable)) in self.synchronizeDisposables {
            if operations[peerId] != operation {
                removed.append(disposable)
                self.synchronizeDisposables.removeValue(forKey: peerId)
            }
        }
        
        for (peerId, operation) in operations {
            if self.synchronizeDisposables[peerId] == nil {
                let disposable = MetaDisposable()
                self.synchronizeDisposables[peerId] = (operation, disposable)
                added.append((peerId, operation, disposable))
            }
        }
        
        return (removed, added)
    }
}

func managedSynchronizePeerReadStates(network: Network, postbox: Postbox, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let state = Atomic(value: ManagedSynchronizePeerReadStatesState())
        
        let disposable = postbox.synchronizePeerReadStatesView().start(next: { view in
            let (removed, added) = state.with { state -> (removed: [Disposable], added: [(PeerId, PeerReadStateSynchronizationOperation, MetaDisposable)]) in
                return state.update(operations: view.operations)
            }
            
            for disposable in removed {
                disposable.dispose()
            }
            
            for (peerId, operation, disposable) in added {
                let synchronizeOperation: Signal<Void, NoError>
                switch operation {
                    case .Validate:
                        synchronizeOperation = synchronizePeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId, push: false, validate: true)
                    case let .Push(_, thenSync):
                        synchronizeOperation = synchronizePeerReadState(network: network, postbox: postbox, stateManager: stateManager, peerId: peerId, push: true, validate: thenSync)
                }
                disposable.set(synchronizeOperation.start())
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
