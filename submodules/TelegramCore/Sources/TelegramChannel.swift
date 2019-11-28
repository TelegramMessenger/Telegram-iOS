import Foundation
import Postbox

import SyncCore

public enum TelegramChannelPermission {
    case sendMessages
    case pinMessages
    case inviteMembers
    case editAllMessages
    case deleteAllMessages
    case banMembers
    case addAdmins
    case changeInfo
}

public extension TelegramChannel {
    func hasPermission(_ permission: TelegramChannelPermission) -> Bool {
        if self.flags.contains(.isCreator) {
            return true
        }
        switch permission {
            case .sendMessages:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.flags.contains(.canPostMessages)
                    } else {
                        return false
                    }
                } else {
                    if let _ = self.adminRights {
                        return true
                    }
                    if let bannedRights = self.bannedRights, bannedRights.flags.contains(.banSendMessages) {
                        return false
                    }
                    if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.contains(.banSendMessages) {
                        return false
                    }
                    return true
                }
            case .pinMessages:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.flags.contains(.canPinMessages) || adminRights.flags.contains(.canEditMessages)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.flags.contains(.canPinMessages) {
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
            case .inviteMembers:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.flags.contains(.canInviteUsers)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.flags.contains(.canInviteUsers) {
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
                if let adminRights = self.adminRights, adminRights.flags.contains(.canEditMessages) {
                    return true
                }
                return false
            case .deleteAllMessages:
                if let adminRights = self.adminRights, adminRights.flags.contains(.canDeleteMessages) {
                    return true
                }
                return false
            case .banMembers:
                if let adminRights = self.adminRights, adminRights.flags.contains(.canBanUsers) {
                    return true
                }
                return false
            case .changeInfo:
                if case .broadcast = self.info {
                    if let adminRights = self.adminRights {
                        return adminRights.flags.contains(.canChangeInfo)
                    } else {
                        return false
                    }
                } else {
                    if let adminRights = self.adminRights, adminRights.flags.contains(.canChangeInfo) {
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
                if let adminRights = self.adminRights, adminRights.flags.contains(.canAddAdmins) {
                    return true
                }
                return false
        }
    }
    
    public func hasBannedPermission(_ rights: TelegramChatBannedRightsFlags) -> (Int32, Bool)? {
        if self.flags.contains(.isCreator) {
            return nil
        }
        if let adminRights = self.adminRights, !adminRights.flags.isEmpty {
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
    
    public var isRestrictedBySlowmode: Bool {
        if self.flags.contains(.isCreator) {
            return false
        }
        if let adminRights = self.adminRights, !adminRights.flags.isEmpty {
            return false
        }
        if case let .group(group) = self.info {
            return group.flags.contains(.slowModeEnabled)
        } else {
            return false
        }
    }
}
