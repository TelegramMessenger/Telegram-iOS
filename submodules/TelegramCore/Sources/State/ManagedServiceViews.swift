import Foundation
import Postbox
import SwiftSignalKit

func managedServiceViews(accountPeerId: PeerId, network: Network, postbox: Postbox, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager) -> Signal<Void, NoError> {
    return Signal { _ in
        let disposable = DisposableSet()
        disposable.add(managedMessageHistoryHoles(accountPeerId: accountPeerId, network: network, postbox: postbox).start())
        disposable.add(managedChatListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId).start())
        disposable.add(managedSynchronizePeerReadStates(network: network, postbox: postbox, stateManager: stateManager).start())
        disposable.add(managedSynchronizeGroupMessageStats(network: network, postbox: postbox, stateManager: stateManager).start())
        
        return disposable
    }
}
