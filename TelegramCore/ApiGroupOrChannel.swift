import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

func imageRepresentationsForApiChatPhoto(_ photo: Api.ChatPhoto) -> [TelegramMediaImageRepresentation] {
    var telegramPhoto: [TelegramMediaImageRepresentation] = []
    switch photo {
    case let .chatPhoto(photoSmall, photoBig):
        if let smallResource = mediaResourceFromApiFileLocation(photoSmall, size: nil), let largeResource = mediaResourceFromApiFileLocation(photoBig, size: nil) {
            telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 80.0, height: 80.0), resource: smallResource))
            telegramPhoto.append(TelegramMediaImageRepresentation(dimensions: CGSize(width: 640.0, height: 640.0), resource: largeResource))
        }
    case .chatPhotoEmpty:
        break
    }
    return telegramPhoto
}

func parseTelegramGroupOrChannel(chat: Api.Chat) -> Peer? {
    switch chat {
        case let .chat(flags, id, title, photo, participantsCount, date, version, migratedTo, adminRights, bannedRights):
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
                role = .creator
            } else if (flags & (1 << 4)) != 0 {
                role = .admin
            }
            if (flags & (1 << 3)) != 0 {
                groupFlags.insert(.adminsEnabled)
            }
            if (flags & (1 << 5)) != 0 {
                groupFlags.insert(.deactivated)
            }
            return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: Int(participantsCount), role: role, membership: left ? .Left : .Member, flags: groupFlags, migrationReference: migrationReference, creationDate: date, version: Int(version))
        case let .chatEmpty(id):
            return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: "", photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], migrationReference: nil, creationDate: 0, version: 0)
        case let .chatForbidden(id, title):
            return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: [], participantCount: 0, role: .member, membership: .Removed, flags: [], migrationReference: nil, creationDate: 0, version: 0)
        case let .channel(flags, id, accessHash, title, username, photo, date, version, restrictionReason, adminRights, bannedRights, _/*feed*//*, feedId*/):
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
                let infoFlags = TelegramChannelGroupFlags()
                info = .group(TelegramChannelGroupInfo(flags: infoFlags))
            } else {
                var infoFlags = TelegramChannelBroadcastFlags()
                if (flags & Int32(1 << 11)) != 0 {
                    infoFlags.insert(.messagesShouldHaveSignatures)
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
            
            let restrictionInfo: PeerAccessRestrictionInfo?
            if let restrictionReason = restrictionReason {
                restrictionInfo = PeerAccessRestrictionInfo(reason: restrictionReason)
            } else {
                restrictionInfo = nil
            }
            
            return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: date, version: version, participationStatus: participationStatus, info: info, flags: channelFlags, restrictionInfo: restrictionInfo, adminRights: adminRights.flatMap(TelegramChatAdminRights.init), bannedRights: bannedRights.flatMap(TelegramChatBannedRights.init), peerGroupId: /*feed*/nil/*feedId.flatMap { PeerGroupId(rawValue: $0) }*/)
        case let .channelForbidden(flags, id, accessHash, title, untilDate):
            let info: TelegramChannelInfo
            if (flags & Int32(1 << 8)) != 0 {
                info = .group(TelegramChannelGroupInfo(flags: []))
            } else {
                info = .broadcast(TelegramChannelBroadcastInfo(flags: []))
            }
            
            return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .kicked, info: info, flags: TelegramChannelFlags(), restrictionInfo: nil, adminRights: nil, bannedRights: TelegramChatBannedRights(flags: [.banReadMessages], untilDate: untilDate ?? Int32.max), peerGroupId: nil)
    }
}

func mergeGroupOrChannel(lhs: Peer?, rhs: Api.Chat) -> Peer? {
    switch rhs {
        case .chat, .chatEmpty, .chatForbidden, .channelForbidden:
            return parseTelegramGroupOrChannel(chat: rhs)
        case let .channel(flags, _, accessHash, title, username, photo, date, version, restrictionReason, adminRights, bannedRights, _/*feed*//*, feedId*/):
            if accessHash != nil && (flags & (1 << 12)) == 0 {
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
                return TelegramChannel(id: lhs.id, accessHash: lhs.accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: lhs.creationDate, version: lhs.version, participationStatus: lhs.participationStatus, info: info, flags: channelFlags, restrictionInfo: lhs.restrictionInfo, adminRights: lhs.adminRights, bannedRights: lhs.bannedRights, peerGroupId: lhs.peerGroupId)
            } else {
                return nil
            }
    }
}
