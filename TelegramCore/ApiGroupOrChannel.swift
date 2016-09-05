import Foundation
#if os(macOS)
    import PostboxMac
#else
    import Postbox
#endif

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

func parseTelegramGroupOrChannel(chat: Api.Chat) -> Peer? {
    switch chat {
        case let .chat(flags, id, title, photo, participantsCount, date, version, migratedTo):
            let left = (flags & (1 | 2)) != 0
            return TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: imageRepresentationsForApiChatPhoto(photo), participantCount: Int(participantsCount), membership: left ? .Left : .Member, version: Int(version))
        case let .chatEmpty(id):
            TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: "", photo: [], participantCount: 0, membership: .Removed, version: 0)
        case let .chatForbidden(id, title):
            TelegramGroup(id: PeerId(namespace: Namespaces.Peer.CloudGroup, id: id), title: title, photo: [], participantCount: 0, membership: .Removed, version: 0)
        case let .channel(flags, id, accessHash, title, username, photo, date, version, restrictionReason):
            let participationStatus: TelegramChannelParticipationStatus
            if (flags & Int32(1 << 1)) != 0 {
                participationStatus = .kicked
            } else if (flags & Int32(1 << 2)) != 0 {
                participationStatus = .left
            } else {
                participationStatus = .member
            }
            
            let role: TelegramChannelRole
            if (flags & Int32(1 << 0)) != 0 {
                role = .creator
            } else if (flags & Int32(1 << 3)) != 0 {
                role = .editor
            } else if (flags & Int32(1 << 4)) != 0 {
                role = .moderator
            } else {
                role = .member
            }
            
            let info: TelegramChannelInfo
            if (flags & Int32(1 << 8)) != 0 {
                var infoFlags = TelegramChannelGroupFlags()
                if (flags & Int32(1 << 10)) != 0 {
                    infoFlags.insert(.everyMemberCanInviteMembers)
                }
                info = .group(TelegramChannelGroupInfo(flags: infoFlags))
            } else {
                var infoFlags = TelegramChannelBroadcastFlags()
                if (flags & Int32(1 << 11)) != 0 {
                    infoFlags.insert(.messagesShouldHaveSignatures)
                }
                info = .broadcast(TelegramChannelBroadcastInfo(flags: []))
            }
            
            var channelFlags = TelegramChannelFlags()
            if (flags & Int32(1 << 7)) != 0 {
                channelFlags.insert(.verified)
            }
            
            let restrictionInfo: PeerAccessRestrictionInfo?
            if let restrictionReason = restrictionReason {
                restrictionInfo = PeerAccessRestrictionInfo(reason: restrictionReason)
            } else {
                restrictionInfo = nil
            }
            
            return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: date, version: version, participationStatus: participationStatus, role: role, info: info, flags: channelFlags, restrictionInfo: restrictionInfo)
        case let .channelForbidden(flags, id, accessHash, title):
            let info: TelegramChannelInfo
            if (flags & Int32(1 << 8)) != 0 {
                var infoFlags = TelegramChannelGroupFlags()
                info = .group(TelegramChannelGroupInfo(flags: infoFlags))
            } else {
                var infoFlags = TelegramChannelBroadcastFlags()
                info = .broadcast(TelegramChannelBroadcastInfo(flags: []))
            }
            
            return TelegramChannel(id: PeerId(namespace: Namespaces.Peer.CloudChannel, id: id), accessHash: accessHash, title: title, username: nil, photo: [], creationDate: 0, version: 0, participationStatus: .kicked, role: .member, info: info, flags: TelegramChannelFlags(), restrictionInfo: nil)
    }
    
    return nil
}

func mergeGroupOrChannel(lhs: Peer?, rhs: Api.Chat) -> Peer? {
    switch rhs {
        case .chat, .chatEmpty, .chatForbidden, .channelForbidden:
            return parseTelegramGroupOrChannel(chat: rhs)
        case let .channel(flags, id, accessHash, title, username, photo, date, version, restrictionReason):
            if let _ = accessHash {
                return parseTelegramGroupOrChannel(chat: rhs)
            } else if let lhs = lhs as? TelegramChannel {
                var channelFlags = lhs.flags
                if (flags & Int32(1 << 7)) != 0 {
                    channelFlags.insert(.verified)
                } else {
                    let _ = channelFlags.remove(.verified)
                }
                var info = lhs.info
                switch info {
                    case .broadcast:
                        break
                    case let .group(groupInfo):
                        var infoFlags = TelegramChannelGroupFlags()
                        if (flags & Int32(1 << 10)) != 0 {
                            infoFlags.insert(.everyMemberCanInviteMembers)
                        }
                        info = .group(TelegramChannelGroupInfo(flags: infoFlags))
                }
                return TelegramChannel(id: lhs.id, accessHash: lhs.accessHash, title: title, username: username, photo: imageRepresentationsForApiChatPhoto(photo), creationDate: lhs.creationDate, version: lhs.version, participationStatus: lhs.participationStatus, role: lhs.role, info: info, flags: channelFlags, restrictionInfo: lhs.restrictionInfo)
            } else {
                return nil
            }
    }
}
