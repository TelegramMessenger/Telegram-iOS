import Foundation
import AsyncDisplayKit
import Display
import Postbox

final class TelegramHashtag {
    let peerName: String?
    let hashtag: String
    
    init(peerName: String?, hashtag: String) {
        self.peerName = peerName
        self.hashtag = hashtag
    }
}

final class TelegramPeerMention {
    let peerId: PeerId
    let mention: String
    
    init(peerId: PeerId, mention: String) {
        self.peerId = peerId
        self.mention = mention
    }
}

struct TelegramTextAttributes {
    static let Url = "UrlAttributeT"
    static let PeerMention = "TelegramPeerMention"
    static let PeerTextMention = "TelegramPeerTextMention"
    static let BotCommand = "TelegramBotCommand"
    static let Hashtag = "TelegramHashtag"
}
