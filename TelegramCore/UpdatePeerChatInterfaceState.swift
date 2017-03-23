import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func updatePeerChatInterfaceState(account: Account, peerId: PeerId, state: SynchronizeableChatInterfaceState) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Void in
        let currentInputState = (modifier.getPeerChatInterfaceState(peerId) as? SynchronizeableChatInterfaceState)?.synchronizeableInputState
        let updatedInputState = state.synchronizeableInputState
        
        if currentInputState != updatedInputState {
            if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup {
                addSynchronizeChatInputStateOperation(modifier: modifier, peerId: peerId)
            }
        }
        modifier.updatePeerChatInterfaceState(peerId, update: { _ in
            return state
        })
    }
}
