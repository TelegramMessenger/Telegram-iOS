import Foundation
import Postbox
import SwiftSignalKit

func managedServiceViews(accountPeerId: PeerId, network: Network, postbox: Postbox, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager) -> (resetPeerHoles: (PeerId) -> Void, disposable: Disposable) {
    let disposable = DisposableSet()
    
    let managedHoles = managedMessageHistoryHoles(accountPeerId: accountPeerId, network: network, postbox: postbox)
    
    disposable.add(managedHoles.1)
    disposable.add(managedChatListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId).start())
    disposable.add(managedForumTopicListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId).start())
    
    return (managedHoles.0, disposable)
}
