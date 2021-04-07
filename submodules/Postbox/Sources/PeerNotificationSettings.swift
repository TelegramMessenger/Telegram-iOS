
public enum PeerNotificationSettingsBehavior: PostboxCoding {
    case none
    case reset(atTimestamp: Int32, toValue: PeerNotificationSettings)
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .none
            case 1:
                if let toValue = decoder.decodeObjectForKey("toValue") as? PeerNotificationSettings {
                    self = .reset(atTimestamp: decoder.decodeInt32ForKey("atTimestamp", orElse: 0), toValue: toValue)
                } else {
                    assertionFailure()
                    self = .none
                }
            default:
                assertionFailure()
                self = .none
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "_v")
            case let .reset(atTimestamp, toValue):
                encoder.encodeInt32(1, forKey: "_v")
                encoder.encodeInt32(atTimestamp, forKey: "atTimestamp")
                encoder.encodeObject(toValue, forKey: "toValue")
        }
    }
}

public protocol PeerNotificationSettings: PostboxCoding {
    func isRemovedFromTotalUnreadCount(`default`: Bool) -> Bool
    var behavior: PeerNotificationSettingsBehavior { get }
    
    func isEqual(to: PeerNotificationSettings) -> Bool
}

public protocol PostboxGlobalNotificationSettings: PostboxCoding {
    func defaultIncludePeer(peer: Peer) -> Bool
    
    func isEqualInDefaultPeerInclusion(other: PostboxGlobalNotificationSettings) -> Bool
}

public func resolvedIsRemovedFromTotalUnreadCount(globalSettings: PostboxGlobalNotificationSettings, peer: Peer, peerSettings: PeerNotificationSettings?) -> Bool {
    let defaultValue = !globalSettings.defaultIncludePeer(peer: peer)
    if let peerSettings = peerSettings {
        return peerSettings.isRemovedFromTotalUnreadCount(default: defaultValue)
    } else {
        return defaultValue
    }
}
