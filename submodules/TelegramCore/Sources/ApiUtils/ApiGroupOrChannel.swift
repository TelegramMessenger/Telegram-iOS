import Foundation
import Postbox
import TelegramApi


func imageRepresentationsForApiChatPhoto(_ photo: Api.ChatPhoto) -> [TelegramMediaImageRepresentation] {
    var representations: [TelegramMediaImageRepresentation] = []
    switch photo {
        case let .chatPhoto(_, photoId, strippedThumb, dcId):
            let smallResource: TelegramMediaResource
            let fullSizeResource: TelegramMediaResource

            smallResource = CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: photoId, sizeSpec: .small, volumeId: nil, localId: nil)
            fullSizeResource = CloudPeerPhotoSizeMediaResource(datacenterId: dcId, photoId: photoId, sizeSpec: .fullSize, volumeId: nil, localId: nil)

            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 80, height: 80), resource: smallResource, progressiveSizes: [], immediateThumbnailData: strippedThumb?.makeData()))
            representations.append(TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: 640, height: 640), resource: fullSizeResource, progressiveSizes: [], immediateThumbnailData: strippedThumb?.makeData()))
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
                migrationReference = TelegramGroupToChannelMigrationReference(peerId: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(channelId)), accessHash: accessHash)
            case .inputChannelEmpty:
                break
            case .inputChannelFromMessage:
                break
            }
        }
        var groupFlags = TelegramGroupFlags()
        var role: TelegramGroupRole = .member
        if (flags & (1 << 0)) != 0 {
            role = .creator(rank: nil)
        } else if let adminRights = adminRights {
            role = .admin(TelegramChatAdminRights(apiAdminRights: adminRights) ?? TelegramChatAdminRights(rights: []), rank: nil)
        }
        if (flags & (1 << 5)) != 0 {
            groupFlags.insert(.deactivated)
        }
        if (flags & Int32(1 << 23)) != 0 {
            groupFlags.insert(.hasVoiceChat)
        }
        if (flags & Int32(1 << 24)) != 0 {
            groupFlags.insert(.hasActiveVoiceChat)
        }
        if (flags & Int32(1 << 25)) != 0 {
            groupFlags.insert(.copyProtectionEnabled)
        }
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)), title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: Int(participantsCount), role: role, membership: left ? .Left : .Member, flags: groupFlags, defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init(apiBannedRights:)), migrationReference: migrationReference, creationDate: date, version: Int(version))
    case let .chatEmpty(id):
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)), title: "", photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    case let .chatForbidden(id, title):
        return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(id)), title: title, photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], defaultBannedRights: nil, migrationReference: nil, creationDate: 0, version: 0)
    case let .channel(flags, id, accessHash, title, username, photo, date, restrictionReason, adminRights, bannedRights, defaultBannedRights, _):
        let isMin = (flags & (1 << 12)) != 0
        
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
        if (flags & Int32(1 << 23)) != 0 {
            channelFlags.insert(.hasVoiceChat)
        }
        if (flags & Int32(1 << 24)) != 0 {
            channelFlags.insert(.hasActiveVoiceChat)
        }
        if (flags & Int32(1 << 25)) != 0 {
            channelFlags.insert(.isFake)
        }
        if (flags & Int32(1 << 26)) != 0 {
            channelFlags.insert(.isGigagroup)
        }
        if (flags & Int32(1 << 27)) != 0 {
            channelFlags.insert(.copyProtectionEnabled)
        }
        if (flags & Int32(1 << 28)) != 0 {
            channelFlags.insert(.joinToSend)
        }
        if (flags & Int32(1 << 29)) != 0 {
            channelFlags.insert(.requestToJoin)
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
        
        return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)), accessHash: accessHashValue, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: date, version: 0, participationStatus: participationStatus, info: info, flags: channelFlags, restrictionInfo: restrictionInfo, adminRights: adminRights.flatMap(TelegramChatAdminRights.init), bannedRights: bannedRights.flatMap(TelegramChatBannedRights.init), defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init))
    case let .channelForbidden(flags, id, accessHash, title, untilDate):
        let info: TelegramChannelInfo
        if (flags & Int32(1 << 8)) != 0 {
            info = .group(TelegramChannelGroupInfo(flags: []))
        } else {
            info = .broadcast(TelegramChannelBroadcastInfo(flags: []))
        }
        
        return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id)), accessHash: .personal(accessHash), title: title, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .kicked, info: info, flags: TelegramChannelFlags(), restrictionInfo: nil, adminRights: nil, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: untilDate ?? Int32.max), defaultBannedRights: nil)
    }
}

func mergeGroupOrChannel(lhs: Peer?, rhs: Api.Chat) -> Peer? {
    switch rhs {
        case .chat, .chatEmpty, .chatForbidden, .channelForbidden:
            return parseTelegramGroupOrChannel(chat: rhs)
        case let .channel(flags, _, accessHash, title, username, photo, _, _, _, _, defaultBannedRights, _):
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
                if (flags & Int32(1 << 23)) != 0 {
                    channelFlags.insert(.hasVoiceChat)
                } else {
                    let _ = channelFlags.remove(.hasVoiceChat)
                }
                if (flags & Int32(1 << 24)) != 0 {
                    channelFlags.insert(.hasActiveVoiceChat)
                } else {
                    let _ = channelFlags.remove(.hasActiveVoiceChat)
                }
                var info = lhs.info
                switch info {
                case .broadcast:
                    break
                case .group:
                    var infoFlags = TelegramChannelGroupFlags()
                    if (flags & Int32(1 << 22)) != 0 {
                        infoFlags.insert(.slowModeEnabled)
                    }
                    info = .group(TelegramChannelGroupInfo(flags: infoFlags))
                }
                
                return TelegramChannel(id: lhs.id, accessHash: lhs.accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: lhs.creationDate, version: lhs.version, participationStatus: lhs.participationStatus, info: info, flags: channelFlags, restrictionInfo: lhs.restrictionInfo, adminRights: lhs.adminRights, bannedRights: lhs.bannedRights, defaultBannedRights: defaultBannedRights.flatMap(TelegramChatBannedRights.init))
            } else {
                return parseTelegramGroupOrChannel(chat: rhs)
            }
    }
}

func mergeChannel(lhs: TelegramChannel?, rhs: TelegramChannel) -> TelegramChannel {
    guard let lhs = lhs else {
        return rhs
    }
    
    if case .personal? = rhs.accessHash {
        return rhs
    }
    
    var channelFlags = lhs.flags
    if rhs.flags.contains(.isGigagroup) {
        channelFlags.insert(.isGigagroup)
    }
    if rhs.flags.contains(.isVerified) {
        channelFlags.insert(.isVerified)
    } else {
        let _ = channelFlags.remove(.isVerified)
    }
    if rhs.flags.contains(.hasVoiceChat) {
        channelFlags.insert(.hasVoiceChat)
    } else {
        let _ = channelFlags.remove(.hasVoiceChat)
    }
    if rhs.flags.contains(.hasActiveVoiceChat) {
        channelFlags.insert(.hasActiveVoiceChat)
    } else {
        let _ = channelFlags.remove(.hasActiveVoiceChat)
    }
    var info = lhs.info
    switch info {
    case .broadcast:
        break
    case .group:
        let infoFlags = TelegramChannelGroupFlags()
        info = .group(TelegramChannelGroupInfo(flags: infoFlags))
    }
    
    let accessHash: TelegramPeerAccessHash?
    if let rhsAccessHashValue = lhs.accessHash, case .personal = rhsAccessHashValue {
        accessHash = rhsAccessHashValue
    } else {
        accessHash = rhs.accessHash ?? lhs.accessHash
    }
    
    return TelegramChannel(id: lhs.id, accessHash: accessHash, title: rhs.title, username: rhs.username, photo: rhs.photo, creationDate: rhs.creationDate, version: rhs.version, participationStatus: lhs.participationStatus, info: info, flags: channelFlags, restrictionInfo: rhs.restrictionInfo, adminRights: rhs.adminRights, bannedRights: rhs.bannedRights, defaultBannedRights: rhs.defaultBannedRights)
}

