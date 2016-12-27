import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func managedServiceViews(network: Network, postbox: Postbox, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let disposable = DisposableSet()
        disposable.add(managedMessageHistoryHoles(network: network, postbox: postbox).start())
        disposable.add(managedChatListHoles(network: network, postbox: postbox).start())
        disposable.add(managedSynchronizePeerReadStates(network: network, postbox: postbox, stateManager: stateManager).start())
        
        let pendingMessagesDisposable = postbox.unsentMessageIdsView().start(next: { view in
            pendingMessageManager.updatePendingMessageIds(view.ids)
        })
        disposable.add(ActionDisposable(action: {
            pendingMessagesDisposable.dispose()
            pendingMessageManager.updatePendingMessageIds(Set())
        }))
        
        return disposable
    }
}
