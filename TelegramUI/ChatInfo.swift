import Foundation
import Postbox
import TelegramCore
import Display

func peerSharedMediaController(account: Account, peerId: PeerId) -> ViewController? {
    return PeerMediaCollectionController(account: account, peerId: peerId)
}
