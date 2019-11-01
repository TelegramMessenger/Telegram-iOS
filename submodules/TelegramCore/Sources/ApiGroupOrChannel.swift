import Foundation
import Postbox
import TelegramApi

import SyncCore

func imageRepresentationsForApiChatPhoto(_ photo: Api.ChatPhoto) -> [TelegramMediaImageRepresentation] {
    var representations: [TelegramMediaImageRepresentation] = []
    switch photo {
        case let .chatPhoto(photoSmall, photoBig, dcId):
            
            let smallResource: TelegramMediaResource
            let fullSizeResource: TelegramMediaResource
            switch photoSmall {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    smallResource = CloudPeerPhotoSizeMediaResource(datacenterId: dcId, sizeSpec: .small, volumeId: volumeId, localId: localId)
            }
            switch photoBig {
                case let .fileLocationToBeDeprecated(volumeId, localId):
                    fullSizeResource = CloudPeerPhotoSizeMediaResource(datacenterId: dcId, sizeSpec: .fullSize, volumeId: volumeId, localId: localId)
            }
            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 80, height: 80), resource: smallResource))
            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: fullSizeResource))
        case .chatPhotoEmpty:
            break
    }
    return representations
}

func parseTelegramGroupOrChannel(chat: Api.Chat) -> Peer? {
    switch chat {
    case let .chat(flags, id, title, photo, participantsCount, date, version, migratedTo, adminRights, defaultBannedRights):
        let left = (flags & ((1 << 1) | (1 << 2))) != 0
        var migrationReference: TelegramGroupToChannelMigrationReference?
        if let migratedTo = migratedTo {
            switch migratedTo {
            case let .inputChannel(channelId, accessHash):
                migrationReference = TelegramGroupToChannelMigrationReference(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: channelId), accessHash: accessHash)
            case .inputChannelEmpty:
                break
            }
        }
        var groupFlags = TelegramGroupFlags()
        var role: TelegramGroupRole = .member
        if (flags & (1 << 0)) != 0 {
            role = .creator(rank: nil)
        } else if let adminRights = adminRights {
            role = .admin(TelegramChatAdminRights(apiAdminRights: adminRights), rank: nil)
        }
        if (flags & (1 << 5)) != 0 {
            groupFlags.insert(.deactivated)
        }
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: Int(participantsCount), role: role, membership: left ? .Left : .Member, flags: groupFlags, defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init(apiBannedRights:)), migrationReference: migrationReference, creationDate: date, version: Int(version))
    case let .chatEmpty(id):
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: "", photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    case let .chatForbidden(id, title):
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    case let .channel(flags, id, accessHash, title, username, photo, date, version, restrictionReason, adminRights, bannedRights, defaultBannedRights, _):
        let isMin = (flags & (1 << 20)) != 0
        
        let participationStatus: TelegramChannelParticipationStatus
        if (flags & Int32(1 << 1)) != 0 {
            participationStatus = .kicked
        } else if (flags & Int32(1 << 2)) != 0 {
            participationStatus = .left
        } else {
            participationStatus = .member
        }
        
        let info: TelegramChannelInfo
        if (flags & Int32(1 << 8)) != 0 {
            var infoFlags = TelegramChannelGroupFlags()
            if (flags & Int32(1 << 22)) != 0 {
                infoFlags.insert(.slowModeEnabled)
            }
            info = .group(TelegramChannelGroupInfo(flags: infoFlags))
        } else {
            var infoFlags = TelegramChannelBroadcastFlags()
            if (flags & Int32(1 << 11)) != 0 {
                infoFlags.insert(.messagesShouldHaveSignatures)
            }
            if (flags & Int32(1 << 20)) != 0 {
                infoFlags.insert(.hasDiscussionGroup)
            }
            info = .broadcast(TelegramChannelBroadcastInfo(flags: infoFlags))
        }
        
        var channelFlags = TelegramChannelFlags()
        if (flags & Int32(1 << 0)) != 0 {
            channelFlags.insert(.isCreator)
        }
        if (flags & Int32(1 << 7)) != 0 {
            channelFlags.insert(.isVerified)
        }
        if (flags & Int32(1 << 19)) != 0 {
            channelFlags.insert(.isScam)
        }
        if (flags & Int32(1 << 21)) != 0 {
            channelFlags.insert(.hasGeo)
        }
        
        let restrictionInfo: PeerAccessRestrictionInfo?
        if let restrictionReason = restrictionReason {
            restrictionInfo = PeerAccessRestrictionInfo(apiReasons: restrictionReason)
        } else {
            restrictionInfo = nil
        }
        
        let accessHashValue = accessHash.flatMap { value -> TelegramPeerAccessHash in
            if isMin {
                return .genericPublic(value)
            } else {
                return .personal(value)
            }
        }
        
        return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHashValue, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: date, version: version, participationStatus: participationStatus, info: info, flags: channelFlags, restrictionInfo: restrictionInfo, adminRights: adminRights.flatMap(TelegramChatAdminRights.init), bannedRights: bannedRights.flatMap(TelegramChatBannedRights.init), defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init))
    case let .channelForbidden(flags, id, accessHash, title, untilDate):
        let info: TelegramChannelInfo
        if (flags & Int32(1 << 8)) != 0 {
            info = .group(TelegramChannelGroupInfo(flags: []))
        } else {
            info = .broadcast(TelegramChannelBroadcastInfo(flags: []))
        }
        
        return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: .personal(accessHash), title: title, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .kicked, info: info, flags: TelegramChannelFlags(), restrictionInfo: nil, adminRights: nil, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: untilDate ?? Int32.max), defaultBannedRights: nil)
    }
}

func mergeGroupOrChannel(lhs: Peer?, rhs: Api.Chat) -> Peer? {
    switch rhs {
        case .chat, .chatEmpty, .chatForbidden, .channelForbidden:
            return parseTelegramGroupOrChannel(chat: rhs)
        case let .channel(flags, _, accessHash, title, username, photo, _, _, _, _, _, defaultBannedRights, _/*feed*//*, feedId*/):
            let isMin = (flags & (1 << 12)) != 0
            if accessHash != nil && !isMin {
                return parseTelegramGroupOrChannel(chat: rhs)
            } else if let lhs = lhs as? TelegramChannel {
                var channelFlags = lhs.flags
                if (flags & Int32(1 << 7)) != 0 {
                    channelFlags.insert(.isVerified)
                } else {
                    let _ = channelFlags.remove(.isVerified)
                }
                var info = lhs.info
                switch info {
                case .broadcast:
                    break
                case .group:
                    let infoFlags = TelegramChannelGroupFlags()
                    info = .group(TelegramChannelGroupInfo(flags: infoFlags))
                }
                return TelegramChannel(id: lhs.id, accessHash: lhs.accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: lhs.creationDate, version: lhs.version, participationStatus: lhs.participationStatus, info: info, flags: channelFlags, restrictionInfo: lhs.restrictionInfo, adminRights: lhs.adminRights, bannedRights: lhs.bannedRights, defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init))
            } else {
                return nil
            }
    }
}
