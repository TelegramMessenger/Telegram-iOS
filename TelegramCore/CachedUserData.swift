import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public final class CachedUserData: CachedPeerData {
    public let about: String?
    public let botInfo: BotInfo?
    
    public let peerIds = Set<PeerId>()
    
    init(about: String?, botInfo: BotInfo?) {
        self.about = about
        self.botInfo = botInfo
    }
    
    public init(decoder: Decoder) {
        self.about = decoder.decodeStringForKey("a")
        self.botInfo = decoder.decodeObjectForKey("bi") as? BotInfo
    }
    
    public func encode(_ encoder: Encoder) {
        if let about = self.about {
            encoder.encodeString(about, forKey: "a")
        } else {
            encoder.encodeNil(forKey: "a")
        }
        if let botInfo = self.botInfo {
            encoder.encodeObject(botInfo, forKey: "bi")
        } else {
            encoder.encodeNil(forKey: "bi")
        }
    }
    
    public func isEqual(to: CachedPeerData) -> Bool {
        guard let other = to as? CachedUserData else {
            return false
        }
        
        return other.about == self.about && other.botInfo == self.botInfo
    }
}

extension CachedUserData {
    convenience init(apiUserFull: Api.UserFull) {
        switch apiUserFull {
            case let .userFull(_, _, about, _, _, _, apiBotInfo, commonChatsCount):
                let botInfo: BotInfo?
                if let apiBotInfo = apiBotInfo {
                    botInfo = BotInfo(apiBotInfo: apiBotInfo)
                } else {
                    botInfo = nil
                }
                self.init(about: about, botInfo: botInfo)
        }
    }
}
