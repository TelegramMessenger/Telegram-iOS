import Foundation

public class PeerNotificationSettingsDecodeHelper {
    public let decode: (_ data: Data) -> PeerNotificationSettings?

    public init(decode: @escaping (_ data: Data) -> PeerNotificationSettings?) {
        self.decode = decode
    }
}

public enum PeerNotificationSettingsBehavior {
    enum CodingKeys: String, CodingKey {
        case _case = "_v"
        case toValue
        case atTimestamp
    }

    case none
    case reset(atTimestamp: Int32, toValue: PeerNotificationSettings)
    
    public init(from decoder: Decoder, helper: PeerNotificationSettingsDecodeHelper) throws {
        let container = try decoder.container(keyedBy: StringCodingKey.self)

        switch decoder.decodeInt32ForKey("_v", orElse: 0) {
            case 0:
                self = .none
            case 1:
                if let toValue = helper.decode(PeerNotificationSettings.self, forKey: "toValue") {
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
                encoder.encode(toValue, forKey: "toValue")
        }
    }
}

public protocol PeerNotificationSettings: Codable {
    func isRemovedFromTotalUnreadCount(`default`: Bool) -> Bool

    var behavior: PeerNotificationSettingsBehavior { get }
}

public final class PostboxGlobalNotificationSettings {
    public let defaultIncludePeer: (_ peer: Peer) -> Bool

    public init(
        defaultIncludePeer: @escaping (_ peer: Peer) -> Bool
    ) {
        self.defaultIncludePeer = defaultIncludePeer
    }
}

public func resolvedIsRemovedFromTotalUnreadCount(globalSettings: PostboxGlobalNotificationSettings, peer: Peer, peerSettings: PeerNotificationSettings?) -> Bool {
    let defaultValue = !globalSettings.defaultIncludePeer(peer)
    if let peerSettings = peerSettings {
        return peerSettings.isRemovedFromTotalUnreadCount(default: defaultValue)
    } else {
        return defaultValue
    }
}
