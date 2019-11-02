import Foundation
import Postbox

import SyncCore

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
