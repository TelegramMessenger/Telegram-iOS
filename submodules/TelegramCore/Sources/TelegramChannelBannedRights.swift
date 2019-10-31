import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension TelegramChatBannedRights {
    init(apiBannedRights: Api.ChatBannedRights) {
        switch apiBannedRights {
            case let .chatBannedRights(flags, untilDate):
                self.init(flags: TelegramChatBannedRightsFlags(rawValue: flags), untilDate: untilDate)
        }
    }
    
    var apiBannedRights: Api.ChatBannedRights {
        return .chatBannedRights(flags: self.flags.rawValue, untilDate: self.untilDate)
    }
}
