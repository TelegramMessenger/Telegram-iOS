import Foundation
import Postbox
import TelegramApi

import SyncCore

extension TelegramChatBannedRights {
    init(apiBannedRights: Api.ChatBannedRights) {
        switch apiBannedRights {
            case let .chatBannedRights(flags, untilDate):
                self.init(flags: TelegramChatBannedRightsFlags(rawValue: flags), untilDate: untilDate)
            case let .chatBannedRightsChannel(flags):
                let isKicked = (flags & (1 << 0)) != 0
                self.init(flags: [.banReadMessages], untilDate: Int32.max)
        }
    }
    
    var apiBannedRights: Api.ChatBannedRights {
        return .chatBannedRights(flags: self.flags.rawValue, untilDate: self.untilDate)
    }
}
