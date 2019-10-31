import PostboxDataTypes
import PostboxCoding

public enum TelegramChannelInfo: Int32 {
    case broadcast = 0
    case group = 1
}

public final class TelegramChannel: Peer {
    public let id: PeerId
    public let username: String?
    public let info: TelegramChannelInfo
    
    public let associatedPeerId: PeerId? = nil
    public let notificationSettingsPeerId: PeerId? = nil
    
    public init(decoder: PostboxDecoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i", orElse: 0))
        self.username = decoder.decodeOptionalStringForKey("un")
        self.info = TelegramChannelInfo(rawValue: decoder.decodeInt32ForKey("i.t", orElse: 0)) ?? .broadcast
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        preconditionFailure()
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        guard let other = other as? TelegramChannel else {
            return false
        }
        
        if self.username != other.username {
            return false
        }
        
        return true
    }
}
