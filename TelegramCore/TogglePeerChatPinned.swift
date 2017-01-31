import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func togglePeerChatPinned(postbox: Postbox, peerId: PeerId) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        var peerIds = modifier.getPinnedPeerIds()
        if let index = peerIds.index(of: peerId) {
            peerIds.remove(at: index)
        } else {
            peerIds.insert(peerId, at: 0)
        }
        modifier.setPinnedPeerIds(peerIds)
        addSynchronizePinnedChatsOperation(modifier: modifier)
    }
}
