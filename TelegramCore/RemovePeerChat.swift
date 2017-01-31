import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func removePeerChat(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        if peerId.namespace == Namespaces.Peer.SecretChat {
            
        } else {
            cloudChatAddRemoveChatOperation(modifier: modifier, peerId: peerId)
            if peerId.namespace == Namespaces.Peer.CloudUser {
                modifier.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessages)
                modifier.clearHistory(peerId)
            } else {
                modifier.updatePeerChatListInclusion(peerId, inclusion: .never)
            }
        }
    }
}
