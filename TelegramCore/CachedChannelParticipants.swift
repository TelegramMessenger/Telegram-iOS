import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

private enum ChannelParticipantValue: Int32 {
    case member = 0
    case creator = 1
    case editor = 2
    case moderator = 3
}

public enum ChannelParticipant: Coding, Equatable {
    case member(id: PeerId, invitedAt: Int32)
    case creator(id: PeerId)
    case editor(id: PeerId, invitedBy: PeerId, invitedAt: Int32)
    case moderator(id: PeerId, invitedBy: PeerId, invitedAt: Int32)
    
    public var peerId: PeerId {
        switch self {
            case let .member(id, _):
                return id
            case let .creator(id):
                return id
            case let .editor(id, _, _):
                return id
            case let .moderator(id, _, _):
                return id
        }
    }
    
    public static func ==(lhs: ChannelParticipant, rhs: ChannelParticipant) -> Bool {
        switch lhs {
            case let .member(id, invitedAt):
                if case .member(id, invitedAt) = rhs {
                    return true
                } else {
                    return false
                }
            case let .creator(id):
                if case .creator(id) = rhs {
                    return true
                } else {
                    return false
                }
            case let .editor(id, invitedBy, invitedAt):
                if case .editor(id, invitedBy, invitedAt) = rhs {
                    return true
                } else {
                    return false
                }
            case let .moderator(id, invitedBy, invitedAt):
                if case .moderator(id, invitedBy, invitedAt) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public init(decoder: Decoder) {
        switch decoder.decodeInt32ForKey("r") as Int32 {
            case ChannelParticipantValue.member.rawValue:
                self = .member(id: PeerId(decoder.decodeInt64ForKey("i")), invitedAt: decoder.decodeInt32ForKey("t"))
            case ChannelParticipantValue.creator.rawValue:
                self = .creator(id: PeerId(decoder.decodeInt64ForKey("i")))
            case ChannelParticipantValue.editor.rawValue:
                self = .editor(id: PeerId(decoder.decodeInt64ForKey("i")), invitedBy: PeerId(decoder.decodeInt64ForKey("p")), invitedAt: decoder.decodeInt32ForKey("t"))
            case ChannelParticipantValue.moderator.rawValue:
                self = .moderator(id: PeerId(decoder.decodeInt64ForKey("i")), invitedBy: PeerId(decoder.decodeInt64ForKey("p")), invitedAt: decoder.decodeInt32ForKey("t"))
            default:
                assertionFailure()
                self = .member(id: PeerId(decoder.decodeInt64ForKey("i")), invitedAt: decoder.decodeInt32ForKey("t"))
        }
    }
    
    public func encode(_ encoder: Encoder) {
        switch self {
            case let .member(id, invitedAt):
                encoder.encodeInt32(ChannelParticipantValue.member.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
                encoder.encodeInt32(invitedAt, forKey: "t")
            case let .creator(id):
                encoder.encodeInt32(ChannelParticipantValue.creator.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
            case let .editor(id, invitedBy, invitedAt):
                encoder.encodeInt32(ChannelParticipantValue.editor.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
                encoder.encodeInt64(invitedBy.toInt64(), forKey: "p")
                encoder.encodeInt32(invitedAt, forKey: "t")
            case let .moderator(id, invitedBy, invitedAt):
                encoder.encodeInt32(ChannelParticipantValue.moderator.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
                encoder.encodeInt64(invitedBy.toInt64(), forKey: "p")
                encoder.encodeInt32(invitedAt, forKey: "t")
        }
    }
}

public final class CachedChannelParticipants: Coding, Equatable {
    public let participants: [ChannelParticipant]
    
    init(participants: [ChannelParticipant]) {
        self.participants = participants
    }
    
    public init(decoder: Decoder) {
        self.participants = decoder.decodeObjectArrayWithDecoderForKey("p")
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeObjectArray(self.participants, forKey: "p")
    }
    
    public static func ==(lhs: CachedChannelParticipants, rhs: CachedChannelParticipants) -> Bool {
        return lhs.participants == rhs.participants
    }
}

extension CachedChannelParticipants {
    convenience init(apiParticipants: [Api.ChannelParticipant]) {
        var participants: [ChannelParticipant] = []
        for participant in apiParticipants {
            switch participant {
                case let .channelParticipant(userId, date):
                    participants.append(.member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedAt: date))
                case let .channelParticipantCreator(userId):
                    participants.append(.creator(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId)))
                case let .channelParticipantEditor(userId, inviterId, date):
                    participants.append(.editor(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId), invitedAt: date))
                case let .channelParticipantKicked(userId, _, date):
                    participants.append(.member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedAt: date))
                case let .channelParticipantModerator(userId, inviterId, date):
                    participants.append(.moderator(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: inviterId), invitedAt: date))
                case let .channelParticipantSelf(userId, _, date):
                    participants.append(.member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), invitedAt: date))
            }
        }
        self.init(participants: participants)
    }
}
