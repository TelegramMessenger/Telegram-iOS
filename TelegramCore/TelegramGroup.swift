import Foundation
import Postbox

public enum TelegramGroupMembership: Int32 {
    case Member
    case Left
    case Removed
}

public final class TelegramGroup: Peer, Coding {
    public let id: PeerId
    public let accessHash: Int64
    public let title: String
    public let photo: [TelegramMediaImageRepresentation]
    public let participantCount: Int
    public let membership: TelegramGroupMembership
    public let version: Int
    
    public var indexName: PeerIndexNameRepresentation {
        return .title(self.title)
    }
    
    public init(id: PeerId, accessHash: Int64?, title: String, photo: [TelegramMediaImageRepresentation], participantCount: Int, membership: TelegramGroupMembership, version: Int) {
        self.id = id
        self.accessHash = accessHash ?? 0
        self.title = title
        self.photo = photo
        self.participantCount = participantCount
        self.membership = membership
        self.version = version
    }
    
    public init(decoder: Decoder) {
        self.id = PeerId(decoder.decodeInt64ForKey("i"))
        self.accessHash = decoder.decodeInt64ForKey("ah")
        self.title = decoder.decodeStringForKey("t")
        self.photo = decoder.decodeObjectArrayForKey("ph")
        self.participantCount = Int(decoder.decodeInt32ForKey("pc"))
        self.membership = TelegramGroupMembership(rawValue: decoder.decodeInt32ForKey("m"))!
        self.version = Int(decoder.decodeInt32ForKey("v"))
    }
    
    public func encode(_ encoder: Encoder) {
        encoder.encodeInt64(self.id.toInt64(), forKey: "i")
        encoder.encodeInt64(accessHash, forKey: "ah")
        encoder.encodeString(self.title, forKey: "t")
        encoder.encodeObjectArray(self.photo, forKey: "ph")
        encoder.encodeInt32(Int32(self.participantCount), forKey: "pc")
        encoder.encodeInt32(self.membership.rawValue, forKey: "m")
        encoder.encodeInt32(Int32(self.version), forKey: "v")
    }
    
    public func isEqual(_ other: Peer) -> Bool {
        if let other = other as? TelegramGroup {
            if self.id != other.id {
                return false
            }
            if self.accessHash != other.accessHash {
                return false
            }
            if self.title != other.title {
                return false
            }
            if self.photo != other.photo {
                return false
            }
            if self.membership != other.membership {
                return false
            }
            if self.version != other.version {
                return false
            }
            if self.participantCount != other.participantCount {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

private func imageRepresentationsForApiChatPhoto(_ photo: Api.ChatPhoto) -> [TelegramMediaImageRepresentation] {
    var telegramPhoto: [TelegramMediaImageRepresentation] = []
    switch photo {
    case let .chatPhoto(photoSmall, photoBig):
        if let smallLocation = telegramMediaLocationFromApiLocation(photoSmall), let largeLocation = telegramMediaLocationFromApiLocation(photoBig) {
            telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 80.0, height: 80.0), location: smallLocation, size: nil))
            telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), location: largeLocation, size: nil))
        }
    case .chatPhotoEmpty:
        break
    }
    return telegramPhoto
}

public extension TelegramGroup {
    public convenience init(chat: Api.Chat) {
        switch chat {
            case let .chat(flags, id, title, photo, participantsCount, _, version, _):
                let left = (flags & (1 | 2)) != 0
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), accessHash: nil, title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: Int(participantsCount), membership: left ? .Left : .Member, version: Int(version))
            case let .chatEmpty(id):
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), accessHash: nil, title: "", photo: [], participantCount: 0, membership: .Removed, version: 0)
            case let .chatForbidden(id, title):
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), accessHash: nil, title: title, photo: [], participantCount: 0, membership: .Removed, version: 0)
            case let .channel(flags, id, accessHash, title, _, photo, date, version, restrictionReason):
                let left = (flags & (1 | 2)) != 0
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: 0, membership: left ? .Left : .Member, version: Int(version))
            case let .channelForbidden(_, id, accessHash, title):
                self.init(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, photo: [], participantCount: 0, membership: .Left, version: 0)
        }
    }
    
    public static func merge(_ lhs: TelegramGroup?, rhs: Api.Chat) -> TelegramGroup? {
        switch rhs {
            case .chat, .chatEmpty, .chatForbidden, .channelForbidden:
                return TelegramGroup(chat: rhs)
            case let .channel(_, _, accessHash, title, _, photo, date, _, restrictionReason):
                if let _ = accessHash {
                    return TelegramGroup(chat: rhs)
                } else if let lhs = lhs {
                    return TelegramGroup(id: lhs.id, accessHash: lhs.accessHash, title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: lhs.participantCount, membership: lhs.membership, version: 0)
                } else {
                    return nil
                }
        }
    }
}
