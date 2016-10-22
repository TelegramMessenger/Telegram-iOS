import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func managedServiceViews(network: Network, postbox: Postbox, stateManager: StateManager, pendingMessageManager: PendingMessageManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let disposable = DisposableSet()
        disposable.add(managedMessageHistoryHoles(network: network, postbox: postbox).start())
        disposable.add(managedChatListHoles(network: network, postbox: postbox).start())
        //disposable.add(managedUnsentMessageIndices(network: network, postbox: postbox, stateManager: stateManager).start())
        disposable.add(managedSynchronizePeerReadStates(network: network, postbox: postbox, stateManager: stateManager).start())
        
        let pendingMessagesDisposable = postbox.unsentMessageIndicesView().start(next: { view in
            pendingMessageManager.updatePendingMessageIndices(view.indices)
        })
        disposable.add(ActionDisposable(action: {
            pendingMessagesDisposable.dispose()
            pendingMessageManager.updatePendingMessageIndices(Set())
        }))
        
        return disposable
    }
}
