import Foundation
import Postbox
import SwiftSignalKit

import SyncCore

public func updatePeerChatInterfaceState(account: Account, peerId: PeerId, state: SynchronizeableChatInterfaceState) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        let currentInputState = (transaction.getPeerChatInterfaceState(peerId) as? SynchronizeableChatInterfaceState)?.synchronizeableInputState
        let updatedInputState = state.synchronizeableInputState
        
        if currentInputState != updatedInputState {
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                addSynchronizeChatInputStateOperation(transaction: transaction, peerId: peerId)
            }
        }
        transaction.updatePeerChatInterfaceState(peerId, update: { _ in
            return state
        })
    }
}
