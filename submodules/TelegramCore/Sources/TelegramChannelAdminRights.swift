import Foundation
import Postbox
import TelegramApi

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
