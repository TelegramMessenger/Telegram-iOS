import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public enum TogglePeerChatPinnedResult {
    case done
    case limitExceeded
}

public func togglePeerChatPinned(postbox: Postbox, peerId: PeerId) -> Signal<TogglePeerChatPinnedResult, NoError> {
    return postbox.modify { modifier -> TogglePeerChatPinnedResult in
        var peerIds = modifier.getPinnedPeerIds()
        let sameKind = peerIds.filter { ($0.namespace == Namespaces.Peer.SecretChat) == (peerId.namespace == Namespaces.Peer.SecretChat) && $0 != peerId }
        
        if sameKind.count + 1 > 5 {
            return .limitExceeded
        } else {
            if let index = peerIds.index(of: peerId) {
                peerIds.remove(at: index)
            } else {
                peerIds.insert(peerId, at: 0)
            }
            modifier.setPinnedPeerIds(peerIds)
            addSynchronizePinnedChatsOperation(modifier: modifier)
            return .done
        }
    }
}
