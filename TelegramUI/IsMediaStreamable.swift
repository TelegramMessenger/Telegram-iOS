import Foundation
import Postbox
import TelegramCore

func isMediaStreamable(message: Message, media: TelegramMediaFile) -> Bool {
    if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
        return false
    }
    if media.isVideo && !media.isAnimated {
        return true
    }
    return false
}
