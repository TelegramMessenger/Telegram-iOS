import Foundation
import Postbox
import SwiftSignalKit


func _internal_checkPeerChatServiceActions(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Void in
        transaction.applyMarkUnread(peerId: peerId, namespace: Namespaces.Message.SecretIncoming, value: false, interactive: true)
        
        if peerId.namespace == Namespaces.Peer.SecretChat {
            if let state = transaction.getPeerChatState(peerId) as? SecretChatState {
                let updatedState = secretChatCheckLayerNegotiationIfNeeded(transaction: transaction, peerId: peerId, state: state)
                if state != updatedState {
                    transaction.setPeerChatState(peerId, state: updatedState)
                }
            }
        }
    }
}
