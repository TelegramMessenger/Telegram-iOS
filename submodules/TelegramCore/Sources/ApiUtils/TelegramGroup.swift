import Foundation
import Postbox


// Incuding at least one Objective-C class in a swift file ensures that it doesn't get stripped by the linker
private final class LinkHelperClass: NSObject {
}

public extension TelegramGroup {
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
