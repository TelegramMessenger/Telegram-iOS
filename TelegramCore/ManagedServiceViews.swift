import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

func managedServiceViews(accountPeerId: PeerId, network: Network, postbox: Postbox, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let disposable = DisposableSet()
        disposable.add(managedMessageHistoryHoles(accountPeerId: accountPeerId, network: network, postbox: postbox).start())
        disposable.add(managedChatListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId).start())
        disposable.add(managedSynchronizePeerReadStates(network: network, postbox: postbox, stateManager: stateManager).start())
        //disposable.add(managedGroupFeedReadStateSyncOperations(postbox: postbox, network: network, accountPeerId: accountPeerId, stateManager: stateManager).start())
        
        return disposable
    }
}
