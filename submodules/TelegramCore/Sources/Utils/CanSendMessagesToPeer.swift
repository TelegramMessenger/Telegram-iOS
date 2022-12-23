import Foundation
import Postbox


// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public func canSendMessagesToPeer(_ peer: Peer) -> Bool {
    if let peer = peer as? TelegramUser, peer.addressName == "replies" {
        return false
    } else if peer is TelegramUser || peer is TelegramGroup {
        return !peer.isDeleted
    } else if let peer = peer as? TelegramSecretChat {
        return peer.embeddedState == .active
    } else if let peer = peer as? TelegramChannel {
        return peer.hasPermission(.sendMessages)
    } else {
        return false
    }
}
