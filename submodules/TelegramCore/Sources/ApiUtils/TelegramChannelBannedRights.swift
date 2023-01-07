import Foundation
import Postbox
import TelegramApi

extension TelegramChatBannedRights {
    init(apiBannedRights: Api.ChatBannedRights) {
        switch apiBannedRights {
            case let .chatBannedRights(flags, untilDate):
                var effectiveFlags = TelegramChatBannedRightsFlags(rawValue: flags)
                effectiveFlags.remove(.banSendMedia)
                self.init(flags: effectiveFlags, untilDate: untilDate)
        }
    }
    
    var apiBannedRights: Api.ChatBannedRights {
        var effectiveFlags = self.flags
        effectiveFlags.remove(.banSendMedia)
        
        return .chatBannedRights(flags: effectiveFlags.rawValue, untilDate: self.untilDate)
    }
}
