import Foundation
import Postbox


public enum TelegramChannelPermission {
    case sendText
    case sendPhoto
    case sendVideo
    case sendSomething
    case pinMessages
    case manageTopics
    case createTopics
    case inviteMembers
    case editAllMessages
    case deleteAllMessages
    case banMembers
    case addAdmins
    case changeInfo
    case canBeAnonymous
    case manageCalls
}

public extension TelegramChannel {
    func hasPermission(_ permission: TelegramChannelPermission) -> Bool {
        if self.flags.contains(.isCreator) {
            if case .canBeAnonymous = permission {
                if let adminRights = self.adminRights {
                    return adminRights.rights.contains(.canBeAnonymous)
                } else {
                    return false
                }
            }
            return true
        }
        switch permission {
            case .sendText:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canPostMessages)
                    } else {
                        return false
                    }
                } else {
                    if let _ = self.adminRights {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banSendText) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banSendText) {
                        return false
                    }
                    return true
                }
            case .sendPhoto:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canPostMessages)
                    } else {
                        return false
                    }
                } else {
                    if let _ = self.adminRights {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banSendPhotos) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banSendPhotos) {
                        return false
                    }
                    return true
                }
            case .sendVideo:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canPostMessages)
                    } else {
                        return false
                    }
                } else {
                    if let _ = self.adminRights {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banSendVideos) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banSendVideos) {
                        return false
                    }
                    return true
                }
            case .sendSomething:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canPostMessages)
                    } else {
                        return false
                    }
                } else {
                    if let _ = self.adminRights {
                        return true
                    }
                    
                    let flags: TelegramChatBannedRightsFlags = [
                        .banSendText,
                        .banSendInstantVideos,
                        .banSendVoice,
                        .banSendPhotos,
                        .banSendVideos,
                        .banSendStickers,
                        .banSendPolls,
                        .banSendFiles,
                        .banSendInline,
                        .banSendMusic
                    ]
                    
                    if let bannedRights = self.bannedRights, bannedRights.flags.intersection(flags) == flags {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.intersection(flags) == flags {
                        return false
                    }
                    return true
                }
            case .pinMessages:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canPinMessages) || adminRights.rights.contains(.canEditMessages)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.rights.contains(.canPinMessages) {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banPinMessages) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banPinMessages) {
                        return false
                    }
                    return true
                }
            case .manageTopics:
                if self.flags.contains(.isCreator) {
                    return true
                }
                if self.adminRights == nil {
                    return false
                }
                if let adminRights = self.adminRights, adminRights.rights.contains(.canManageTopics) {
                    return true
                }
                return false
            case .createTopics:
                if self.flags.contains(.isCreator) {
                    return true
                }
                if let adminRights = self.adminRights, adminRights.rights.contains(.canManageTopics) {
                    return true
                }
                if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banManageTopics) {
                    return false
                }
                if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banManageTopics) {
                    return false
                }
                return true
            case .inviteMembers:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canInviteUsers)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.rights.contains(.canInviteUsers) {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banAddMembers) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banAddMembers) {
                        return false
                    }
                    return true
                }
            case .editAllMessages:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canEditMessages) {
                    return true
                }
                return false
            case .deleteAllMessages:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canDeleteMessages) {
                    return true
                }
                return false
            case .banMembers:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canBanUsers) {
                    return true
                }
                return false
            case .changeInfo:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.rights.contains(.canChangeInfo)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.rights.contains(.canChangeInfo) {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banChangeInfo) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banChangeInfo) {
                        return false
                    }
                    return true
                }
            case .addAdmins:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canAddAdmins) {
                    return true
                }
                return false
            case .manageCalls:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canManageCalls) {
                    return true
                }
                return false
            case .canBeAnonymous:
                if let adminRights = self.adminRights, adminRights.rights.contains(.canBeAnonymous) {
                    return true
                }
                return false
        }
    }
    
    func hasBannedPermission(_ rights: TelegramChatBannedRightsFlags) -> (Int32, Bool)? {
        if self.flags.contains(.isCreator) {
            return nil
        }
        if let _ = self.adminRights {
            return nil
        }
        if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(rights) {
            return (Int32.max, false)
        }
        if let bannedRights = self.bannedRights, bannedRights.flags.contains(rights) {
            return (bannedRights.untilDate, true)
        }
        return nil
    }
    
    var isRestrictedBySlowmode: Bool {
        if self.flags.contains(.isCreator) {
            return false
        }
        if let _ = self.adminRights {
            return false
        }
        if case let .group(group) = self.info {
            return group.flags.contains(.slowModeEnabled)
        } else {
            return false
        }
    }
}
