import Foundation
import Postbox
import TelegramCore
import SyncCore
import Display
import AccountContext

func peerSharedMediaControllerImpl(context: AccountContext, peerId: PeerId) -> ViewController? {
    return PeerMediaCollectionController(context: context, peerId: peerId)
}
