import Foundation
import Postbox
import TelegramApi

import SyncCore

func parsedTelegramProfilePhoto(_ photo: Api.UserProfilePhoto) -> [TelegramMediaImageRepresentation] {
    var representations: [TelegramMediaImageRepresentation] = []
    switch photo {
        case let .userProfilePhoto(_, photoSmall, photoBig, dcId):
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
        case .userProfilePhotoEmpty:
            break
    }
    return representations
}

extension TelegramUser {
    convenience init(user: Api.User) {
        switch user {
        case let .user(flags, id, accessHash, firstName, lastName, username, phone, photo, _, _, restrictionReason, botInlinePlaceholder, _):
            let representations: [TelegramMediaImageRepresentation] = photo.flatMap(parsedTelegramProfilePhoto) ?? []
            
            let isMin = (flags & (1 << 20)) != 0
            let accessHashValue = accessHash.flatMap { value -> TelegramPeerAccessHash in
                if isMin {
                    return .genericPublic(value)
                } else {
                    return .personal(value)
                }
            }
            
            var userFlags: UserInfoFlags = []
            if (flags & (1 << 17)) != 0 {
                userFlags.insert(.isVerified)
            }
            if (flags & (1 << 23)) != 0 {
                userFlags.insert(.isSupport)
            }
            if (flags & (1 << 24)) != 0 {
                userFlags.insert(.isScam)
            }
            
            var botInfo: BotUserInfo?
            if (flags & (1 << 14)) != 0 {
                var botFlags = BotUserInfoFlags()
                if (flags & (1 << 15)) != 0 {
                    botFlags.insert(.hasAccessToChatHistory)
                }
                if (flags & (1 << 16)) == 0 {
                    botFlags.insert(.worksWithGroups)
                }
                if (flags & (1 << 21)) != 0 {
                    botFlags.insert(.requiresGeolocationForInlineRequests)
                }
                botInfo = BotUserInfo(flags: botFlags, inlinePlaceholder: botInlinePlaceholder)
            }
            
            let restrictionInfo: PeerAccessRestrictionInfo? = restrictionReason.flatMap(PeerAccessRestrictionInfo.init(apiReasons:))
            
            self.init(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: id), accessHash: accessHashValue, firstName: firstName, lastName: lastName, username: username, phone: phone, photo: representations, botInfo: botInfo, restrictionInfo: restrictionInfo, flags: userFlags)
        case let .userEmpty(id):
            self.init(id: PeerId(namespace: Namespaces.Peer.CloudUser, id: id), accessHash: nil, firstName: nil, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [])
        }
    }
    
    static func merge(_ lhs: TelegramUser?, rhs: Api.User) -> TelegramUser? {
        switch rhs {
            case let .user(flags, _, rhsAccessHash, _, _, username, _, photo, _, _, restrictionReason, botInlinePlaceholder, _):
                let isMin = (flags & (1 << 20)) != 0
                if !isMin {
                    return TelegramUser(user: rhs)
                } else {
                    let telegramPhoto = photo.flatMap(parsedTelegramProfilePhoto) ?? []
                    if let lhs = lhs {
                        var userFlags: UserInfoFlags = []
                        if (flags & (1 << 17)) != 0 {
                            userFlags.insert(.isVerified)
                        }
                        if (flags & (1 << 23)) != 0 {
                            userFlags.insert(.isSupport)
                        }
                        if (flags & (1 << 24)) != 0 {
                            userFlags.insert(.isScam)
                        }
                        
                        var botInfo: BotUserInfo?
                        if (flags & (1 << 14)) != 0 {
                            var botFlags = BotUserInfoFlags()
                            if (flags & (1 << 15)) != 0 {
                                botFlags.insert(.hasAccessToChatHistory)
                            }
                            if (flags & (1 << 16)) == 0 {
                                botFlags.insert(.worksWithGroups)
                            }
                            if (flags & (1 << 21)) != 0 {
                                botFlags.insert(.requiresGeolocationForInlineRequests)
                            }
                            botInfo = BotUserInfo(flags: botFlags, inlinePlaceholder: botInlinePlaceholder)
                        }
                        
                        let restrictionInfo: PeerAccessRestrictionInfo? = restrictionReason.flatMap(PeerAccessRestrictionInfo.init)
                        
                        let rhsAccessHashValue = rhsAccessHash.flatMap { value -> TelegramPeerAccessHash in
                            if isMin {
                                return .genericPublic(value)
                            } else {
                                return .personal(value)
                            }
                        }
                        
                        let accessHash: TelegramPeerAccessHash?
                        if let rhsAccessHashValue = rhsAccessHashValue, case .personal = rhsAccessHashValue {
                            accessHash = rhsAccessHashValue
                        } else {
                            accessHash = lhs.accessHash ?? rhsAccessHashValue
                        }
                        
                        return TelegramUser(id: lhs.id, accessHash: accessHash, firstName: lhs.firstName, lastName: lhs.lastName, username: username, phone: lhs.phone, photo: telegramPhoto, botInfo: botInfo, restrictionInfo: restrictionInfo, flags: userFlags)
                    } else {
                        return TelegramUser(user: rhs)
                    }
                }
            case .userEmpty:
                return TelegramUser(user: rhs)
        }
    }
}
