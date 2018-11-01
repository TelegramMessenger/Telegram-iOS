import Foundation
import Postbox
import TelegramCore

func isMediaStreamable(message: Message, media: TelegramMediaFile) -> Bool {
    if message.containsSecretMedia {
        return false
    }
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    if media.isVideo && !media.isAnimated {
        return true
    }
    guard let size = media.size else {
        return false
    }
    if size < 500 * 1024 {
        return false
    }
    return false
}
