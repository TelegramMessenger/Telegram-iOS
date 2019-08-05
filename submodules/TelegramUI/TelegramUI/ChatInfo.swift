import Foundation
import Postbox
import TelegramCore
import Display
import AccountContext

func peerSharedMediaController(context: AccountContext, peerId: PeerId) -> ViewController? {
    return PeerMediaCollectionController(context: context, peerId: peerId)
}
