import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

public enum PeerMuteState: Equatable {
    case unmuted
    case muted(until: Int32)
    
    fileprivate static func decodeInline(_ decoder: Decoder) -> PeerMuteState {
        switch decoder.decodeInt32ForKey("m.v") as Int32 {
            case 0:
                return .unmuted
            case 1:
                return .muted(until: decoder.decodeInt32ForKey("m.u"))
            default:
                return .unmuted
        }
    }
    
    fileprivate func encodeInline(_ encoder: Encoder) {
        switch self {
            case .unmuted:
                encoder.encodeInt32(0, forKey: "m.v")
            case let .muted(until):
                encoder.encodeInt32(1, forKey: "m.v")
                encoder.encodeInt32(until, forKey: "m.u")
        }
    }
    
    public static func ==(lhs: PeerMuteState, rhs: PeerMuteState) -> Bool {
        switch lhs {
            case .unmuted:
                switch rhs {
                    case .unmuted:
                        return true
                    default:
                        return false
                }
            case let .muted(lhsUntil):
                switch rhs {
                    case .muted(lhsUntil):
                        return true
                    default:
                        return false
                }
        }
    }
}

public enum PeerMessageSound: Equatable {
    case appDefault
    case bundled(index: Int32)
    
    fileprivate static func decodeInline(_ decoder: Decoder) -> PeerMessageSound {
        switch decoder.decodeInt32ForKey("s.v") as Int32 {
            case 0:
                return .appDefault
            case 1:
                return .bundled(index: decoder.decodeInt32ForKey("s.i"))
            default:
                return .appDefault
        }
    }
    
    fileprivate func encodeInline(_ encoder: Encoder) {
        switch self {
            case .appDefault:
                encoder.encodeInt32(0, forKey: "s.v")
            case let .bundled(index):
                encoder.encodeInt32(1, forKey: "s.v")
                encoder.encodeInt32(index, forKey: "s.i")
        }
    }
    
    public static func ==(lhs: PeerMessageSound, rhs: PeerMessageSound) -> Bool {
        switch lhs {
            case .appDefault:
                switch rhs {
                    case .appDefault:
                        return true
                    default:
                        return false
                }
            case let .bundled(lhsIndex):
                switch rhs {
                    case .bundled(lhsIndex):
                        return true
                    default:
                        return false
                }
        }
    }
}

public final class TelegramPeerNotificationSettings: PeerNotificationSettings, Equatable {
    public let muteState: PeerMuteState
    public let messageSound: PeerMessageSound
    
    public init(muteState: PeerMuteState, messageSound: PeerMessageSound) {
        self.muteState = muteState
        self.messageSound = messageSound
    }
    
    public init(decoder: Decoder) {
        self.muteState = PeerMuteState.decodeInline(decoder)
        self.messageSound = PeerMessageSound.decodeInline(decoder)
    }
    
    public func encode(_ encoder: Encoder) {
        self.muteState.encodeInline(encoder)
        self.messageSound.encodeInline(encoder)
    }
    
    public func isEqual(to: PeerNotificationSettings) -> Bool {
        if let to = to as? TelegramPeerNotificationSettings {
            return self == to
        } else {
            return false
        }
    }
    
    public static func ==(lhs: TelegramPeerNotificationSettings, rhs: TelegramPeerNotificationSettings) -> Bool {
        return lhs.muteState == rhs.muteState && lhs.messageSound == rhs.messageSound
    }
}

extension TelegramPeerNotificationSettings {
    public convenience init(apiSettings: Api.PeerNotifySettings) {
        switch apiSettings {
            case .peerNotifySettingsEmpty:
                self.init(muteState: .unmuted, messageSound: .appDefault)
            case let .peerNotifySettings(_, muteUntil, sound):
                self.init(muteState: muteUntil == 0 ? .unmuted : .muted(until: muteUntil), messageSound: sound == "default" ? .appDefault : .bundled(index: Int32(sound) ?? 0))
        }
    }
}
