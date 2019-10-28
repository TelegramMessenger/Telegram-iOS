import Foundation
#if os(macOS)
    import PostboxMac
    import TelegramApiMac
#else
    import Postbox
    import TelegramApi
#endif

import SyncCore

extension TelegramChatAdminRights {
    init(apiAdminRights: Api.ChatAdminRights) {
        switch apiAdminRights {
            case let .chatAdminRights(flags):
                self.init(flags: TelegramChatAdminRightsFlags(rawValue: flags))
        }
    }
    
    var apiAdminRights: Api.ChatAdminRights {
        return .chatAdminRights(flags: self.flags.rawValue)
    }
}
