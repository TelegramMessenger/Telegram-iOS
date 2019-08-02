import Foundation
import Postbox
import TelegramCore
import Display

func peerSharedMediaController(context: AccountContextImpl, peerId: PeerId) -> ViewController? {
    return PeerMediaCollectionController(context: context, peerId: peerId)
}
