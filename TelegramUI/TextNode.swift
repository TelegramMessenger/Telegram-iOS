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

final class TelegramTimecode {
    let time: Double
    let text: String
    
    init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

struct TelegramTextAttributes {
    static let URL = "UrlAttributeT"
    static let PeerMention = "TelegramPeerMention"
    static let PeerTextMention = "TelegramPeerTextMention"
    static let BotCommand = "TelegramBotCommand"
    static let Hashtag = "TelegramHashtag"
    static let Timecode = "TelegramTimecode"
}
