import Foundation
import Postbox
import SwiftSignalKit

func managedServiceViews(accountPeerId: PeerId, network: Network, postbox: Postbox, stateManager: AccountStateManager, pendingMessageManager: PendingMessageManager, pendingReferences: PendingMessageReferences, supportContext: SupportContext?, supplementary: Bool) -> (resetPeerHoles: (PeerId) -> Void, disposable: Disposable) {
    let disposable = DisposableSet()
    
    let managedHoles = managedMessageHistoryHoles(accountPeerId: accountPeerId, network: network, postbox: postbox, pendingReferences: pendingReferences)
    
    disposable.add(managedHoles.1)
    disposable.add(managedChatListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId, supportContext: supportContext).start())
    disposable.add(managedForumTopicListHoles(network: network, postbox: postbox, accountPeerId: accountPeerId).start())
    if let supportContext, !supplementary {
        disposable.add(managedSupportChatListCleanup(postbox: postbox, accountPeerId: accountPeerId, supportContext: supportContext).start())
        disposable.add(managedSupportHiddenChatSweep(postbox: postbox, accountPeerId: accountPeerId).start())
        disposable.add(managedSupportDeletedUserSweep(postbox: postbox, accountPeerId: accountPeerId).start())
        disposable.add(managedSupportFolderChats(postbox: postbox, network: network, accountPeerId: accountPeerId).start())
    }
    
    disposable.add((_internal_refreshSeenStories(postbox: postbox, network: network) |> then(.complete() |> suspendAwareDelay(5 * 60 * 60, queue: .mainQueue())) |> restart).start())
    
    return (managedHoles.0, disposable)
}
