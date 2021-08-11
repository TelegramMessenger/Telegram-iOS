import Postbox

public enum PeerMuteState: Equatable {
    case `default`
    case unmuted
    case muted(until: Int32)
    
    fileprivate static func decodeInline(_ decoder: PostboxDecoder) -> PeerMuteState {
        switch decoder.decodeInt32ForKey("m.v", orElse: 0) {
            case 0:
                return .default
            case 1:
                return .muted(until: decoder.decodeInt32ForKey("m.u", orElse: 0))
            case 2:
                return .unmuted
            default:
                return .default
        }
    }
    
    fileprivate func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .default:
                encoder.encodeInt32(0, forKey: "m.v")
            case let .muted(until):
                encoder.encodeInt32(1, forKey: "m.v")
                encoder.encodeInt32(until, forKey: "m.u")
            case .unmuted:
                encoder.encodeInt32(2, forKey: "m.v")
        }
    }
}

private enum PeerMessageSoundValue: Int32 {
    case none
    case bundledModern
    case bundledClassic
    case `default`
}

public enum PeerMessageSound: Equatable {
    case none
    case `default`
    case bundledModern(id: Int32)
    case bundledClassic(id: Int32)
    
    static func decodeInline(_ decoder: PostboxDecoder) -> PeerMessageSound {
        switch decoder.decodeInt32ForKey("s.v", orElse: 0) {
            case PeerMessageSoundValue.none.rawValue:
                return .none
            case PeerMessageSoundValue.bundledModern.rawValue:
                return .bundledModern(id: decoder.decodeInt32ForKey("s.i", orElse: 0))
            case PeerMessageSoundValue.bundledClassic.rawValue:
                return .bundledClassic(id: decoder.decodeInt32ForKey("s.i", orElse: 0))
            case PeerMessageSoundValue.default.rawValue:
                return .default
            default:
                assertionFailure()
                return .bundledModern(id: 0)
        }
    }
    
    func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .none:
                encoder.encodeInt32(PeerMessageSoundValue.none.rawValue, forKey: "s.v")
            case let .bundledModern(id):
                encoder.encodeInt32(PeerMessageSoundValue.bundledModern.rawValue, forKey: "s.v")
                encoder.encodeInt32(id, forKey: "s.i")
            case let .bundledClassic(id):
                encoder.encodeInt32(PeerMessageSoundValue.bundledClassic.rawValue, forKey: "s.v")
                encoder.encodeInt32(id, forKey: "s.i")
            case .default:
                encoder.encodeInt32(PeerMessageSoundValue.default.rawValue, forKey: "s.v")
        }
    }
    
    public static func ==(lhs: PeerMessageSound, rhs: PeerMessageSound) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .bundledModern(id):
                if case .bundledModern(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .bundledClassic(id):
                if case .bundledClassic(id) = rhs {
                    return true
                } else {
                    return false
                }
            case .default:
                if case .default = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public enum PeerNotificationDisplayPreviews {
    case `default`
    case show
    case hide
    
    static func decodeInline(_ decoder: PostboxDecoder) -> PeerNotificationDisplayPreviews {
        switch decoder.decodeInt32ForKey("p.v", orElse: 0) {
            case 0:
                return .default
            case 1:
                return .show
            case 2:
                return .hide
            default:
                assertionFailure()
                return .default
        }
    }
    
    func encodeInline(_ encoder: PostboxEncoder) {
        switch self {
            case .default:
                encoder.encodeInt32(0, forKey: "p.v")
            case .show:
                encoder.encodeInt32(1, forKey: "p.v")
            case .hide:
                encoder.encodeInt32(2, forKey: "p.v")
        }
    }
}

public final class TelegramPeerNotificationSettings: PeerNotificationSettings, Equatable {
    public let muteState: PeerMuteState
    public let messageSound: PeerMessageSound
    public let displayPreviews: PeerNotificationDisplayPreviews
    
    public static var defaultSettings: TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: .unmuted, messageSound: .default, displayPreviews: .default)
    }
    
    public func isRemovedFromTotalUnreadCount(`default`: Bool) -> Bool {
        switch self.muteState {
            case .unmuted:
                return false
            case .muted:
                return true
            case .default:
                return `default`
        }
    }
    
    public var behavior: PeerNotificationSettingsBehavior {
        if case let .muted(untilTimestamp) = self.muteState, untilTimestamp < Int32.max {
            return .reset(atTimestamp: untilTimestamp, toValue: self.withUpdatedMuteState(.unmuted))
        } else {
            return .none
        }
    }
    
    public init(muteState: PeerMuteState, messageSound: PeerMessageSound, displayPreviews: PeerNotificationDisplayPreviews) {
        self.muteState = muteState
        self.messageSound = messageSound
        self.displayPreviews = displayPreviews
    }
    
    public init(decoder: PostboxDecoder) {
        self.muteState = PeerMuteState.decodeInline(decoder)
        self.messageSound = PeerMessageSound.decodeInline(decoder)
        self.displayPreviews = PeerNotificationDisplayPreviews.decodeInline(decoder)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        self.muteState.encodeInline(encoder)
        self.messageSound.encodeInline(encoder)
        self.displayPreviews.encodeInline(encoder)
    }
    
    public func isEqual(to: PeerNotificationSettings) -> Bool {
        if let to = to as? TelegramPeerNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public func withUpdatedMuteState(_ muteState: PeerMuteState) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: muteState, messageSound: self.messageSound, displayPreviews: self.displayPreviews)
    }
    
    public func withUpdatedMessageSound(_ messageSound: PeerMessageSound) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: self.muteState, messageSound: messageSound, displayPreviews: self.displayPreviews)
    }
    
    public func withUpdatedDisplayPreviews(_ displayPreviews: PeerNotificationDisplayPreviews) -> TelegramPeerNotificationSettings {
        return TelegramPeerNotificationSettings(muteState: self.muteState, messageSound: self.messageSound, displayPreviews: displayPreviews)
    }
    
    public static func ==(lhs: TelegramPeerNotificationSettings, rhs: TelegramPeerNotificationSettings) -> Bool {
        return lhs.muteState == rhs.muteState && lhs.messageSound == rhs.messageSound && lhs.displayPreviews == rhs.displayPreviews
    }
}
