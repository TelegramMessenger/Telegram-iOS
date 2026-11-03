import Foundation
import TelegramCore

public final class TelegramHashtag {
    public let peerName: String?
    public let hashtag: String
    
    public init(peerName: String?, hashtag: String) {
        self.peerName = peerName
        self.hashtag = hashtag
    }
}

public final class TelegramPeerMention {
    public let peerId: EnginePeer.Id
    public let mention: String
    
    public init(peerId: EnginePeer.Id, mention: String) {
        self.peerId = peerId
        self.mention = mention
    }
}

public final class TelegramTimecode {
    public let time: Double
    public let text: String
    
    public init(time: Double, text: String) {
        self.time = time
        self.text = text
    }
}

public final class TelegramTonAddress {
    public let address: String
    public let range: NSRange

    public init(address: String, range: NSRange) {
        self.address = address
        self.range = range
    }
}

public struct TelegramTextAttributes {
    public static let URL = "UrlAttributeT"
    public static let PeerMention = "TelegramPeerMention"
    public static let PeerTextMention = "TelegramPeerTextMention"
    public static let BotCommand = "TelegramBotCommand"
    public static let Hashtag = "TelegramHashtag"
    public static let BankCard = "TelegramBankCard"
    public static let TonAddress = "TelegramTonAddress"
    public static let Timecode = "TelegramTimecode"
    public static let BlockQuote = "TelegramBlockQuote"
    public static let Pre = "TelegramPre"
    public static let Spoiler = "TelegramSpoiler"
    public static let Code = "TelegramCode"
    public static let Button = "TelegramButton"
    public static let Date = "TelegramDate"
}
