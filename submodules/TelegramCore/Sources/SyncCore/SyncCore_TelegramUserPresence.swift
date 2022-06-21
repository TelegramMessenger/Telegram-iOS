import Postbox

public enum UserPresenceStatus: Comparable, PostboxCoding {
    case none
    case present(until: Int32)
    case recently
    case lastWeek
    case lastMonth
    
    public static func <(lhs: UserPresenceStatus, rhs: UserPresenceStatus) -> Bool {
        switch lhs {
            case .none:
                switch rhs {
                    case .none:
                        return false
                    case .lastMonth, .lastWeek, .recently, .present:
                        return true
                }
            case let .present(until):
                switch rhs {
                    case .none:
                        return false
                    case let .present(rhsUntil):
                        return until < rhsUntil
                    case .lastWeek, .lastMonth, .recently:
                        return false
                }
            case .recently:
                switch rhs {
                    case .none, .lastWeek, .lastMonth, .recently:
                        return false
                    case .present:
                        return true
                }
            case .lastWeek:
                switch rhs {
                    case .none, .lastMonth, .lastWeek:
                        return false
                    case .present, .recently:
                        return true
                }
            case .lastMonth:
                switch rhs {
                    case .none, .lastMonth:
                        return false
                    case .present, .recently, lastWeek:
                        return true
                }
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("v", orElse: 0) {
            case 0:
                self = .none
            case 1:
                self = .present(until: decoder.decodeInt32ForKey("t", orElse: 0))
            case 2:
                self = .recently
            case 3:
                self = .lastWeek
            case 4:
                self = .lastMonth
            default:
                self = .none
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(0, forKey: "v")
            case let .present(timestamp):
                encoder.encodeInt32(1, forKey: "v")
                encoder.encodeInt32(timestamp, forKey: "t")
            case .recently:
                encoder.encodeInt32(2, forKey: "v")
            case .lastWeek:
                encoder.encodeInt32(3, forKey: "v")
            case .lastMonth:
                encoder.encodeInt32(4, forKey: "v")
        }
    }
}

public final class TelegramUserPresence: PeerPresence, Equatable {
    public let status: UserPresenceStatus
    public let lastActivity: Int32
    
    public init(status: UserPresenceStatus, lastActivity: Int32) {
        self.status = status
        self.lastActivity = lastActivity
    }
    
    public init(decoder: PostboxDecoder) {
        self.status = UserPresenceStatus(decoder: decoder)
        self.lastActivity = decoder.decodeInt32ForKey("la", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        self.status.encode(encoder)
        encoder.encodeInt32(self.lastActivity, forKey: "la")
    }
    
    public static func ==(lhs: TelegramUserPresence, rhs: TelegramUserPresence) -> Bool {
        return lhs.status == rhs.status && lhs.lastActivity == rhs.lastActivity
    }
    
    public func isEqual(to: PeerPresence) -> Bool {
        if let to = to as? TelegramUserPresence {
            return self == to
        } else {
            return false
        }
    }
}
