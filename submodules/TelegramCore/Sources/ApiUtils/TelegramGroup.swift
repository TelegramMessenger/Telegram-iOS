import Foundation
import Postbox


// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public extension TelegramGroup {
    enum Permission {
        case sendSomething
        case manageWelcomeMessages
    }
    
    func hasPermission(_ permission: Permission) -> Bool {
        switch permission {
        case .sendSomething:
            switch self.role {
            case .creator, .admin:
                return true
            default:
                break
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
            if let defaultBannedRights = self.defaultBannedRights, defaultBannedRights.flags.intersection(flags) == flags {
                return false
            }
            return true
        case .manageWelcomeMessages:
            switch self.role {
            case .creator:
                return true
            case let .admin(rights, _):
                return rights.rights.contains(.canManageWelcomeMessages)
            case .member:
                return false
            }
        }
    }
    
    func hasBannedPermission(_ rights: TelegramChatBannedRightsFlags) -> Bool {
        switch self.role {
        case .creator, .admin:
            return false
        default:
            if let bannedRights = self.defaultBannedRights {
                return bannedRights.flags.contains(rights)
            } else {
                return false
            }
        }
    }
}
