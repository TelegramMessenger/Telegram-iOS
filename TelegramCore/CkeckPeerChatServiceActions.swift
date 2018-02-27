import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func checkPeerChatServiceActions(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
                let updatedState = secretChatCheckLayerNegotiationIfNeeded(modifier: modifier, peerId: peerId, state: state)
                if state != updatedState {
                    modifier.setPeerChatState(peerId, state: updatedState)
                }
            }
        }
    }
}
