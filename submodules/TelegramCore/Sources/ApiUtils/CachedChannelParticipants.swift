import Foundation
import Postbox
import TelegramApi


private enum ChannelParticipantValue: Int32 {
    case member = 0
    case creator = 1
    case editor = 2
    case moderator = 3
}

public struct ChannelParticipantAdminInfo: PostboxCoding, Equatable {
    public let rights: TelegramChatAdminRights
    public let promotedBy: PeerId
    public let canBeEditedByAccountPeer: Bool
    
    public init(rights: TelegramChatAdminRights, promotedBy: PeerId, canBeEditedByAccountPeer: Bool) {
        self.rights = rights
        self.promotedBy = promotedBy
        self.canBeEditedByAccountPeer = canBeEditedByAccountPeer
    }
    
    public init(decoder: PostboxDecoder) {
        self.rights = decoder.decodeObjectForKey("r", decoder: { TelegramChatAdminRights(decoder: $0) }) as! TelegramChatAdminRights
        self.promotedBy = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.canBeEditedByAccountPeer = decoder.decodeInt32ForKey("e", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.rights, forKey: "r")
        encoder.encodeInt64(self.promotedBy.toInt64(), forKey: "p")
        encoder.encodeInt32(self.canBeEditedByAccountPeer ? 1 : 0, forKey: "e")
    }
    
    public static func ==(lhs: ChannelParticipantAdminInfo, rhs: ChannelParticipantAdminInfo) -> Bool {
        return lhs.rights == rhs.rights && lhs.promotedBy == rhs.promotedBy && lhs.canBeEditedByAccountPeer == rhs.canBeEditedByAccountPeer
    }
}

public struct ChannelParticipantBannedInfo: PostboxCoding, Equatable {
    public let rights: TelegramChatBannedRights
    public let restrictedBy: PeerId
    public let timestamp: Int32
    public let isMember: Bool
    
    public init(rights: TelegramChatBannedRights, restrictedBy: PeerId, timestamp: Int32, isMember: Bool) {
        self.rights = rights
        self.restrictedBy = restrictedBy
        self.timestamp = timestamp
        self.isMember = isMember
    }
    
    public init(decoder: PostboxDecoder) {
        self.rights = decoder.decodeObjectForKey("r", decoder: { TelegramChatBannedRights(decoder: $0) }) as! TelegramChatBannedRights
        self.restrictedBy = PeerId(decoder.decodeInt64ForKey("p", orElse: 0))
        self.timestamp = decoder.decodeInt32ForKey("t", orElse: 0)
        self.isMember = decoder.decodeInt32ForKey("m", orElse: 0) != 0
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObject(self.rights, forKey: "r")
        encoder.encodeInt64(self.restrictedBy.toInt64(), forKey: "p")
        encoder.encodeInt32(self.timestamp, forKey: "t")
        encoder.encodeInt32(self.isMember ? 1 : 0, forKey: "m")
    }
    
    public static func ==(lhs: ChannelParticipantBannedInfo, rhs: ChannelParticipantBannedInfo) -> Bool {
        return lhs.rights == rhs.rights && lhs.restrictedBy == rhs.restrictedBy && lhs.timestamp == rhs.timestamp && lhs.isMember == rhs.isMember
    }
}

public enum ChannelParticipant: PostboxCoding, Equatable {
    case creator(id: PeerId, adminInfo: ChannelParticipantAdminInfo?, rank: String?)
    case member(id: PeerId, invitedAt: Int32, adminInfo: ChannelParticipantAdminInfo?, banInfo: ChannelParticipantBannedInfo?, rank: String?)
    
    public var peerId: PeerId {
        switch self {
            case let .creator(id, _, _):
                return id
            case let .member(id, _, _, _, _):
                return id
        }
    }
    
    public var rank: String? {
        switch self {
            case let .creator(_, _, rank):
                return rank
            case let .member(_, _, _, _, rank):
                return rank
        }
    }
    
    public static func ==(lhs: ChannelParticipant, rhs: ChannelParticipant) -> Bool {
        switch lhs {
            case let .member(lhsId, lhsInvitedAt, lhsAdminInfo, lhsBanInfo, lhsRank):
                if case let .member(rhsId, rhsInvitedAt, rhsAdminInfo, rhsBanInfo, rhsRank) = rhs {
                    if lhsId != rhsId {
                        return false
                    }
                    if lhsInvitedAt != rhsInvitedAt {
                        return false
                    }
                    if lhsAdminInfo != rhsAdminInfo {
                        return false
                    }
                    if lhsBanInfo != rhsBanInfo {
                        return false
                    }
                    if lhsRank != rhsRank {
                        return false
                    }
                    return true
                } else {
                    return false
                }
            case let .creator(id, adminInfo, rank):
                if case .creator(id, adminInfo, rank) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    public init(decoder: PostboxDecoder) {
        switch decoder.decodeInt32ForKey("r", orElse: 0) {
            case ChannelParticipantValue.member.rawValue:
                self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0), adminInfo: decoder.decodeObjectForKey("ai", decoder: { ChannelParticipantAdminInfo(decoder: $0) }) as? ChannelParticipantAdminInfo, banInfo: decoder.decodeObjectForKey("bi", decoder: { ChannelParticipantBannedInfo(decoder: $0) }) as? ChannelParticipantBannedInfo, rank: decoder.decodeOptionalStringForKey("rank"))
            case ChannelParticipantValue.creator.rawValue:
                self = .creator(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), adminInfo: decoder.decodeObjectForKey("ai", decoder: { ChannelParticipantAdminInfo(decoder: $0) }) as? ChannelParticipantAdminInfo, rank: decoder.decodeOptionalStringForKey("rank"))
            default:
                self = .member(id: PeerId(decoder.decodeInt64ForKey("i", orElse: 0)), invitedAt: decoder.decodeInt32ForKey("t", orElse: 0), adminInfo: nil, banInfo: nil, rank: nil)
        }
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        switch self {
            case let .member(id, invitedAt, adminInfo, banInfo, rank):
                encoder.encodeInt32(ChannelParticipantValue.member.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
                encoder.encodeInt32(invitedAt, forKey: "t")
                if let adminInfo = adminInfo {
                    encoder.encodeObject(adminInfo, forKey: "ai")
                } else {
                    encoder.encodeNil(forKey: "ai")
                }
                if let banInfo = banInfo {
                    encoder.encodeObject(banInfo, forKey: "bi")
                } else {
                    encoder.encodeNil(forKey: "bi")
                }
                if let rank = rank {
                    encoder.encodeString(rank, forKey: "rank")
                } else {
                    encoder.encodeNil(forKey: "rank")
                }
            case let .creator(id, adminInfo, rank):
                encoder.encodeInt32(ChannelParticipantValue.creator.rawValue, forKey: "r")
                encoder.encodeInt64(id.toInt64(), forKey: "i")
                if let adminInfo = adminInfo {
                    encoder.encodeObject(adminInfo, forKey: "ai")
                } else {
                    encoder.encodeNil(forKey: "ai")
                }
                if let rank = rank {
                    encoder.encodeString(rank, forKey: "rank")
                } else {
                    encoder.encodeNil(forKey: "rank")
                }
        }
    }
}

public final class CachedChannelParticipants: PostboxCoding, Equatable {
    public let participants: [ChannelParticipant]
    
    init(participants: [ChannelParticipant]) {
        self.participants = participants
    }
    
    public init(decoder: PostboxDecoder) {
        self.participants = decoder.decodeObjectArrayWithDecoderForKey("p")
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeObjectArray(self.participants, forKey: "p")
    }
    
    public static func ==(lhs: CachedChannelParticipants, rhs: CachedChannelParticipants) -> Bool {
        return lhs.participants == rhs.participants
    }
}


extension ChannelParticipant {
    init(apiParticipant: Api.ChannelParticipant) {
        switch apiParticipant {
            case let .channelParticipant(userId, date):
                self = .member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), invitedAt: date, adminInfo: nil, banInfo: nil, rank: nil)
            case let .channelParticipantCreator(_, userId, adminRights, rank):
                self = .creator(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(apiAdminRights: adminRights) ?? TelegramChatAdminRights(rights: []), promotedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), canBeEditedByAccountPeer: true), rank: rank)
            case let .channelParticipantBanned(flags, userId, restrictedBy, date, bannedRights):
                let hasLeft = (flags & (1 << 0)) != 0
                let banInfo = ChannelParticipantBannedInfo(rights: TelegramChatBannedRights(apiBannedRights: bannedRights), restrictedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(restrictedBy)), timestamp: date, isMember: !hasLeft)
                self = .member(id: userId.peerId, invitedAt: date, adminInfo: nil, banInfo: banInfo, rank: nil)
            case let .channelParticipantAdmin(flags, userId, _, promotedBy, date, adminRights, rank: rank):
                self = .member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), invitedAt: date, adminInfo: ChannelParticipantAdminInfo(rights: TelegramChatAdminRights(apiAdminRights: adminRights) ?? TelegramChatAdminRights(rights: []), promotedBy: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(promotedBy)), canBeEditedByAccountPeer: (flags & (1 << 0)) != 0), banInfo: nil, rank: rank)
            case let .channelParticipantSelf(_, userId, _, date):
                self = .member(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), invitedAt: date, adminInfo: nil, banInfo: nil, rank: nil)
            case let .channelParticipantLeft(userId):
                self = .member(id: userId.peerId, invitedAt: 0, adminInfo: nil, banInfo: nil, rank: nil)
        }
    }
}

extension CachedChannelParticipants {
    convenience init(apiParticipants: [Api.ChannelParticipant]) {
        self.init(participants: apiParticipants.map(ChannelParticipant.init))
    }
}
